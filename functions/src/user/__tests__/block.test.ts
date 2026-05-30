/**
 * Unit tests for the blocking Cloud Functions and _blockUtils pure helpers.
 *
 * Covers:
 *   - blockUser: auth guards, argument validation, idempotency, limit enforcement
 *   - unblockUser: auth guards, argument validation, delete call
 *   - adminGetBlockedUsers: auth guards, admin check, list shape
 *   - _blockUtils pure functions: mergeIntoBlockList, removeFromBlockList, isBlockedByRoom
 */

import {HttpsError} from "firebase-functions/v2/https";
import type {CallableRequest} from "firebase-functions/v2/https";

// ── Firebase-admin mock ───────────────────────────────────────────────────────
// All Firestore chain methods start as jest.fn() returning `{}` by default.
// Individual tests override `mockResolvedValueOnce` / `mockReturnValueOnce`
// where the CF code inspects the result.

const mockDelete = jest.fn().mockResolvedValue(undefined);
const mockUpdate = jest.fn().mockResolvedValue(undefined);
const mockSet = jest.fn().mockResolvedValue(undefined);
const mockGet = jest.fn();
const mockOrderBy = jest.fn();
const mockDoc = jest.fn();
const mockCollection = jest.fn();

// `runTransaction(fn)` invokes the callback with a tx that proxies the same
// terminal Firestore mocks, so the get/set/update expectations below apply
// unchanged whether the CF reads/writes directly or inside a transaction.
const mockRunTransaction = jest.fn(
  (fn: (tx: unknown) => unknown) =>
    Promise.resolve(
      fn({get: mockGet, set: mockSet, update: mockUpdate, delete: mockDelete}),
    ),
);

// `orderBy` returns an object whose `get` resolves to a snap.
mockOrderBy.mockReturnValue({get: mockGet});

// `doc` returns an object whose methods are the terminal Firestore ops.
mockDoc.mockReturnValue({
  get: mockGet,
  set: mockSet,
  update: mockUpdate,
  delete: mockDelete,
  collection: mockCollection,
});

// `collection` returns an object with `doc`, `get`, and `orderBy`.
mockCollection.mockReturnValue({
  doc: mockDoc,
  get: mockGet,
  orderBy: mockOrderBy,
});

// `firestore()` returns an object with `collection`.
const mockFirestore = jest.fn().mockReturnValue({
  collection: mockCollection,
  runTransaction: mockRunTransaction,
});

jest.mock("firebase-admin", () => ({
  firestore: mockFirestore,
}));

jest.mock("firebase-admin/firestore", () => ({
  FieldValue: {serverTimestamp: jest.fn().mockReturnValue("__serverTimestamp__")},
  Timestamp: jest.fn(),
}));

