import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  getBlockedUids,
  isBlockedByRoom,
  mergeIntoBlockList,
  type BlockListEntry,
} from "../user/_blockUtils";

const ROOM_ID_PATTERN = /^[A-Za-z0-9]{5}$/;

export const joinRoomById = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {roomId} = request.data as {roomId?: unknown};
    if (typeof roomId !== "string" || !ROOM_ID_PATTERN.test(roomId)) {
      throw new HttpsError(
        "invalid-argument",
        "roomId must be a 5-character alphanumeric string.",
      );
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const rtdb = admin.database();
    const roomRef = db.collection("rooms").doc(roomId);

    // Pre-flight read for fast, readable error messages.
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }

    const data = roomSnap.data()!;
    if (data.status === "expired") {
      throw new HttpsError("failed-precondition", "Room has expired.");
    }
    if (data.status === "padding") {
      throw new HttpsError(
        "failed-precondition",
        "Room is no longer available.",
      );
    }
    if (data.isLocked) {
      throw new HttpsError("failed-precondition", "Room is locked.");
    }
    if ((data.users as string[]).includes(uid)) {
      // Idempotent — user already in room, just confirm.
      return {roomId, mode: data.mode, roomType: data.roomType};
    }
    if (data.memberCount >= data.maxUsers) {
      throw new HttpsError("resource-exhausted", "Room is full.");
    }

    // Caller's own block list — fetched once here, then re-checked inside the
    // transaction below against the transactionally-read room snapshot.
    const callerBlockedUids = await getBlockedUids(db, uid);

    // Atomic join — re-validates capacity AND block state on the
    // transactionally-read snapshot. Checking blocks here (not just in the
    // pre-flight read) closes the race where two users join an empty room
    // concurrently and each slips past the other's block guard.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(roomRef);
      if (!snap.exists) throw new HttpsError("not-found", "Room not found.");

      const d = snap.data()!;
      if (d.status === "expired") {
        throw new HttpsError("failed-precondition", "Room has expired.");
      }
      if (d.status === "padding") {
        throw new HttpsError(
          "failed-precondition",
          "Room is no longer available.",
        );
      }
      if (d.isLocked) {
        throw new HttpsError("failed-precondition", "Room is locked.");
      }
      if (d.memberCount >= d.maxUsers) {
        throw new HttpsError("resource-exhausted", "Room is full.");
      }

      const roomBlockList =
        (d.blockList as BlockListEntry[] | undefined) ?? [];
      if (isBlockedByRoom(roomBlockList, uid)) {
        throw new HttpsError(
          "permission-denied",
          "You are blocked from this room.",
        );
      }
      if ((d.users as string[]).some((u) => callerBlockedUids.includes(u))) {
        throw new HttpsError(
          "permission-denied",
          "A room member is on your block list.",
        );
      }

      tx.update(roomRef, {
        users: FieldValue.arrayUnion(uid),
        memberCount: FieldValue.increment(1),
        status: "active",
        paddingUntil: null,
        blockList: mergeIntoBlockList(roomBlockList, uid, callerBlockedUids),
      });
    });

    await rtdb.ref(`rooms/${roomId}/members/${uid}`).set(true);
    logger.info("User joined room by ID", {uid, roomId});
    return {roomId, mode: data.mode, roomType: data.roomType};
  },
);
