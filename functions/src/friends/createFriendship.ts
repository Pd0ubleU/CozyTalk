import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

/**
 * Writes both RTDB `friends/{uid1}/{uid2}` and `friends/{uid2}/{uid1}` nodes
 * when a friendship document is created. Using admin credentials bypasses the
 * owner-only write rule that would deny a client writing the peer's node.
 *
 * This mirrors onFriendshipDeleted, which removes the same nodes on delete.
 */
export const onFriendshipCreated = onDocumentCreated(
  {document: "friendships/{friendshipId}", region: "us-central1"},
  async (event) => {
    const {friendshipId} = event.params;
    const rtdb = admin.database();
    const users: string[] = event.data?.data()?.users ?? [];

    if (users.length !== 2) {
      logger.warn("onFriendshipCreated: users array absent or wrong length", {
        friendshipId,
      });
      return;
    }

    await Promise.all([
      rtdb.ref(`friends/${users[0]}/${users[1]}`).set(true),
      rtdb.ref(`friends/${users[1]}/${users[0]}`).set(true),
    ]);

    logger.info("Wrote RTDB friends nodes on friendship create", {
      friendshipId,
    });
  },
);
