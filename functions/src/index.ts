import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp({
  databaseURL:
    "https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app",
});

setGlobalOptions({maxInstances: 10});

// ── Friends ───────────────────────────────────────────────────────────────────
export {onFriendshipCreated} from "./friends/createFriendship";
export {onFriendshipDeleted} from "./friends/removeFriendship";
// ── Admin ─────────────────────────────────────────────────────────────────────
export {adminGetDashboard} from "./admin/adminGetDashboard";
export {adminResolveReport} from "./admin/adminResolveReport";
export {adminGetChatLog} from "./admin/adminGetChatLog";
export {adminBanUser} from "./admin/adminBanUser";
export {adminUnbanUser} from "./admin/adminUnbanUser";
export {adminGetBlockedUsers} from "./admin/adminGetBlockedUsers";

// ── User ──────────────────────────────────────────────────────────────────────
export {blockUser} from "./user/blockUser";
export {unblockUser} from "./user/unblockUser";

// ── Chat (existing) ───────────────────────────────────────────────────────────
export {sendMessage} from "./chat/sendMessage";
export {endSession} from "./chat/endSession";
export {reportSession} from "./chat/reportSession";
// setTyping: no Cloud Function — clients write directly to RTDB.

// ── Matchmaking ───────────────────────────────────────────────────────────────
export {joinGroupRoom} from "./matchmaking/joinGroupRoom";
export {cleanupMember} from "./matchmaking/cleanupMember";
export {cleanupPoolMember} from "./matchmaking/cleanupPoolMember";
export {createCustomRoom} from "./matchmaking/createCustomRoom";
export {joinRoomById} from "./matchmaking/joinRoomById";
export {leaveRoom} from "./matchmaking/leaveRoom";
export {join1v1Pool} from "./matchmaking/join1v1Pool";
export {cancel1v1Pool} from "./matchmaking/cancel1v1Pool";
export {match1v1Users} from "./matchmaking/match1v1Users";
export {expireRooms} from "./matchmaking/expireRooms";
export {setRoomLock} from "./matchmaking/setRoomLock";

export const helloWorld = onCall({invoker: "public", cors: true}, (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const input = request.data?.message;
  if (typeof input !== "string" || input.trim() === "") {
    throw new HttpsError(
      "invalid-argument",
      "A non-empty message string is required.",
    );
  }
  logger.info("Echo request", {message: input, structuredData: true});
  return {message: input};
});
