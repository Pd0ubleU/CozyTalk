import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {requireAdmin} from "./_utils";

/**
 * Returns the blocked-users list for a given uid (admin only).
 * @param {{ uid: string }} data
 * @return {{ blockedUsers: Array<{ uid: string, displayName: string | null, blockedAt: string | null }> }}
 */
export const adminGetBlockedUsers = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    await requireAdmin(request);

    const {uid} = request.data as {uid: unknown};
    if (!uid || typeof uid !== "string") {
      throw new HttpsError("invalid-argument", "uid is required.");
    }

    const db = admin.firestore();
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("blocked")
      .orderBy("blockedAt", "desc")
      .get();

    const blockedUsers = snap.docs.map((d) => {
      const data = d.data();
      const ts = data.blockedAt as Timestamp | null;
      return {
        uid: d.id,
        displayName: (data.displayName as string | null) ?? null,
        blockedAt: ts ? ts.toDate().toISOString() : null,
      };
    });

    logger.info("adminGetBlockedUsers", {targetUid: uid, count: blockedUsers.length});
    return {blockedUsers};
  },
);
