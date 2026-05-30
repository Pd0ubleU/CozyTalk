import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {PADDING_MINUTES} from "./_utils";
import {meanVector} from "./embeddingService";
import {getBlockedUids, removeFromBlockList, type BlockListEntry} from "../user/_blockUtils";

export const leaveRoom = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {roomId} = request.data as {roomId?: unknown};
    if (typeof roomId !== "string" || roomId.length === 0) {
      throw new HttpsError("invalid-argument", "roomId is required.");
    }
    if (roomId.includes("/")) {
      throw new HttpsError("invalid-argument", "Invalid roomId.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const rtdb = admin.database();
    const roomRef = db.collection("rooms").doc(roomId);

    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }
    const data = roomSnap.data()!;
    if (!(data.users as string[]).includes(uid)) {
      // Idempotent — already left, clean up RTDB just in case.
      await Promise.all([
        rtdb.ref(`rooms/${roomId}/members/${uid}`).remove(),
        rtdb.ref(`typing/${roomId}/${uid}`).remove(),
        rtdb.ref(`presence/${roomId}/${uid}`).remove(),
      ]);
      return {success: true};
    }

    const leaverBlockedUids = await getBlockedUids(db, uid);

    let newCount = 0;
    let requeueUid: string | null = null;
    let requeueInterestVector: number[] | null = null;
    let requeueBackgroundTheme: string | null = null;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(roomRef);
      if (!snap.exists) return;

      const d = snap.data()!;
      if (!(d.users as string[]).includes(uid)) return;

      newCount = Math.max(0, (d.memberCount as number) - 1);
      const update: Record<string, unknown> = {
        users: FieldValue.arrayRemove(uid),
        memberCount: newCount,
        blockList: removeFromBlockList(
          (d.blockList as BlockListEntry[] | undefined) ?? [],
          leaverBlockedUids,
        ),
      };

      if (newCount === 0) {
        update.status = "padding";
        update.paddingUntil = Timestamp.fromMillis(
          Date.now() + PADDING_MINUTES * 60 * 1000,
        );
      } else if (d.mode === "1v1" && newCount === 1) {
        // One player left a 1v1 room — put it in a short padding window so
        // the remaining player's app detects the state change and re-queues.
        update.status = "padding";
        update.paddingUntil = Timestamp.fromMillis(Date.now() + 30 * 1000);
        requeueUid = (d.users as string[]).find((u) => u !== uid) ?? null;
        // Capture the remaining user's interest vector and theme so they're
        // restored on re-queue — interest matching and theme partitioning must
        // survive a partner-left re-queue.
        if (requeueUid) {
          const mi = d.memberInterests as Record<string, number[]> | null;
          requeueInterestVector = mi?.[requeueUid] ?? null;
          requeueBackgroundTheme =
            (d.backgroundTheme as string | null | undefined) ?? null;
        }
      }

      // Remove this member's interest vector and recompute the room aggregate.
      if (d.mode === "group") {
        const existing =
          (d.memberInterests as Record<string, number[]> | null) ?? {};
        const remaining = Object.fromEntries(
          Object.entries(existing).filter(([k]) => k !== uid),
        ) as Record<string, number[]>;

        // Always update memberInterests if any interests exist (even if uid wasn't in it).
        // This ensures stale interests are cleared when a member leaves.
        if (Object.keys(remaining).length > 0) {
          update.memberInterests = remaining;
          update.roomInterestVector = meanVector(Object.values(remaining));
        } else {
          update.memberInterests = null;
          update.roomInterestVector = null;
        }
      }

      tx.update(roomRef, update);
    });

    await Promise.all([
      rtdb.ref(`rooms/${roomId}/members/${uid}`).remove(),
      rtdb.ref(`typing/${roomId}/${uid}`).remove(),
      rtdb.ref(`presence/${roomId}/${uid}`).remove(),
    ]);

    if (requeueUid) {
      // Delete first so the subsequent set() triggers onDocumentCreated,
      // firing match1v1Users immediately for the re-queued user.
      const requeueRef = db.collection("waiting_pool").doc(requeueUid);
      await requeueRef.delete();
      await requeueRef.set({
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        status: "waiting",
        mode: "1v1",
        roomId: null,
        interestText: null,
        interestVector: requeueInterestVector,
        backgroundTheme: requeueBackgroundTheme,
      });
      // Remove the remaining user's RTDB membership so cleanupMember fires,
      // decrements memberCount to 0, and lets expireRooms clean up the old room.
      await Promise.all([
        rtdb.ref(`rooms/${roomId}/members/${requeueUid}`).remove(),
        rtdb.ref(`typing/${roomId}/${requeueUid}`).remove(),
        rtdb.ref(`presence/${roomId}/${requeueUid}`).remove(),
      ]);
      logger.info("Re-queued remaining 1v1 user after partner left", {
        requeueUid,
        roomId,
      });
    }

    logger.info("User left room", {uid, roomId, remainingMembers: newCount});
    return {success: true};
  },
);
