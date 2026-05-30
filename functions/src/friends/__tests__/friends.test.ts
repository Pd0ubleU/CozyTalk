/**
 * Integration tests for friends Cloud Functions.
 * Runs against the local Firebase emulator suite.
 *
 * Covers:
 *   - onFriendshipCreated: RTDB friends/{uid1}/{uid2} node creation
 *   - onFriendshipCreated: graceful handling when users array is absent
 *   - onFriendshipDeleted: friend_messages subcollection cleanup
 *   - onFriendshipDeleted: RTDB friends/{uid1}/{uid2} node removal
 *   - onFriendshipDeleted: graceful handling when users array is absent
 */

import {
  resetEmulatorData,
  adminFirestoreSet,
  adminFirestoreList,
  adminFirestoreDelete,
  rtdbGet,
  rtdbSet,
  waitUntilAdminDocMatches,
  waitUntilRtdbValue,
} from "../../matchmaking/__tests__/helpers";

beforeEach(async () => {
  await resetEmulatorData();
}, 15_000);

afterEach(async () => {
  await resetEmulatorData();
}, 15_000);

// ── onFriendshipCreated ──────────────────────────────────────────────────────

describe("onFriendshipCreated", () => {
  const friendshipId = "uid-alice_uid-bob";
  const uid1 = "uid-alice";
  const uid2 = "uid-bob";

  test("writes both RTDB friends nodes when friendship is created", async () => {
    await adminFirestoreSet(`friendships/${friendshipId}`, {
      users: [uid1, uid2],
      displayNames: {[uid1]: "Alice", [uid2]: "Bob"},
      chatRoomId: friendshipId,
    });

    await waitUntilRtdbValue(`friends/${uid1}/${uid2}`, (snap) => snap.exists, {
      timeout: 15_000,
    });

    const node1 = await rtdbGet(`friends/${uid1}/${uid2}`);
    const node2 = await rtdbGet(`friends/${uid2}/${uid1}`);
    expect(node1.exists).toBe(true);
    expect(node2.exists).toBe(true);
  });

  test("handles missing users array without writing RTDB nodes", async () => {
    await adminFirestoreSet(`friendships/${friendshipId}`, {
      displayNames: {[uid1]: "Alice", [uid2]: "Bob"},
      chatRoomId: friendshipId,
      // users field intentionally absent
    });

    // Wait briefly for the CF to fire; both nodes must stay absent
    await new Promise((r) => setTimeout(r, 3_000));

    const node1 = await rtdbGet(`friends/${uid1}/${uid2}`);
    const node2 = await rtdbGet(`friends/${uid2}/${uid1}`);
    expect(node1.exists).toBe(false);
    expect(node2.exists).toBe(false);
  });
});

// ── onFriendshipDeleted ───────────────────────────────────────────────────────

describe("onFriendshipDeleted", () => {
  const friendshipId = "uid-alice_uid-bob";
  const uid1 = "uid-alice";
  const uid2 = "uid-bob";

  /**
   * Seeds a friendship doc, friend_messages subcollection, and RTDB friends
   * nodes, then deletes the friendship doc to trigger onFriendshipDeleted.
   */
  async function seedAndDelete(): Promise<void> {
    await adminFirestoreSet(`friendships/${friendshipId}`, {
      users: [uid1, uid2],
      displayNames: {[uid1]: "Alice", [uid2]: "Bob"},
      chatRoomId: friendshipId,
    });

    await adminFirestoreSet(`friend_messages/${friendshipId}/messages/msg-1`, {
      senderId: uid1,
      senderDisplayName: "Alice",
      text: "hey",
      timestamp: 1000,
    });
    await adminFirestoreSet(`friend_messages/${friendshipId}/messages/msg-2`, {
      senderId: uid2,
      senderDisplayName: "Bob",
      text: "hi",
      timestamp: 2000,
    });

    await rtdbSet(`friends/${uid1}/${uid2}`, true);
    await rtdbSet(`friends/${uid2}/${uid1}`, true);

    await adminFirestoreDelete(`friendships/${friendshipId}`);
  }

  test("deletes friend_messages subcollection when friendship is removed", async () => {
    await seedAndDelete();

    await waitUntilAdminDocMatches(
      `friend_messages/${friendshipId}/messages/msg-1`,
      (doc) => doc === null,
      {timeout: 15_000},
    );

    const messages = await adminFirestoreList(
      `friend_messages/${friendshipId}/messages`,
    );
    expect(messages).toHaveLength(0);
  });

  test("removes both RTDB friends nodes when friendship is deleted", async () => {
    await seedAndDelete();

    await waitUntilRtdbValue(
      `friends/${uid1}/${uid2}`,
      (snap) => !snap.exists,
      {timeout: 15_000},
    );

    const node1 = await rtdbGet(`friends/${uid1}/${uid2}`);
    const node2 = await rtdbGet(`friends/${uid2}/${uid1}`);
    expect(node1.exists).toBe(false);
    expect(node2.exists).toBe(false);
  });

  test("handles missing users array without throwing", async () => {
    await adminFirestoreSet(`friendships/${friendshipId}`, {
      displayNames: {[uid1]: "Alice", [uid2]: "Bob"},
      chatRoomId: friendshipId,
      // users field intentionally absent
    });

    await adminFirestoreSet(`friend_messages/${friendshipId}/messages/msg-1`, {
      senderId: uid1,
      senderDisplayName: "Alice",
      text: "hey",
      timestamp: 1000,
    });

    await adminFirestoreDelete(`friendships/${friendshipId}`);

    await waitUntilAdminDocMatches(
      `friend_messages/${friendshipId}/messages/msg-1`,
      (doc) => doc === null,
      {timeout: 15_000},
    );

    const messages = await adminFirestoreList(
      `friend_messages/${friendshipId}/messages`,
    );
    expect(messages).toHaveLength(0);
  });
});
