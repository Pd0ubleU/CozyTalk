import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  createRoomWithRetry,
  generateKey,
  VALID_BACKGROUND_THEMES,
} from "./_utils";

export const createCustomRoom = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const rtdb = admin.database();

    const data = request.data as {backgroundTheme?: unknown};
    const rawTheme =
      typeof data?.backgroundTheme === "string"
        ? data.backgroundTheme.trim()
        : null;
    const backgroundTheme =
      rawTheme && VALID_BACKGROUND_THEMES.has(rawTheme) ? rawTheme : null;

    const roomId = await createRoomWithRetry(db, {
      roomType: "custom",
      mode: "group",
      status: "active",
      maxUsers: 5,
      memberCount: 1,
      users: [uid],
      isLocked: false,
      createdAt: FieldValue.serverTimestamp(),
      paddingUntil: null,
      encryptionKey: generateKey(),
      backgroundTheme: backgroundTheme,
    });

    await rtdb.ref(`rooms/${roomId}/members/${uid}`).set(true);
    logger.info("Created custom room", {uid, roomId, backgroundTheme});
    return {roomId};
  },
);
