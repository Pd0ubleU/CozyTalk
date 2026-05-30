import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const MAX_BLOCKED_USERS = 5;

/**
 * Blocks a target user. Enforces a maximum of 5 blocked users per caller.
 * Writing when the target is already blocked is idempotent (updates displayName).
 * @param {{ targetUid: string, displayName?: string }} data
 * @return {{ success: true } | { success: false, reason: "max_blocked_reached" }}
 */
export const blockUser = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const callerUid = request.auth.uid;
    const {targetUid, displayName} = request.data as {
      targetUid: unknown;
      displayName?: unknown;
    };

    if (!targetUid || typeof targetUid !== "string") {
      throw new HttpsError("invalid-argument", "targetUid is required.");
    }
    if (callerUid === targetUid) {
      throw new HttpsError("invalid-argument", "Cannot block yourself.");
    }
    if (
      displayName !== undefined &&
      displayName !== null &&
      typeof displayName !== "string"
    ) {
      throw new HttpsError("invalid-argument", "displayName must be a string.");
    }

    const db = admin.firestore();
    const blockedCollRef = db
      .collection("users")
      .doc(callerUid)
      .collection("blocked");
    const targetRef = blockedCollRef.doc(targetUid);

    // Read + limit-check + write must be atomic. Without a transaction, two
    // concurrent calls could both read size = 4, both pass the cap check, and
    // both write — leaving the caller with 6 blocked users. The transaction
    // serializes them so the second sees the first's write and is rejected.
    const outcome = await db.runTransaction(async (tx) => {
      const existingSnap = await tx.get(targetRef);
      if (existingSnap.exists) {
        // Idempotent — update displayName if provided, then confirm success.
        if (typeof displayName === "string") {
          tx.update(targetRef, {displayName});
        }
        return "already_blocked" as const;
      }

      const countSnap = await tx.get(blockedCollRef);
      if (countSnap.size >= MAX_BLOCKED_USERS) {
        return "max_blocked_reached" as const;
      }

      tx.set(targetRef, {
        blockedUid: targetUid,
        displayName: typeof displayName === "string" ? displayName : null,
        blockedAt: FieldValue.serverTimestamp(),
      });
      return "blocked" as const;
    });

    if (outcome === "max_blocked_reached") {
      return {success: false, reason: "max_blocked_reached"};
    }
    if (outcome === "already_blocked") {
      logger.info("blockUser: already blocked, idempotent update", {
        callerUid,
        targetUid,
      });
    } else {
      logger.info("blockUser: user blocked", {callerUid, targetUid});
    }
    return {success: true};
  },
);
