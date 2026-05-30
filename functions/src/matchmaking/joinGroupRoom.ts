import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  createRoomWithRetry,
  generateKey,
  VALID_BACKGROUND_THEMES,
} from "./_utils";
import {
  embedText,
  cosineSimilarity,
  meanVector,
  INTEREST_SIMILARITY_THRESHOLD,
} from "./embeddingService";
import {
  getBlockedUids,
  isBlockedByRoom,
  mergeIntoBlockList,
  type BlockListEntry,
} from "../user/_blockUtils";

export const joinGroupRoom = onCall(
  {invoker: "public", cors: true, memory: "512MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const rtdb = admin.database();

    const data = request.data as {
      interestText?: unknown;
      backgroundTheme?: unknown;
    };
    const rawInterest =
      typeof data?.interestText === "string" ? data.interestText.trim() : null;
    const rawTheme =
      typeof data?.backgroundTheme === "string"
        ? data.backgroundTheme.trim()
        : null;
    const backgroundTheme =
      rawTheme && VALID_BACKGROUND_THEMES.has(rawTheme) ? rawTheme : null;
    const userVector = rawInterest ? await embedText(rawInterest) : null;

    // Remove any stale waiting_pool entry to keep the pool clean.
    await db
      .collection("waiting_pool")
      .doc(uid)
      .delete()
      .catch(() => null);

    /**
     * Shuffles candidates and attempts to join each one atomically.
     * Updates roomInterestVector and memberInterests in the join transaction
     * when the user has an interest vector. Skips rooms where the joiner is
     * blocked or where a room member is on the joiner's block list.
     * Returns the joined roomId on success, or null if all candidates fail.
     * @param {FirebaseFirestore.QueryDocumentSnapshot[]} docs - Candidate room docs.
     * @param {number[] | null} vector - Joining user's interest vector, if any.
     * @param {string[]} joinerBlockedUids - UIDs the joining user has blocked.
     * @return {Promise<string | null>} The joined roomId, or null.
     */
    async function _tryJoinCandidates(
      docs: FirebaseFirestore.QueryDocumentSnapshot[],
      vector: number[] | null,
      joinerBlockedUids: string[],
    ): Promise<string | null> {
      const shuffled = [...docs].sort(() => Math.random() - 0.5);
      for (const doc of shuffled) {
        const roomRef = db.collection("rooms").doc(doc.id);
        let joined = false;

        try {
          await db.runTransaction(async (tx) => {
            const roomSnap = await tx.get(roomRef);
            if (!roomSnap.exists) return;

            const d = roomSnap.data()!;
            if (
              d.status === "expired" ||
              d.status === "padding" ||
              d.isLocked ||
              d.memberCount >= d.maxUsers ||
              (d.users as string[]).includes(uid)
            ) {
              return;
            }

            const blockList = (d.blockList as BlockListEntry[]) ?? [];
            if (isBlockedByRoom(blockList, uid)) return;
            if ((d.users as string[]).some((u) => joinerBlockedUids.includes(u))) return;

            // Themed users must not land in a different-theme room.
            // Unthemed users can join any room.
            if (backgroundTheme) {
              const roomTheme =
                (d.backgroundTheme as string | null | undefined) ?? null;
              if (roomTheme !== backgroundTheme) return;
            }

            const update: Record<string, unknown> = {
              users: FieldValue.arrayUnion(uid),
              memberCount: FieldValue.increment(1),
              status: "active",
              paddingUntil: null,
              blockList: mergeIntoBlockList(blockList, uid, joinerBlockedUids),
            };

            // Add user's interest to room aggregate when they have a vector.
            if (vector) {
              const existing =
                (d.memberInterests as Record<string, number[]> | null) ?? {};
              const updated = {...existing, [uid]: vector};
              update.memberInterests = updated;
              update.roomInterestVector = meanVector(Object.values(updated));
            }

            tx.update(roomRef, update);
            joined = true;
          });
        } catch (err) {
          logger.warn(
            "Transaction failed joining room, trying next candidate",
            {roomId: doc.id, err},
          );
          continue;
        }

        if (joined) {
          await rtdb.ref(`rooms/${doc.id}/members/${uid}`).set(true);
          logger.info("User joined existing group room", {
            uid,
            roomId: doc.id,
            hadInterest: !!vector,
          });
          return doc.id;
        }
      }
      return null;
    }

    const joinerBlockedUids = await getBlockedUids(db, uid);

    // Fetch Phase 1 (lone-user) and Phase 2 (2-4 member) candidates in parallel.
    // When the user has interest, we also use these results for Phase 0.
    // Themed users get a backgroundTheme filter so they only land in same-theme
    // rooms. Unthemed users see all rooms (no filter).
    let priorityQuery: admin.firestore.Query = db
      .collection("rooms")
      .where("mode", "==", "group")
      .where("status", "==", "active")
      .where("isLocked", "==", false)
      .where("memberCount", "==", 1);
    let otherQuery: admin.firestore.Query = db
      .collection("rooms")
      .where("mode", "==", "group")
      .where("status", "==", "active")
      .where("isLocked", "==", false)
      .where("memberCount", ">", 1)
      .where("memberCount", "<", 5);
    if (backgroundTheme) {
      priorityQuery = priorityQuery.where(
        "backgroundTheme",
        "==",
        backgroundTheme,
      );
      otherQuery = otherQuery.where("backgroundTheme", "==", backgroundTheme);
    }
    const [prioritySnap, otherSnap] = await Promise.all([
      priorityQuery.limit(10).get(),
      otherQuery.limit(10).get(),
    ]);

    // Phase 0 — Interest matching: if the user typed an interest, find rooms
    // whose aggregate interest vector is similar enough to theirs. Interest-matched
    // rooms take priority over lone-user rooms (the existing Phase 1).
    if (userVector) {
      const allCandidates = [...prioritySnap.docs, ...otherSnap.docs];
      const matchingRooms = allCandidates.filter((d) => {
        const rv = d.data().roomInterestVector;
        return (
          Array.isArray(rv) &&
          cosineSimilarity(userVector, rv as number[]) >=
            INTEREST_SIMILARITY_THRESHOLD
        );
      });

      if (matchingRooms.length > 0) {
        const matched = await _tryJoinCandidates(matchingRooms, userVector, joinerBlockedUids);
        if (matched) {
          return {roomId: matched, isNewRoom: false};
        }
      }
    }

    // Phase 1 — Priority: join a room with exactly 1 member so that lone users
    // find a partner as quickly as possible.
    const priorityRoomId = await _tryJoinCandidates(
      prioritySnap.docs,
      userVector,
      joinerBlockedUids,
    );
    if (priorityRoomId) {
      return {roomId: priorityRoomId, isNewRoom: false};
    }

    // Phase 2 — Random: no lone-user rooms found; join any available room with
    // 2–4 members, chosen at random.
    const otherRoomId = await _tryJoinCandidates(otherSnap.docs, userVector, joinerBlockedUids);
    if (otherRoomId) {
      return {roomId: otherRoomId, isNewRoom: false};
    }

    // Phase 3 — No available room found: create one and become the first member.
    const newRoomData: Parameters<typeof createRoomWithRetry>[1] = {
      roomType: "public",
      mode: "group",
      status: "active",
      maxUsers: 5,
      memberCount: 1,
      users: [uid],
      isLocked: false,
      createdAt: FieldValue.serverTimestamp(),
      paddingUntil: null,
      encryptionKey: generateKey(),
      blockList: joinerBlockedUids.map((userId) => ({blockedBy: uid, userId, amount: 1})),
      ...(userVector
        ? {
            memberInterests: {[uid]: userVector},
            roomInterestVector: userVector,
          }
        : {}),
      backgroundTheme: backgroundTheme,
    };

    const roomId = await createRoomWithRetry(db, newRoomData);

    await rtdb.ref(`rooms/${roomId}/members/${uid}`).set(true);
    logger.info("Created new group room", {
      uid,
      roomId,
      hadInterest: !!userVector,
    });

    // Race-condition mitigation: if another user created a 1-member room at the
    // same time (both saw an empty DB), merge into theirs and discard ours.
    // Themed users only merge into same-theme rooms; unthemed merge anywhere.
    let soloQuery: admin.firestore.Query = db
      .collection("rooms")
      .where("mode", "==", "group")
      .where("status", "==", "active")
      .where("isLocked", "==", false)
      .where("memberCount", "==", 1);
    if (backgroundTheme) {
      soloQuery = soloQuery.where("backgroundTheme", "==", backgroundTheme);
    }
    const soloRooms = await soloQuery.limit(5).get();

    const mergeTarget = soloRooms.docs.find((d) => d.id !== roomId);
    if (mergeTarget) {
      const targetRef = db.collection("rooms").doc(mergeTarget.id);
      const myRoomRef = db.collection("rooms").doc(roomId);
      let merged = false;

      try {
        await db.runTransaction(async (tx) => {
          const [targetSnap, mySnap] = await Promise.all([
            tx.get(targetRef),
            tx.get(myRoomRef),
          ]);
          if (!targetSnap.exists || !mySnap.exists) return;
          const td = targetSnap.data()!;
          if (
            td.status === "expired" ||
            td.isLocked ||
            (td.memberCount as number) >= (td.maxUsers as number) ||
            (td.users as string[]).includes(uid)
          ) {
            return;
          }

          const mergeBlockList = (td.blockList as BlockListEntry[] | undefined) ?? [];
          if (isBlockedByRoom(mergeBlockList, uid)) return;
          if ((td.users as string[]).some((u) => joinerBlockedUids.includes(u))) return;

          const mergeUpdate: Record<string, unknown> = {
            users: FieldValue.arrayUnion(uid),
            memberCount: FieldValue.increment(1),
            blockList: mergeIntoBlockList(mergeBlockList, uid, joinerBlockedUids),
          };
          if (userVector) {
            const existing =
              (td.memberInterests as Record<string, number[]> | null) ?? {};
            const updated = {...existing, [uid]: userVector};
            mergeUpdate.memberInterests = updated;
            mergeUpdate.roomInterestVector = meanVector(Object.values(updated));
          }

          tx.update(targetRef, mergeUpdate);
          tx.delete(myRoomRef);
          merged = true;
        });
      } catch (err) {
        logger.warn("Group room merge failed, staying in created room", {
          roomId,
          err,
        });
      }

      if (merged) {
        await Promise.all([
          rtdb.ref(`rooms/${roomId}/members/${uid}`).remove(),
          rtdb.ref(`rooms/${mergeTarget.id}/members/${uid}`).set(true),
        ]);
        logger.info("Merged into existing group room after creation", {
          uid,
          roomId: mergeTarget.id,
          abandonedRoomId: roomId,
        });
        return {roomId: mergeTarget.id, isNewRoom: false};
      }
    }

    return {roomId, isNewRoom: true};
  },
);