jest.mock("firebase-functions/logger", () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

// `onCall` is used by the CF files only to wrap the handler. We bypass it by
// importing the raw handler directly after replacing the export with an
// identity wrapper.
jest.mock("firebase-functions/v2/https", () => {
  const original = jest.requireActual<typeof import("firebase-functions/v2/https")>(
    "firebase-functions/v2/https",
  );
  return {
    ...original,
    // Return a fake callable whose `.run` invokes the handler so tests can call
    // it directly. We also expose the handler on `.handler` for convenience.
    onCall: (_opts: unknown, handler: (req: CallableRequest) => unknown) => ({
      run: handler,
    }),
  };
});

// `requireAdmin` is used by adminGetBlockedUsers — mock at module level so
// individual tests can override the resolved value.
const mockRequireAdmin = jest.fn();
jest.mock("../../admin/_utils", () => ({
  requireAdmin: (...args: unknown[]) => mockRequireAdmin(...args),
}));

// ── Import CFs after mocks are in place ──────────────────────────────────────

import {blockUser} from "../blockUser";
import {unblockUser} from "../unblockUser";
import {adminGetBlockedUsers} from "../../admin/adminGetBlockedUsers";
import {
  mergeIntoBlockList,
  removeFromBlockList,
  isBlockedByRoom,
  BlockListEntry,
} from "../_blockUtils";

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Builds a minimal CallableRequest for unit tests.
 * @param {Record<string, unknown>} data - CF input payload.
 * @param {string | null} uid - Authenticated uid, or null for unauthenticated.
 * @return {CallableRequest}
 */
function makeRequest(
  data: Record<string, unknown>,
  uid: string | null = "caller-uid",
): CallableRequest {
  return {
    data,
    auth: uid ? {uid, token: {} as CallableRequest["auth"]["token"]} : undefined,
    rawRequest: {} as CallableRequest["rawRequest"],
    acceptsStreaming: false,
  } as unknown as CallableRequest;
}

/**
 * Calls the inner handler extracted from an `onCall` wrapper.
 * @param {{ run: (req: CallableRequest) => unknown }} fn - Wrapped callable.
 * @param {CallableRequest} req - Request to pass to the handler.
 * @return {Promise<unknown>}
 */
async function invoke(
  fn: {run: (req: CallableRequest) => unknown},
  req: CallableRequest,
): Promise<unknown> {
  return fn.run(req);
}

// ── blockUser ─────────────────────────────────────────────────────────────────

describe("blockUser", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Default `doc().collection()` chain: return an object with doc, get, orderBy.
    mockCollection.mockReturnValue({
      doc: mockDoc,
      get: mockGet,
      orderBy: mockOrderBy,
    });
    mockDoc.mockReturnValue({
      get: mockGet,
      set: mockSet,
      update: mockUpdate,
      delete: mockDelete,
      collection: mockCollection,
    });
    mockOrderBy.mockReturnValue({get: mockGet});
    mockFirestore.mockReturnValue({
      collection: mockCollection,
      runTransaction: mockRunTransaction,
    });
  });

  test("throws unauthenticated if not signed in", async () => {
    const req = makeRequest({targetUid: "target-uid"}, null);
    await expect(invoke(blockUser as {run: (r: CallableRequest) => unknown}, req)).rejects.toThrow(
      HttpsError,
    );
    await expect(
      invoke(blockUser as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "unauthenticated"});
  });

  test("throws invalid-argument if targetUid missing", async () => {
    const req = makeRequest({});
    await expect(
      invoke(blockUser as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "invalid-argument"});
  });

  test("throws invalid-argument if blocking yourself", async () => {
    const req = makeRequest({targetUid: "caller-uid"});
    await expect(
      invoke(blockUser as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "invalid-argument"});
  });

  test("returns success:true when blocking a new user", async () => {
    // existingSnap.exists = false; countSnap.size = 0
    mockGet
      .mockResolvedValueOnce({exists: false}) // targetRef.get()
      .mockResolvedValueOnce({size: 0}); // blockedCollRef.get()

    const req = makeRequest({targetUid: "target-uid", displayName: "Alice"});
    const result = await invoke(blockUser as {run: (r: CallableRequest) => unknown}, req);
    expect(result).toEqual({success: true});
    expect(mockSet).toHaveBeenCalledTimes(1);
    // The read-check-write sequence must run inside a transaction so the
    // 5-block cap cannot be bypassed by concurrent calls.
    expect(mockRunTransaction).toHaveBeenCalledTimes(1);
  });

  test("returns max_blocked_reached when at limit (5 blocked)", async () => {
    // existingSnap.exists = false; countSnap.size = 5 (at limit)
    mockGet
      .mockResolvedValueOnce({exists: false})
      .mockResolvedValueOnce({size: 5});

    const req = makeRequest({targetUid: "target-uid"});
    const result = await invoke(blockUser as {run: (r: CallableRequest) => unknown}, req);
    expect(result).toEqual({success: false, reason: "max_blocked_reached"});
    expect(mockSet).not.toHaveBeenCalled();
  });

  test("is idempotent when already blocked (returns success:true)", async () => {
    // existingSnap.exists = true — should skip limit check and return success
    mockGet.mockResolvedValueOnce({exists: true});

    const req = makeRequest({targetUid: "target-uid"});
    const result = await invoke(blockUser as {run: (r: CallableRequest) => unknown}, req);
    expect(result).toEqual({success: true});
    expect(mockSet).not.toHaveBeenCalled();
  });

  test("throws invalid-argument if displayName is not a string", async () => {
    const req = makeRequest({targetUid: "target-uid", displayName: 42});
    await expect(
      invoke(blockUser as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "invalid-argument"});
  });
});

// ── unblockUser ───────────────────────────────────────────────────────────────

describe("unblockUser", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    mockCollection.mockReturnValue({
      doc: mockDoc,
      get: mockGet,
      orderBy: mockOrderBy,
    });
    mockDoc.mockReturnValue({
      get: mockGet,
      set: mockSet,
      update: mockUpdate,
      delete: mockDelete,
      collection: mockCollection,
    });
    mockFirestore.mockReturnValue({
      collection: mockCollection,
      runTransaction: mockRunTransaction,
    });
  });

  test("throws unauthenticated if not signed in", async () => {
    const req = makeRequest({targetUid: "target-uid"}, null);
    await expect(
      invoke(unblockUser as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "unauthenticated"});
  });

  test("throws invalid-argument if targetUid missing", async () => {
    const req = makeRequest({});
    await expect(
      invoke(unblockUser as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "invalid-argument"});
  });

  test("returns success:true on successful unblock", async () => {
    mockDelete.mockResolvedValueOnce(undefined);

    const req = makeRequest({targetUid: "target-uid"});
    const result = await invoke(unblockUser as {run: (r: CallableRequest) => unknown}, req);
    expect(result).toEqual({success: true});
    expect(mockDelete).toHaveBeenCalledTimes(1);
  });
});

// ── adminGetBlockedUsers ──────────────────────────────────────────────────────

