import * as crypto from "crypto";
import {HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import type {BlockListEntry} from "../user/_blockUtils";
export type {BlockListEntry} from "../user/_blockUtils";

export const PADDING_MINUTES = 5;

export const VALID_BACKGROUND_THEMES = new Set([
  "kao_tapu",
  "red_lotus_lake",
  "sea_of_cloud",
  "lumphini_park",
]);
const ROOM_ID_CHARS =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const ROOM_ID_LENGTH = 5;
const MAX_CREATE_ATTEMPTS = 5;

/**
 * Generates a cryptographically random 5-character alphanumeric room ID.
 * @return {string} Random 5-char string from [A-Za-z0-9].
 */
export function generateRoomId(): string {
  const bytes = crypto.randomBytes(ROOM_ID_LENGTH);
  return Array.from(bytes, (b) => ROOM_ID_CHARS[b % ROOM_ID_CHARS.length]).join(
    "",
  );
}

/**
 * Generates a random 256-bit AES key as a hex string.
 * @return {string} Hex-encoded 32-byte key.
 */
export function generateKey(): string {
  return crypto.randomBytes(32).toString("hex");
}

export interface RoomData {
  roomType: "public" | "custom";
  mode: "1v1" | "group";
  status: "active" | "padding";
  maxUsers: number;
  memberCount: number;
  users: string[];
  isLocked: boolean;
  createdAt: FieldValue;
  paddingUntil: null;
  encryptionKey: string;
  roomInterestVector?: number[] | null;
  memberInterests?: Record<string, number[]> | null;
  blockList?: BlockListEntry[] | null;
  backgroundTheme?: string | null;
}

/**
 * Atomically creates a room doc with a unique 5-char ID.
 * Retries on ALREADY_EXISTS (live room or expired tombstone collision).
 * @param {admin.firestore.Firestore} db - Firestore instance.
 * @param {RoomData} data - Room fields (roomId is added automatically).
 * @param {number} maxAttempts - Max retry attempts before giving up.
 * @return {Promise<string>} The claimed room ID.
 */
export async function createRoomWithRetry(
  db: admin.firestore.Firestore,
  data: RoomData,
  maxAttempts = MAX_CREATE_ATTEMPTS,
): Promise<string> {
  for (let i = 0; i < maxAttempts; i++) {
    const roomId = generateRoomId();
    try {
      await db
        .collection("rooms")
        .doc(roomId)
        .create({...data, roomId});
      return roomId;
    } catch (e: unknown) {
      const err = e as {code?: number | string};
      const isAlreadyExists =
        err.code === 6 ||
        err.code === "ALREADY_EXISTS" ||
        (e instanceof Error && e.message.includes("ALREADY_EXISTS"));
      if (!isAlreadyExists) throw e;
      logger.debug("Room ID collision, retrying", {roomId, attempt: i + 1});
    }
  }
  throw new HttpsError(
    "internal",
    "Failed to generate a unique room ID. Please try again.",
  );
}

/**
 * Recursively batch-deletes all documents in a Firestore subcollection.
 * @param {admin.firestore.Firestore} db - Firestore instance.
 * @param {admin.firestore.CollectionReference} collRef - Collection to delete.
 * @param {number} batchSize - Documents per batch.
 * @return {Promise<void>}
 */
export async function deleteSubcollection(
  db: admin.firestore.Firestore,
  collRef: admin.firestore.CollectionReference,
  batchSize = 100,
): Promise<void> {
  const snap = await collRef.limit(batchSize).get();
  if (snap.empty) return;

  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();

  if (snap.size >= batchSize) {
    await deleteSubcollection(db, collRef, batchSize);
  }
}
