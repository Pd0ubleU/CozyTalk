import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {deleteSubcollection} from "../matchmaking/_utils";

export const onFriendshipDeleted = onDocumentDeleted(
  {document: "friendships/{friendshipId}", region: "us-central1"},
  async (event) => {
    const {friendshipId} = event.params;
    const db = admin.firestore();
    const rtdb = admin.database();

    const users: string[] = event.data?.data()?.users ?? [];

    await Promise.all([
      deleteSubcollection(
        db,
        db
          .collection("friend_messages")
          .doc(friendshipId)
          .collection("messages"),
      ),
      users.length === 2
        ? Promise.all([
            rtdb.ref(`friends/${users[0]}/${users[1]}`).remove(),
            rtdb.ref(`friends/${users[1]}/${users[0]}`).remove(),
          ])
        : Promise.resolve(),
    ]);

    logger.info(
      "Cleaned up friend messages and RTDB presence on friendship delete",
      {
        friendshipId,
      },
    );
  },
);