describe("adminGetBlockedUsers", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    mockCollection.mockReturnValue({
      doc: mockDoc,
      get: mockGet,
      orderBy: mockOrderBy,
    });
    mockDoc.mockReturnValue({
      get: mockGet,
      set: mockSet,
      update: mockUpdate,
      delete: mockDelete,
      collection: mockCollection,
    });
    mockOrderBy.mockReturnValue({get: mockGet});
    mockFirestore.mockReturnValue({
      collection: mockCollection,
      runTransaction: mockRunTransaction,
    });
  });

  test("throws unauthenticated if not signed in", async () => {
    mockRequireAdmin.mockRejectedValueOnce(
      new HttpsError("unauthenticated", "Must be signed in."),
    );
    const req = makeRequest({uid: "some-uid"}, null);
    await expect(
      invoke(adminGetBlockedUsers as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "unauthenticated"});
  });

  test("throws permission-denied if not admin", async () => {
    mockRequireAdmin.mockRejectedValueOnce(
      new HttpsError("permission-denied", "Admin access required."),
    );
    const req = makeRequest({uid: "some-uid"});
    await expect(
      invoke(adminGetBlockedUsers as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "permission-denied"});
  });

  test("throws invalid-argument if uid missing", async () => {
    mockRequireAdmin.mockResolvedValueOnce({uid: "admin-uid", displayName: "Admin"});
    const req = makeRequest({});
    await expect(
      invoke(adminGetBlockedUsers as {run: (r: CallableRequest) => unknown}, req),
    ).rejects.toMatchObject({code: "invalid-argument"});
  });

  test("returns blocked users list for a valid uid", async () => {
    mockRequireAdmin.mockResolvedValueOnce({uid: "admin-uid", displayName: "Admin"});

    const fakeTs = {toDate: () => new Date("2024-01-15T10:00:00.000Z")};
    const fakeDocs = [
      {id: "uid-A", data: () => ({displayName: "Alice", blockedAt: fakeTs})},
      {id: "uid-B", data: () => ({displayName: null, blockedAt: null})},
    ];
    mockGet.mockResolvedValueOnce({docs: fakeDocs});

    const req = makeRequest({uid: "target-uid"});
    const result = (await invoke(
      adminGetBlockedUsers as {run: (r: CallableRequest) => unknown},
      req,
    )) as {blockedUsers: Array<{uid: string; displayName: string | null; blockedAt: string | null}>};

    expect(result.blockedUsers).toHaveLength(2);
    expect(result.blockedUsers[0]).toEqual({
      uid: "uid-A",
      displayName: "Alice",
      blockedAt: "2024-01-15T10:00:00.000Z",
    });
    expect(result.blockedUsers[1]).toEqual({
      uid: "uid-B",
      displayName: null,
      blockedAt: null,
    });
  });

  test("returns empty array when user has no blocked users", async () => {
    mockRequireAdmin.mockResolvedValueOnce({uid: "admin-uid", displayName: "Admin"});
    mockGet.mockResolvedValueOnce({docs: []});

    const req = makeRequest({uid: "target-uid"});
    const result = (await invoke(
      adminGetBlockedUsers as {run: (r: CallableRequest) => unknown},
      req,
    )) as {blockedUsers: unknown[]};

    expect(result.blockedUsers).toEqual([]);
  });
});

// ── _blockUtils pure functions ────────────────────────────────────────────────
// These tests need no Firebase mocks — the functions are pure TypeScript.

describe("mergeIntoBlockList", () => {
  test("adds new entry when userId not present", () => {
    const current: BlockListEntry[] = [];
    const result = mergeIntoBlockList(current, "user-A", ["user-B"]);
    expect(result).toEqual([{blockedBy: "user-A", userId: "user-B", amount: 1}]);
  });

  test("increments amount when userId already in list", () => {
    const current: BlockListEntry[] = [{blockedBy: "user-A", userId: "user-B", amount: 1}];
    const result = mergeIntoBlockList(current, "user-C", ["user-B"]);
    expect(result).toHaveLength(1);
    expect(result[0].amount).toBe(2);
  });
});

describe("removeFromBlockList", () => {
  test("decrements amount and removes entries that reach zero", () => {
    const current: BlockListEntry[] = [
      {blockedBy: "user-A", userId: "user-B", amount: 1},
      {blockedBy: "user-A", userId: "user-C", amount: 2},
    ];
    const result = removeFromBlockList(current, ["user-B", "user-C"]);
    // user-B (1→0) removed; user-C (2→1) kept
    expect(result).toHaveLength(1);
    expect(result[0].userId).toBe("user-C");
    expect(result[0].amount).toBe(1);
  });
});

describe("isBlockedByRoom", () => {
  test("returns true when uid is in blockList", () => {
    const blockList: BlockListEntry[] = [
      {blockedBy: "user-A", userId: "user-B", amount: 1},
    ];
    expect(isBlockedByRoom(blockList, "user-B")).toBe(true);
  });

  test("returns false when uid not in blockList", () => {
    const blockList: BlockListEntry[] = [
      {blockedBy: "user-A", userId: "user-B", amount: 1},
    ];
    expect(isBlockedByRoom(blockList, "user-X")).toBe(false);
  });
});
