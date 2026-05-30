import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Unblocks a previously blocked user.
 * @param {{ targetUid: string }} data
 * @return {{ success: true }}
 */
export const unblockUser = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const callerUid = request.auth.uid;
    const {targetUid} = request.data as {targetUid: unknown};

    if (!targetUid || typeof targetUid !== "string") {
      throw new HttpsError("invalid-argument", "targetUid is required.");
    }

    const db = admin.firestore();
    await db
      .collection("users")
      .doc(callerUid)
      .collection("blocked")
      .doc(targetUid)
      .delete();

    logger.info("unblockUser: user unblocked", {callerUid, targetUid});
    return {success: true};
  },
);
