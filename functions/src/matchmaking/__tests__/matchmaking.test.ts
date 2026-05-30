import {
  signInAnon,
  signOut,
  callFn,
  resetEmulatorData,
  rtdbGet,
  waitUntilRtdbValue,
  adminFirestoreDoc,
  adminFirestoreUpdate,
  adminFirestoreSet,
  waitUntilAdminDocMatches,
  tryLeaveRoom,
  tryCancelPool,
  buildRoom,
  sleep,
  callScheduledFn,
} from "./helpers";

// Warm up the emulator before the suite runs. The first CF invocation after
// emulator start triggers JIT compilation and can take 60-90 s. Absorbing that
// cost here means no individual test needs an inflated timeout.
beforeAll(async () => {
  await signInAnon();
  await callFn("joinGroupRoom").catch(() => {});
  signOut();
  await resetEmulatorData();
}, 120_000);

beforeEach(async () => {
  await signOut();
  await resetEmulatorData();
}, 15_000);

afterEach(async () => {
  signOut();
  await resetEmulatorData();
}, 15_000);

// ── Group Room: Priority Selection ─────────────────────────────────────────

describe("priority", () => {
  test("1-member room chosen over 2-member room", async () => {
    const roomA = await buildRoom(2);
    const roomB = await buildRoom(1);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(roomB);

    const docA = await adminFirestoreDoc(`rooms/${roomA}`);
    expect(docA!["memberCount"]).toBe(2);
    await tryLeaveRoom(res["roomId"] as string);
  }, 120_000);

  test("1-member room chosen when competing with 3-member and 4-member rooms", async () => {
    const roomA = await buildRoom(4);
    const roomB = await buildRoom(3);
    const roomC = await buildRoom(1);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(roomC);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomA}`),
      adminFirestoreDoc(`rooms/${roomB}`),
    ]);
    expect(docs[0]!["memberCount"]).toBe(4);
    expect(docs[1]!["memberCount"]).toBe(3);
    await tryLeaveRoom(res["roomId"] as string);
  });

  test("1-member room wins from mixed field (1/5, 2/5, 3/5, 4/5)", async () => {
    const room4 = await buildRoom(4);
    const room2 = await buildRoom(2);
    const room3 = await buildRoom(3);
    const room1 = await buildRoom(1);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(room1);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${room4}`),
      adminFirestoreDoc(`rooms/${room2}`),
      adminFirestoreDoc(`rooms/${room3}`),
    ]);
    expect(docs[0]!["memberCount"]).toBe(4);
    expect(docs[1]!["memberCount"]).toBe(2);
    expect(docs[2]!["memberCount"]).toBe(3);
    await tryLeaveRoom(res["roomId"] as string);
  });

  test("priority distribution: 15 consecutive joiners spread randomly across 3 one-member rooms", async () => {
    const roomX = await buildRoom(1);
    const roomY = await buildRoom(1);
    const roomZ = await buildRoom(1);
    const knownRooms = new Set([roomX, roomY, roomZ]);
    const counts: Record<string, number> = {[roomX]: 0, [roomY]: 0, [roomZ]: 0};

    for (let i = 0; i < 15; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;

      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(2);
    // Sanity bound: P(max ≥ 14 out of 15) ≈ 0.00065% with uniform 3-room dist.
    expect(Math.max(...Object.values(counts))).toBeLessThan(14);
  });

  test("after first 1-member room fills, next joiner picks the remaining 1-member room", async () => {
    const roomX = await buildRoom(1);
    const roomY = await buildRoom(1);

    signOut();
    await signInAnon();
    const resU = await callFn("joinGroupRoom");
    const joinedByU = resU["roomId"] as string;
    expect([roomX, roomY]).toContain(joinedByU);
    const remaining = joinedByU === roomX ? roomY : roomX;

    signOut();
    await signInAnon();
    const resV = await callFn("joinGroupRoom");
    expect(resV["roomId"]).toBe(remaining);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomX}`),
      adminFirestoreDoc(`rooms/${roomY}`),
    ]);
    expect(docs[0]!["memberCount"]).toBe(2);
    expect(docs[1]!["memberCount"]).toBe(2);
    await tryLeaveRoom(resV["roomId"] as string);
  });

  test("priority load test: 20 joiners across 5 one-member rooms", async () => {
    const rooms: string[] = [];
    for (let i = 0; i < 5; i++) {
      rooms.push(await buildRoom(1));
    }
    const knownRooms = new Set(rooms);
    const counts: Record<string, number> = Object.fromEntries(
      rooms.map((r) => [r, 0]),
    );

    for (let i = 0; i < 20; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;

      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(3);
    // Sanity bound only: catches a completely degenerate picker (all 20 into
    // one room). Not a distribution test — tight bounds on 20 samples are
    // statistically flaky (~11% failure at <8 with uniform 5-room distribution).
    expect(Math.max(...Object.values(counts))).toBeLessThan(16);
  });

  test("priority concurrent race: two rapid joiners to the same 1-member room", async () => {
    const roomX = await buildRoom(1);

    signOut();
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const joinedA = resA["roomId"] as string;

    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom");
    const joinedB = resB["roomId"] as string;

    expect(resA["roomId"]).not.toBeNull();
    expect(resB["roomId"]).not.toBeNull();

    if (joinedA === roomX && joinedB === roomX) {
      const doc = await adminFirestoreDoc(`rooms/${roomX}`);
      const users = doc!["users"] as string[];
      expect(new Set(users).size).toBe(users.length);
      expect(users).toContain(uidA);
    }

    const roomDoc = await adminFirestoreDoc(`rooms/${roomX}`);
    expect(roomDoc!["memberCount"]).toBeLessThanOrEqual(5);
    await tryLeaveRoom(joinedB);
  });
});

// ── Group Room: Secondary Randomness ──────────────────────────────────────

describe("secondary randomness", () => {
  test("15 joiners spread across 3 two-member rooms", async () => {
    const roomA = await buildRoom(2);
    const roomB = await buildRoom(2);
    const roomC = await buildRoom(2);
    const knownRooms = new Set([roomA, roomB, roomC]);
    const counts: Record<string, number> = {[roomA]: 0, [roomB]: 0, [roomC]: 0};

    for (let i = 0; i < 15; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;

      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(2);
    // Sanity bound: P(max ≥ 14 out of 15) ≈ 0.00065% with uniform 3-room dist.
    expect(Math.max(...Object.values(counts))).toBeLessThan(14);
  });

  test("repeated join-leave by same user does not always hit same room", async () => {
    await buildRoom(3);
    await buildRoom(3);
    await buildRoom(3);

    const visited = new Set<string>();

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;
      visited.add(joined);
      await callFn("leaveRoom", {roomId: joined});
    }

    expect(visited.size).toBeGreaterThanOrEqual(2);
  });

  test("joins distributed across rooms of different sizes (2/5, 3/5, 4/5)", async () => {
    const roomA = await buildRoom(2);
    const roomB = await buildRoom(3);
    const roomC = await buildRoom(4);
    const knownRooms = new Set([roomA, roomB, roomC]);
    const counts: Record<string, number> = {[roomA]: 0, [roomB]: 0, [roomC]: 0};

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;
      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(2);
  });

  test("all secondary rooms fill up → new room created", async () => {
    const roomA = await buildRoom(4);

    signOut();
    await signInAnon();
    await callFn("joinRoomById", {roomId: roomA});
    expect((await adminFirestoreDoc(`rooms/${roomA}`))!["memberCount"]).toBe(5);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    expect(res["isNewRoom"]).toBe(true);
    expect(res["roomId"]).not.toBe(roomA);
    await tryLeaveRoom(res["roomId"] as string);
  });
});

// ── Padding: Not Joinable ──────────────────────────────────────────────────

describe("padding", () => {
  test("last user leaves → padding → next joiner creates new room", async () => {
    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    const originalRoomId = res["roomId"] as string;
    await callFn("leaveRoom", {roomId: originalRoomId});

    const paddingDoc = await adminFirestoreDoc(`rooms/${originalRoomId}`);
    expect(paddingDoc!["status"]).toBe("padding");
    expect(paddingDoc!["memberCount"]).toBe(0);

    signOut();
    await signInAnon();
    const newRes = await callFn("joinGroupRoom");
    expect(newRes["isNewRoom"]).toBe(true);
    expect(newRes["roomId"]).not.toBe(originalRoomId);

    const stillPadding = await adminFirestoreDoc(`rooms/${originalRoomId}`);
    expect(stillPadding!["status"]).toBe("padding");
    await tryLeaveRoom(newRes["roomId"] as string);
  });

  test("joinRoomById on padding room throws failed-precondition", async () => {
    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    const roomId = res["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    expect((await adminFirestoreDoc(`rooms/${roomId}`))!["status"]).toBe(
      "padding",
    );

    signOut();
    await signInAnon();
    try {
      await callFn("joinRoomById", {roomId});
      throw new Error("expected exception for padding room");
    } catch (e) {
      expect((e as Error).message).toContain("failed-precondition");
    }
  });

  test("expired room via joinRoomById throws an error", async () => {
    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    const roomId = res["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    signOut();
    await signInAnon();
    try {
      await callFn("joinRoomById", {roomId});
      throw new Error("expected exception for unavailable room");
    } catch (e) {
      expect((e as Error).message).toMatch(/failed-precondition|not-found/);
    }
  });

  test("1v1 room in padding is not returned by joinGroupRoom", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const v1RoomId = poolDoc!["roomId"] as string;

    await callFn("leaveRoom", {roomId: v1RoomId});

    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );
    await tryCancelPool();

    signOut();
    await signInAnon();
    const groupRes = await callFn("joinGroupRoom");
    expect(groupRes["isNewRoom"]).toBe(true);
    expect(groupRes["roomId"]).not.toBe(v1RoomId);

    const v1Doc = await adminFirestoreDoc(`rooms/${v1RoomId}`);
    expect(v1Doc!["mode"]).toBe("1v1");
    expect(v1Doc!["status"]).toBe("padding");
    await tryLeaveRoom(groupRes["roomId"] as string);
  });
});

// ── RTDB & Edge Cases ──────────────────────────────────────────────────────

describe("RTDB and edge cases", () => {
  test("membership set for both creator and joiner", async () => {
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomId = resA["roomId"] as string;

    signOut();
    const uidB = await signInAnon();
    await callFn("joinGroupRoom");

    const [snapA, snapB] = await Promise.all([
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidA}`, (s) => s.exists),
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidB}`, (s) => s.exists),
    ]);
    expect(snapA.value).toBe(true);
    expect(snapB.value).toBe(true);

    await tryLeaveRoom(roomId);
  });

  test("leaveRoom cleans typing and presence paths (not just members)", async () => {
    await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomId = resA["roomId"] as string;

    signOut();
    const uidB = await signInAnon();
    await callFn("joinGroupRoom");
    await callFn("leaveRoom", {roomId});

    const [typing, presence, member] = await Promise.all([
      rtdbGet(`typing/${roomId}/${uidB}`),
      rtdbGet(`presence/${roomId}/${uidB}`),
      rtdbGet(`rooms/${roomId}/members/${uidB}`),
    ]);
    expect(typing.exists).toBe(false);
    expect(presence.exists).toBe(false);
    expect(member.exists).toBe(false);

    await tryLeaveRoom(roomId);
  });

  test("full room (5/5): joinGroupRoom creates new room; joinRoomById throws", async () => {
    const roomA = await buildRoom(4);

    signOut();
    await signInAnon();
    await callFn("joinRoomById", {roomId: roomA});
    expect((await adminFirestoreDoc(`rooms/${roomA}`))!["memberCount"]).toBe(5);

    signOut();
    await signInAnon();
    const newRes = await callFn("joinGroupRoom");
    expect(newRes["isNewRoom"]).toBe(true);
    expect(newRes["roomId"]).not.toBe(roomA);

    try {
      await callFn("joinRoomById", {roomId: roomA});
      throw new Error("expected exception for full room");
    } catch (e) {
      expect((e as Error).message).toMatch(
        /resource-exhausted|failed-precondition/,
      );
    }
    await tryLeaveRoom(newRes["roomId"] as string);
  });

  test("locked room excluded from joinGroupRoom; unlocked room still joinable", async () => {
    const roomA = await buildRoom(1);
    await callFn("setRoomLock", {roomId: roomA, isLocked: true});

    const roomB = await buildRoom(3);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(roomB);
    expect((await adminFirestoreDoc(`rooms/${roomA}`))!["memberCount"]).toBe(1);

    await tryLeaveRoom(roomB);
  });

  test("user already in room: joinGroupRoom produces no duplicate in users array", async () => {
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomId = resA["roomId"] as string;

    const resA2 = await callFn("joinGroupRoom");

    const doc = await adminFirestoreDoc(`rooms/${roomId}`);
    const users = doc!["users"] as string[];
    expect(users.filter((u) => u === uidA).length).toBeLessThanOrEqual(1);

    await tryLeaveRoom(roomId);
    const secondRoom = resA2["roomId"] as string;
    if (secondRoom !== roomId) await tryLeaveRoom(secondRoom);
  });
});

// ── 1v1 Pool & Match Trigger ───────────────────────────────────────────────

describe("1v1 pool and match", () => {
  test("join1v1Pool: pool entry has all required fields", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["status"]).toBe("waiting");
    expect(doc!["mode"]).toBe("1v1");
    expect(doc!["roomId"]).toBeNull();
    expect(doc!["createdAt"]).not.toBeNull();
    expect(doc!["updatedAt"]).not.toBeNull();

    await tryCancelPool();
  });

  test("match1v1Users trigger: two users matched with correct room and RTDB membership", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    expect(roomId).toHaveLength(5);

    const roomDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(roomDoc!["mode"]).toBe("1v1");
    expect(roomDoc!["status"]).toBe("active");
    expect(roomDoc!["memberCount"]).toBe(2);
    expect(roomDoc!["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidB]),
    );

    // match1v1Users writes Firestore (status=matched) before RTDB members —
    // poll until both entries are visible rather than reading immediately.
    const [rtdbA, rtdbB] = await Promise.all([
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidA}`, (s) => s.exists, {
        timeout: 20_000,
      }),
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidB}`, (s) => s.exists, {
        timeout: 20_000,
      }),
    ]);
    expect(rtdbA.value).toBe(true);
    expect(rtdbB.value).toBe(true);

    await callFn("leaveRoom", {roomId});
  });

  test("match1v1Users: single user in pool stays waiting — trigger handles no-candidate", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");

    await sleep(5000);

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["status"]).toBe("waiting");

    await tryCancelPool();
  });

  test("match1v1Users: 3 users in pool — first two matched, third stays waiting", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();

    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    await sleep(5000);

    const docs = await Promise.all([
      adminFirestoreDoc(`waiting_pool/${uidA}`),
      adminFirestoreDoc(`waiting_pool/${uidB}`),
      adminFirestoreDoc(`waiting_pool/${uidC}`),
    ]);

    expect(docs[0]!["status"]).toBe("matched");
    expect(docs[1]!["status"]).toBe("matched");
    expect(docs[0]!["roomId"]).toBe(docs[1]!["roomId"]);
    expect(docs[2]!["status"]).toBe("waiting");

    await tryCancelPool();
    await tryLeaveRoom(docs[0]!["roomId"] as string);
  });

  test("match1v1Users scale: 10 users → 5 pairs all matched correctly", async () => {
    const uids: string[] = [];
    for (let i = 0; i < 10; i++) {
      signOut();
      uids.push(await signInAnon());
      await callFn("join1v1Pool");
      await sleep(50);
    }

    const poolDocs = await Promise.all(
      uids.map((uid) =>
        waitUntilAdminDocMatches(
          `waiting_pool/${uid}`,
          (d) => d?.["status"] === "matched",
        ),
      ),
    );

    for (let i = 0; i < 10; i++) {
      expect(poolDocs[i]!["status"]).toBe("matched");
    }

    const roomIdSet = new Set(poolDocs.map((d) => d!["roomId"] as string));
    expect(roomIdSet.size).toBe(5);

    const roomDocs = await Promise.all(
      [...roomIdSet].map((id) => adminFirestoreDoc(`rooms/${id}`)),
    );
    for (const doc of roomDocs) {
      expect(doc!["memberCount"]).toBe(2);
      expect((doc!["users"] as string[]).length).toBe(2);
      expect(doc!["mode"]).toBe("1v1");
    }

    for (const id of roomIdSet) {
      await tryLeaveRoom(id);
    }
  });

  test("join1v1Pool idempotent: calling twice recreates entry without error", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");
    expect((await adminFirestoreDoc(`waiting_pool/${uid}`))!["status"]).toBe(
      "waiting",
    );

    await callFn("join1v1Pool");
    expect((await adminFirestoreDoc(`waiting_pool/${uid}`))!["status"]).toBe(
      "waiting",
    );

    await tryCancelPool();
  });

  test("cancel1v1Pool: entry deleted; re-join creates fresh entry", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");
    await callFn("cancel1v1Pool");

    expect(await adminFirestoreDoc(`waiting_pool/${uid}`)).toBeNull();

    await callFn("join1v1Pool");
    const recreated = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(recreated!["status"]).toBe("waiting");

    await tryCancelPool();
  });
});

// ── 1v1 Leave & Requeue ───────────────────────────────────────────────────

describe("1v1 leave and requeue", () => {
  test("leaveRoom (1v1): room enters 30-second padding — not 5-minute group padding", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    const roomDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(roomDoc!["status"]).toBe("padding");

    const paddingUntil = roomDoc!["paddingUntil"];
    expect(paddingUntil).not.toBeNull();

    const paddingMs = new Date(paddingUntil as string).getTime();
    const diffSeconds = (paddingMs - Date.now()) / 1000;
    // Upper bound of 35s since both client and server run on the same host
    // (no Android emulator clock skew).
    expect(diffSeconds).toBeLessThan(35);
    expect(diffSeconds).toBeGreaterThan(0);
  });

  test("leaveRoom (1v1): remaining user gets fresh waiting_pool entry (delete+set fix)", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    const requeuedDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );
    expect(requeuedDoc!["status"]).toBe("waiting");
    expect(requeuedDoc!["mode"]).toBe("1v1");
    expect(requeuedDoc!["roomId"]).toBeNull();
  });

  test("leaveRoom (1v1): RTDB cleared for both users including remaining user", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    const [snapA, snapB] = await Promise.all([
      rtdbGet(`rooms/${roomId}/members/${uidA}`),
      rtdbGet(`rooms/${roomId}/members/${uidB}`),
    ]);
    expect(snapA.exists).toBe(false);
    expect(snapB.exists).toBe(false);
  });

  test("leaveRoom (1v1): typing and presence RTDB paths removed for leaving user", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    const [typing, presence] = await Promise.all([
      rtdbGet(`typing/${roomId}/${uidB}`),
      rtdbGet(`presence/${roomId}/${uidB}`),
    ]);
    expect(typing.exists).toBe(false);
    expect(presence.exists).toBe(false);
  });
});

// ── Complete User Flows ────────────────────────────────────────────────────

describe("flows", () => {
  test("full 1v1 lifecycle — pool → match → RTDB → leave → requeue → cancel", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    expect((await adminFirestoreDoc(`waiting_pool/${uidA}`))!["status"]).toBe(
      "waiting",
    );

    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolB!["roomId"] as string;

    const roomDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(roomDoc!["mode"]).toBe("1v1");
    expect(roomDoc!["memberCount"]).toBe(2);

    // match1v1Users writes Firestore before RTDB — poll until both entries appear.
    const [snapA, snapB] = await Promise.all([
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidA}`, (s) => s.exists, {
        timeout: 20_000,
      }),
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidB}`, (s) => s.exists, {
        timeout: 20_000,
      }),
    ]);
    expect(snapA.value).toBe(true);
    expect(snapB.value).toBe(true);

    await callFn("leaveRoom", {roomId});
    expect((await adminFirestoreDoc(`rooms/${roomId}`))!["status"]).toBe(
      "padding",
    );

    const requeuedA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );
    expect(requeuedA!["status"]).toBe("waiting");

    await tryCancelPool();
  });

  test("1v1 chain — A+B match → B leaves → A+C match in new room", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId1 = poolB!["roomId"] as string;

    await callFn("leaveRoom", {roomId: roomId1});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    expect((await adminFirestoreDoc(`rooms/${roomId1}`))!["status"]).toBe(
      "padding",
    );

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    const poolC = await waitUntilAdminDocMatches(
      `waiting_pool/${uidC}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId2 = poolC!["roomId"] as string;

    expect(roomId2).not.toBe(roomId1);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomId2}`),
      adminFirestoreDoc(`rooms/${roomId1}`),
    ]);
    expect(docs[0]!["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidC]),
    );
    expect(docs[1]!["status"]).toBe("padding");

    await callFn("leaveRoom", {roomId: roomId2});
  });

  test("group room lifecycle — fill to 3 → sequential leaves → padding → new user gets new room", async () => {
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomX = resA["roomId"] as string;
    expect(resA["isNewRoom"]).toBe(true);

    signOut();
    const uidB = await signInAnon();
    const resB = await callFn("joinGroupRoom");
    expect(resB["roomId"]).toBe(roomX);

    signOut();
    const uidC = await signInAnon();
    await callFn("joinGroupRoom");
    const doc3 = await adminFirestoreDoc(`rooms/${roomX}`);
    expect(doc3!["memberCount"]).toBe(3);
    expect(doc3!["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidB, uidC]),
    );

    await callFn("leaveRoom", {roomId: roomX});
    expect((await adminFirestoreDoc(`rooms/${roomX}`))!["memberCount"]).toBe(2);
    expect((await adminFirestoreDoc(`rooms/${roomX}`))!["status"]).toBe(
      "active",
    );

    await tryLeaveRoom(roomX);
    await sleep(500);

    signOut();
    await signInAnon();
    const resD = await callFn("joinGroupRoom");
    expect((resD["roomId"] as string).length).toBe(5);

    await tryLeaveRoom(resD["roomId"] as string);
  });

  test("custom room — create → lock → block → unlock → join → message → padding", async () => {
    await signInAnon();
    const resA = await callFn("createCustomRoom");
    const roomId = resA["roomId"] as string;

    const docInit = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(docInit!["roomType"]).toBe("custom");
    expect(docInit!["isLocked"]).toBe(false);

    await callFn("setRoomLock", {roomId, isLocked: true});
    expect((await adminFirestoreDoc(`rooms/${roomId}`))!["isLocked"]).toBe(
      true,
    );

    signOut();
    await signInAnon();
    try {
      await callFn("joinRoomById", {roomId});
      throw new Error("expected failed-precondition for locked room");
    } catch (e) {
      expect((e as Error).message).toContain("failed-precondition");
    }

    await tryLeaveRoom(roomId);
  });

  test("1v1 and group rooms do not cross-contaminate", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");

    signOut();
    const uidB = await signInAnon();
    const resB = await callFn("joinGroupRoom");
    const groupRoomId = resB["roomId"] as string;

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    const poolC = await waitUntilAdminDocMatches(
      `waiting_pool/${uidC}`,
      (d) => d?.["status"] === "matched",
    );
    const v1RoomId = poolC!["roomId"] as string;

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${v1RoomId}`),
      adminFirestoreDoc(`rooms/${groupRoomId}`),
    ]);

    const v1Room = docs[0]!;
    const groupRoom = docs[1]!;

    expect(v1Room["mode"]).toBe("1v1");
    expect(v1Room["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidC]),
    );
    expect(groupRoom["mode"]).toBe("group");
    expect(groupRoom["memberCount"]).toBe(1);
    expect(groupRoom["users"] as string[]).toContain(uidB);
    expect(groupRoom["users"] as string[]).not.toContain(uidA);
    expect(groupRoom["users"] as string[]).not.toContain(uidC);

    await Promise.all([
      callFn("leaveRoom", {roomId: v1RoomId}),
      tryLeaveRoom(groupRoomId),
    ]);
  });

  test("repeated switching — user visits multiple rooms across cycles", async () => {
    // All three rooms are 3/5 so they are in the secondary (random) pool.
    // There is no priority room, so selection is random across P, Q, R.
    const roomP = await buildRoom(3);
    const roomQ = await buildRoom(3);
    const roomR = await buildRoom(3);
    const knownRooms = new Set([roomP, roomQ, roomR]);
    const visited = new Set<string>();

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;
      expect([...knownRooms]).toContain(joined);
      visited.add(joined);
      await callFn("leaveRoom", {roomId: joined});
    }

    expect(visited.size).toBeGreaterThanOrEqual(2);
  });

  test("rapid 12 join-leave cycles without error", async () => {
    await buildRoom(3);
    await buildRoom(3);
    await buildRoom(3);

    const visited = new Set<string>();
    let errors = 0;

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      try {
        const res = await callFn("joinGroupRoom");
        const joined = res["roomId"] as string;
        visited.add(joined);
        await callFn("leaveRoom", {roomId: joined});
      } catch (_) {
        errors++;
      }
    }

    expect(errors).toBe(0);
    expect(visited.size).toBeGreaterThanOrEqual(2);
  });

  test("1v1 triple chain — A matches 3 different partners in sequence", async () => {
    const doMatch = async (): Promise<string> => {
      signOut();
      const uidPartner = await signInAnon();
      await callFn("join1v1Pool");
      const poolDoc = await waitUntilAdminDocMatches(
        `waiting_pool/${uidPartner}`,
        (d) => d?.["status"] === "matched",
      );
      return poolDoc!["roomId"] as string;
    };

    const uidA = await signInAnon();
    await callFn("join1v1Pool");

    const roomId1 = await doMatch();
    await callFn("leaveRoom", {roomId: roomId1});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    const roomId2 = await doMatch();
    await callFn("leaveRoom", {roomId: roomId2});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    const roomId3 = await doMatch();

    expect(new Set([roomId1, roomId2, roomId3]).size).toBe(3);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomId1}`),
      adminFirestoreDoc(`rooms/${roomId2}`),
      adminFirestoreDoc(`rooms/${roomId3}`),
    ]);
    expect(docs[0]!["status"]).toBe("padding");
    expect(docs[1]!["status"]).toBe("padding");
    expect(docs[2]!["status"]).toBe("active");

    await callFn("leaveRoom", {roomId: roomId3});
  });

  test("padding blocks all re-entry — joinRoomById and joinGroupRoom both refuse", async () => {
    signOut();
    await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomX = resA["roomId"] as string;

    signOut();
    await signInAnon();
    await callFn("joinGroupRoom");
    await callFn("leaveRoom", {roomId: roomX});

    await tryLeaveRoom(roomX);
    await sleep(300);

    const paddingDoc = await adminFirestoreDoc(`rooms/${roomX}`);
    if (paddingDoc!["status"] === "padding") {
      signOut();
      await signInAnon();

      try {
        await callFn("joinRoomById", {roomId: roomX});
        throw new Error("expected failed-precondition for padding room");
      } catch (e) {
        expect((e as Error).message).toContain("failed-precondition");
      }

      const newRes = await callFn("joinGroupRoom");
      expect(newRes["roomId"]).not.toBe(roomX);
      await tryLeaveRoom(newRes["roomId"] as string);
    }
  });

  test("mixed mode — user transitions from 1v1 to group, no contamination", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId1v1 = poolB!["roomId"] as string;

    await callFn("leaveRoom", {roomId: roomId1v1});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    const poolC = await waitUntilAdminDocMatches(
      `waiting_pool/${uidC}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId2 = poolC!["roomId"] as string;

    await callFn("leaveRoom", {roomId: roomId2});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    signOut();
    await signInAnon();
    const groupRes = await callFn("joinGroupRoom");
    const groupRoomId = groupRes["roomId"] as string;

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${groupRoomId}`),
      adminFirestoreDoc(`rooms/${roomId1v1}`),
      adminFirestoreDoc(`rooms/${roomId2}`),
    ]);

    expect(docs[0]!["mode"]).toBe("group");
    expect(docs[1]!["mode"]).toBe("1v1");
    expect(docs[2]!["mode"]).toBe("1v1");

    const groupUsers = docs[0]!["users"] as string[];
    expect(groupUsers).not.toContain(uidA);
    expect(groupUsers).not.toContain(uidB);

    await tryLeaveRoom(groupRoomId);
  });

  test("concurrent group room creation merge — near-simultaneous creators", async () => {
    signOut();
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomA = resA["roomId"] as string;

    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom");
    const roomB = resB["roomId"] as string;

    expect(roomA).toHaveLength(5);
    expect(roomB).toHaveLength(5);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomA}`),
      adminFirestoreDoc(`rooms/${roomB}`),
    ]);

    for (const doc of docs) {
      expect(doc!["memberCount"]).toBeGreaterThanOrEqual(1);
      expect(doc!["memberCount"]).toBeLessThanOrEqual(5);
      expect(doc!["mode"]).toBe("group");
      const users = doc!["users"] as string[];
      expect(new Set(users).size).toBe(users.length);
    }

    if (roomA === roomB) {
      const mergedDoc = await adminFirestoreDoc(`rooms/${roomA}`);
      const users = mergedDoc!["users"] as string[];
      expect(users.filter((u) => u === uidA).length).toBe(1);
    }

    await Promise.all([tryLeaveRoom(roomA), tryLeaveRoom(roomB)]);
  });

  test("group room load test — 15 users fill rooms, each UID in exactly one room", async () => {
    const uids: string[] = [];
    const roomAssignments: Record<string, string> = {};

    for (let i = 0; i < 15; i++) {
      signOut();
      uids.push(await signInAnon());
      const res = await callFn("joinGroupRoom");
      roomAssignments[uids[uids.length - 1]] = res["roomId"] as string;
    }

    expect(Object.values(roomAssignments).every((r) => r.length === 5)).toBe(
      true,
    );

    const uniqueRooms = new Set(Object.values(roomAssignments));
    expect(uniqueRooms.size).toBeGreaterThanOrEqual(3);

    const roomDocs = await Promise.all(
      [...uniqueRooms].map((id) => adminFirestoreDoc(`rooms/${id}`)),
    );
    for (const doc of roomDocs) {
      expect(doc!["memberCount"]).toBeLessThanOrEqual(5);
      expect(doc!["memberCount"]).toBeGreaterThan(0);
    }

    const allUsers = roomDocs.flatMap((d) => d!["users"] as string[]);
    for (const uid of uids) {
      expect(allUsers.filter((u) => u === uid).length).toBe(1);
    }

    for (const id of uniqueRooms) {
      await tryLeaveRoom(id);
    }
  });
});

// ── Regression: bugs found in session 2026-05-16 ──────────────────────────
//
// 1. expireRooms was never running in the emulator (no pubsub) — rooms
//    accumulated in padding indefinitely. Fixed by adding pubsub to dev.sh.
//
// 2. cleanupMember sometimes fails to fire (CF crash / region mismatch).
//    If it does not decrement memberCount to 0, expireRooms skipped the room
//    because memberCount > 0. Fixed by checking RTDB before skipping in
//    _expirePaddingRooms.
//
// 3. "Room access lost" error on voluntary leave — a late permission-denied
//    stream event arrived after the Flutter client already transitioned to
//    idle, overwriting the clean state with an error. Fixed by checking
//    state.status before acting in the onError handler (Flutter-side fix,
//    not tested here).

describe("regression: expireRooms cleans up stuck padding rooms", () => {
  /**
   * Simulates cleanupMember failing to fire after leaveRoom — the room stays
   * in padding with memberCount=1 (the state that was permanently stuck before
   * the fix because expireRooms skipped it). expireRooms must still expire it
   * when paddingUntil has elapsed and RTDB has no real members.
   */
  test("expireRooms expires a padding room with stale memberCount when RTDB is empty", async () => {
    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    const roomId = res["roomId"] as string;

    // Leave normally — room goes to padding with memberCount=0.
    await callFn("leaveRoom", {roomId});
    const afterLeave = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(afterLeave!["status"]).toBe("padding");
    expect(afterLeave!["memberCount"]).toBe(0);

    // Corrupt the doc: simulate cleanupMember missing a decrement.
    // memberCount=1 with paddingUntil already expired — RTDB has no members.
    await adminFirestoreUpdate(`rooms/${roomId}`, {
      memberCount: 1,
      paddingUntil: new Date(Date.now() - 5000),
    });

    const rtdbSnap = await rtdbGet(`rooms/${roomId}/members`);
    expect(rtdbSnap.exists).toBe(false);

    // expireRooms must expire it despite memberCount=1 (no RTDB members).
    await callScheduledFn("expireRooms");
    await sleep(500);

    const afterExpiry = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(afterExpiry!["status"]).toBe("expired");
  });

  /**
   * expireRooms must NOT expire a padding room that genuinely has live RTDB
   * members (someone rejoined during the padding window).
   */
  test("expireRooms skips padding rooms that still have RTDB members", async () => {
    signOut();
    const uidA = await signInAnon();
    const res = await callFn("joinGroupRoom");
    const roomId = res["roomId"] as string;

    signOut();
    await signInAnon();
    await callFn("joinGroupRoom");

    // Write a live RTDB member entry to simulate an active connection.
    await fetch(
      `http://127.0.0.1:9000/rooms/${roomId}/members/${uidA}.json?ns=cozytalk-5d984-default-rtdb&auth=owner`,
      {method: "PUT", body: "true"},
    );

    // Corrupt to padding with expired paddingUntil — but RTDB member is present.
    await adminFirestoreUpdate(`rooms/${roomId}`, {
      status: "padding",
      memberCount: 1,
      paddingUntil: new Date(Date.now() - 5000),
    });

    await callScheduledFn("expireRooms");
    await sleep(500);

    // Must NOT be expired — real RTDB member exists.
    const afterDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(afterDoc!["status"]).toBe("padding");

    // Cleanup: remove RTDB entry and tombstone the room.
    await fetch(
      `http://127.0.0.1:9000/rooms/${roomId}/members/${uidA}.json?ns=cozytalk-5d984-default-rtdb&auth=owner`,
      {method: "DELETE"},
    );
    await adminFirestoreUpdate(`rooms/${roomId}`, {status: "expired"});
  });

  /**
   * 1v1 leaveRoom: the room enters 30-second padding with memberCount=1.
   * expireRooms must not prematurely expire it while paddingUntil is still
   * in the future (even though memberCount=1 and RTDB members are already gone).
   */
  test("expireRooms does not expire a 1v1 padding room while paddingUntil is in the future", async () => {
    signOut();
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    const paddingDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(paddingDoc!["status"]).toBe("padding");
    const paddingUntilMs = new Date(
      paddingDoc!["paddingUntil"] as string,
    ).getTime();
    expect(paddingUntilMs).toBeGreaterThan(Date.now());

    // Run expireRooms — paddingUntil is still in the future, room must survive.
    await callScheduledFn("expireRooms");
    await sleep(500);

    const afterDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(afterDoc!["status"]).toBe("padding");

    await tryCancelPool();
  });
});

// ── Interest vector test helpers ──────────────────────────────────────────────

/** 256-dim unit vector along dimension d. */
const unitVec = (d: number): number[] =>
  Array.from({length: 256}, (_, i) => (i === d ? 1 : 0));

// ── 1v1 interest matching: room interest vectors ──────────────────────────────

describe("1v1 interest matching: room interest vectors", () => {
  test("room has memberInterests and roomInterestVector when both users have vectors", async () => {
    signOut();
    const uidA = await signInAnon();

    // Write pool doc directly so we control the interestVector without Vertex AI.
    await adminFirestoreSet(`waiting_pool/${uidA}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
      interestText: "football",
      interestVector: unitVec(0),
    });

    signOut();
    const uidB = await signInAnon();

    // Writing uidB's doc triggers match1v1Users with uidB as the trigger user.
    await adminFirestoreSet(`waiting_pool/${uidB}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
      interestText: "soccer",
      interestVector: unitVec(0),
    });

    const poolDocB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
      {timeout: 15_000},
    );
    expect(poolDocB?.["status"]).toBe("matched");
    const roomId = poolDocB!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room).not.toBeNull();

    const interests = room!["memberInterests"] as Record<string, unknown>;
    expect(interests).not.toBeNull();
    expect(Object.keys(interests)).toContain(uidA);
    expect(Object.keys(interests)).toContain(uidB);

    const rv = room!["roomInterestVector"] as number[];
    expect(Array.isArray(rv)).toBe(true);
    expect(rv.length).toBe(256);

    await adminFirestoreUpdate(`rooms/${roomId}`, {status: "expired"});
  });

  test("room has null memberInterests when neither user has a vector", async () => {
    signOut();
    const uidA = await signInAnon();
    await callFn("join1v1Pool");

    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDocB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
      {timeout: 15_000},
    );
    const roomId = poolDocB!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["memberInterests"] ?? null).toBeNull();
    expect(room!["roomInterestVector"] ?? null).toBeNull();

    await callFn("leaveRoom", {roomId});
  });
});

// ── Group room: interest vector maintained on join / leave ────────────────────

describe("group room: roomInterestVector maintained on leave", () => {
  test("roomInterestVector is recomputed when a member with interest leaves", async () => {
    // User A creates a group room.
    signOut();
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomId = resA["roomId"] as string;

    // User B joins the same room.
    signOut();
    const uidB = await signInAnon();
    await callFn("joinRoomById", {roomId});

    // Simulate both having submitted interests: write directly to Firestore.
    await adminFirestoreUpdate(`rooms/${roomId}`, {
      memberInterests: {[uidA]: unitVec(0), [uidB]: unitVec(1)},
      roomInterestVector: [0.5, 0.5, ...new Array(254).fill(0)],
    });

    // uidB leaves explicitly — leaveRoom recomputes interest vector synchronously.
    await callFn("leaveRoom", {roomId});

    const updated = await adminFirestoreDoc(`rooms/${roomId}`);
    const interests = updated!["memberInterests"] as Record<string, unknown>;
    expect(Object.keys(interests)).not.toContain(uidB);
    expect(Object.keys(interests)).toContain(uidA);

    // roomInterestVector should now equal uidA's vector (unitVec(0))
    const rv = updated!["roomInterestVector"] as number[];
    expect(Array.isArray(rv)).toBe(true);
    expect(rv[0]).toBe(1);
    expect(rv[1]).toBe(0);
  });

  test("roomInterestVector is null when last member with interest leaves", async () => {
    // Single user joins and creates a group room.
    signOut();
    const uidA = await signInAnon();
    const res = await callFn("joinGroupRoom");
    const roomId = res["roomId"] as string;

    // Simulate the user having an interest vector.
    await adminFirestoreUpdate(`rooms/${roomId}`, {
      memberInterests: {[uidA]: unitVec(0)},
      roomInterestVector: unitVec(0),
    });

    // uidA leaves explicitly — last member, leaveRoom sets padding and nulls interests.
    await callFn("leaveRoom", {roomId});

    const updated = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(updated!["status"]).toBe("padding");
    expect(updated!["roomInterestVector"] ?? null).toBeNull();
    expect(updated!["memberInterests"] ?? null).toBeNull();
  });
});

// ── 1v1 interest matching: candidate preference ───────────────────────────────

describe("1v1 interest matching: prefers similar-interest candidate", () => {
  test("similar-interest candidate is matched over earlier FIFO candidate", async () => {
    // Stage uidC first (earliest createdAt, no interest vector).
    // Writing with status "matching" means onDocumentCreated fires but the
    // CF returns immediately (status != "waiting"), so no real match runs.
    // adminFirestoreUpdate to "waiting" afterwards doesn't re-trigger the CF.
    signOut();
    const uidC = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidC}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "matching",
      mode: "1v1",
      roomId: null,
    });

    // Stage uidB with interest vector matching uidA's (same unit dimension).
    signOut();
    const uidB = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidB}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "matching",
      mode: "1v1",
      roomId: null,
      interestText: "soccer",
      interestVector: unitVec(0),
    });

    // Both staged — flip to "waiting" without firing a new trigger.
    await adminFirestoreUpdate(`waiting_pool/${uidC}`, {status: "waiting"});
    await adminFirestoreUpdate(`waiting_pool/${uidB}`, {status: "waiting"});

    // uidA arrives last with a matching interest vector.
    // Trigger fires: interest sort puts uidB first despite uidC being FIFO-oldest.
    signOut();
    const uidA = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidA}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
      interestText: "football",
      interestVector: unitVec(0), // cosine(unitVec(0), unitVec(0)) = 1.0 ≥ 0.65
    });

    const poolDocA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d?.["status"] === "matched",
      {timeout: 15_000},
    );
    expect(poolDocA?.["status"]).toBe("matched");
    const roomId = poolDocA!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room).not.toBeNull();
    // uidB (similar interest) was preferred over uidC (FIFO-first, no interest).
    expect(room!["users"] as string[]).toContain(uidB);
    expect(room!["users"] as string[]).not.toContain(uidC);

    await adminFirestoreUpdate(`rooms/${roomId}`, {status: "expired"});
  }, 30_000);

  test("falls back to FIFO when trigger user has no interest vector", async () => {
    // Stage uidC (oldest, has interest), uidB (newer, has interest) — both should
    // be ignored for sorting since trigger user has no vector.
    signOut();
    const uidC = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidC}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "matching",
      mode: "1v1",
      roomId: null,
      interestText: "football",
      interestVector: unitVec(0),
    });

    signOut();
    const uidB = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidB}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "matching",
      mode: "1v1",
      roomId: null,
      interestText: "soccer",
      interestVector: unitVec(1),
    });

    await adminFirestoreUpdate(`waiting_pool/${uidC}`, {status: "waiting"});
    await adminFirestoreUpdate(`waiting_pool/${uidB}`, {status: "waiting"});

    // uidA has no interest vector — pure FIFO applies, uidC (oldest) wins.
    signOut();
    const uidA = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidA}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
    });

    const poolDocA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d?.["status"] === "matched",
      {timeout: 15_000},
    );
    const roomId = poolDocA!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room).not.toBeNull();
    // FIFO order: uidC (oldest) is picked first when no interest sorting applies.
    expect(room!["users"] as string[]).toContain(uidC);
    expect(room!["users"] as string[]).not.toContain(uidB);

    await adminFirestoreUpdate(`rooms/${roomId}`, {status: "expired"});
  }, 30_000);
});

// ── join1v1Pool: interest text stored and embedded ────────────────────────────

describe("join1v1Pool: interest text and embedding", () => {
  test("stores interestText and interestVector when interestText is provided", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool", {interestText: "I love football"});

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["interestText"]).toBe("I love football");

    // interestVector is a 256-dim array when Vertex AI (ADC) is available, null otherwise.
    const vec = doc!["interestVector"];
    if (vec !== null) {
      expect(Array.isArray(vec)).toBe(true);
      expect((vec as number[]).length).toBe(256);
    } else {
      expect(vec).toBeNull();
    }

    await tryCancelPool();
  });

  test("interestText and interestVector are null when no interest is provided", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["interestText"]).toBeNull();
    expect(doc!["interestVector"] ?? null).toBeNull();

    await tryCancelPool();
  });

  test("matched room has interest fields when both users provided interest text", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool", {interestText: "football"});
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool", {interestText: "soccer"});

    const poolDocB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
      {timeout: 15_000},
    );
    const roomId = poolDocB!["roomId"] as string;

    const poolDocA = await adminFirestoreDoc(`waiting_pool/${uidA}`);
    const room = await adminFirestoreDoc(`rooms/${roomId}`);

    if (poolDocA?.["interestVector"] !== null) {
      // Both users were embedded — room must carry interest fields.
      const interests = room!["memberInterests"] as Record<string, unknown>;
      expect(Object.keys(interests)).toContain(uidA);
      expect(Object.keys(interests)).toContain(uidB);
      const rv = room!["roomInterestVector"] as number[];
      expect(Array.isArray(rv)).toBe(true);
      expect(rv.length).toBe(256);
    } else {
      // Vertex AI unavailable — room must not have partial interest state.
      expect(room!["memberInterests"] ?? null).toBeNull();
      expect(room!["roomInterestVector"] ?? null).toBeNull();
    }

    await adminFirestoreUpdate(`rooms/${roomId}`, {status: "expired"});
  }, 30_000);
});

// ── joinGroupRoom: interest text seeded into room ─────────────────────────────

describe("joinGroupRoom: interest text seeded into room", () => {
  test("new room gets roomInterestVector and memberInterests when user has interest", async () => {
    const uid = await signInAnon();
    const res = await callFn("joinGroupRoom", {
      interestText: "I love football",
    });
    const roomId = res["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    const vec = room!["roomInterestVector"];

    if (Array.isArray(vec)) {
      expect(Array.isArray(vec)).toBe(true);
      expect((vec as number[]).length).toBe(256);
      const interests = room!["memberInterests"] as Record<string, unknown>;
      expect(Object.keys(interests)).toContain(uid);
    } else {
      // Vertex AI unavailable — both fields must be null (no partial state).
      expect(room!["memberInterests"] ?? null).toBeNull();
      expect(room!["roomInterestVector"] ?? null).toBeNull();
    }

    await tryLeaveRoom(roomId);
  });

  test("second user joining with interest updates memberInterests and recomputes roomInterestVector", async () => {
    signOut();
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom", {interestText: "football"});
    const roomId = resA["roomId"] as string;

    signOut();
    const uidB = await signInAnon();
    const resB = await callFn("joinGroupRoom", {interestText: "soccer"});

    // If uidB landed in the same room (Phase 0 match or Phase 1 FIFO), check interest fields.
    if (resB["roomId"] === roomId) {
      const room = await adminFirestoreDoc(`rooms/${roomId}`);
      const vec = room!["roomInterestVector"];
      if (Array.isArray(vec)) {
        expect(Array.isArray(vec)).toBe(true);
        expect((vec as number[]).length).toBe(256);
        const interests = room!["memberInterests"] as Record<string, unknown>;
        expect(Object.keys(interests)).toContain(uidA);
        expect(Object.keys(interests)).toContain(uidB);
      } else {
        // Vertex AI unavailable — both fields must be null (no partial state).
        expect(room!["memberInterests"] ?? null).toBeNull();
        expect(room!["roomInterestVector"] ?? null).toBeNull();
      }
    }

    await tryLeaveRoom(roomId);
    if (resB["roomId"] !== roomId) {
      await tryLeaveRoom(resB["roomId"] as string);
    }
  }, 20_000);
});

// ── Group interest matching: Phase 0 routing ──────────────────────────────────

describe("group interest matching: Phase 0 routing", () => {
  test("interest-compatible room is chosen over older FIFO-first room when Vertex AI is available", async () => {
    // Room B: plain lone-user room, created FIRST (would win Phase 1 FIFO).
    // Lock it so the football user is forced to create their own room.
    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom");
    const roomB = resB["roomId"] as string;
    await adminFirestoreUpdate(`rooms/${roomB}`, {isLocked: true});

    // Room A: created SECOND with "football" interest.
    // Room B is locked so joinGroupRoom skips it and creates a new room.
    signOut();
    await signInAnon();
    const resA = await callFn("joinGroupRoom", {
      interestText: "I love football",
    });
    const roomA = resA["roomId"] as string;

    expect(roomA).not.toBe(roomB);

    // Unlock room B — it is now the FIFO-older lone-user room again.
    await adminFirestoreUpdate(`rooms/${roomB}`, {isLocked: false});

    const roomADoc = await adminFirestoreDoc(`rooms/${roomA}`);
    if (!Array.isArray(roomADoc?.["roomInterestVector"])) {
      // ADC credentials not set up — Phase 0 cannot activate. Skip routing assertion.
      await Promise.all([tryLeaveRoom(roomA), tryLeaveRoom(roomB)]);
      return;
    }

    // User C with "soccer" interest: Phase 0 should prefer room A (football-compatible)
    // over room B (FIFO-first but no matching interest vector).
    signOut();
    await signInAnon();
    const resC = await callFn("joinGroupRoom", {
      interestText: "I enjoy watching soccer",
    });

    expect(resC["roomId"]).toBe(roomA);

    await tryLeaveRoom(roomB);
    await tryLeaveRoom(resC["roomId"] as string);
  }, 30_000);

  test("user without interest skips Phase 0 and uses Phase 1 FIFO", async () => {
    // Room A: lone-user room with interest (only available room).
    signOut();
    await signInAnon();
    const resA = await callFn("joinGroupRoom", {interestText: "football"});
    const roomId = resA["roomId"] as string;

    // User B has no interest — Phase 0 is skipped entirely, Phase 1 picks the only room.
    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom");

    expect(resB["roomId"]).toBe(roomId);
    await tryLeaveRoom(roomId);
  }, 15_000);

  test("new room created with seeded roomInterestVector when no rooms are available", async () => {
    const uid = await signInAnon();
    const res = await callFn("joinGroupRoom", {interestText: "I love music"});
    const roomId = res["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["memberCount"]).toBe(1);
    expect(room!["users"] as string[]).toContain(uid);

    const vec = room!["roomInterestVector"];
    if (Array.isArray(vec)) {
      expect(Array.isArray(vec)).toBe(true);
      expect((vec as number[]).length).toBe(256);
      const interests = room!["memberInterests"] as Record<string, unknown>;
      expect(Object.keys(interests)).toContain(uid);
    } else {
      // Vertex AI unavailable — both fields must be null (no partial state).
      expect(room!["memberInterests"] ?? null).toBeNull();
      expect(room!["roomInterestVector"] ?? null).toBeNull();
    }

    await tryLeaveRoom(roomId);
  }, 15_000);
});

// ── Background theme: group room partitioning ─────────────────────────────────
//
// backgroundTheme acts as a hard partition key. Users who pick a theme only
// land in rooms that share that theme. Users who pick no theme ("randomized")
// get no filter and can land in any room — same as the pre-feature behaviour.

describe("background theme: group room partitioning", () => {
  test("new group room has backgroundTheme stored in Firestore", async () => {
    const uid = await signInAnon();
    const res = await callFn("joinGroupRoom", {backgroundTheme: "kao_tapu"});
    const roomId = res["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["backgroundTheme"]).toBe("kao_tapu");
    expect(room!["users"] as string[]).toContain(uid);

    await tryLeaveRoom(roomId);
  }, 30_000);

  test("second user with same theme joins existing themed room", async () => {
    signOut();
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom", {
      backgroundTheme: "red_lotus_lake",
    });
    const roomId = resA["roomId"] as string;

    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom", {
      backgroundTheme: "red_lotus_lake",
    });

    expect(resB["roomId"]).toBe(roomId);

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["memberCount"]).toBe(2);
    expect(room!["backgroundTheme"]).toBe("red_lotus_lake");
    expect(room!["users"] as string[]).toContain(uidA);

    await tryLeaveRoom(roomId);
  }, 30_000);

  test("different-theme users get separate rooms", async () => {
    signOut();
    await signInAnon();
    const resA = await callFn("joinGroupRoom", {backgroundTheme: "kao_tapu"});
    const roomA = resA["roomId"] as string;

    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom", {
      backgroundTheme: "red_lotus_lake",
    });
    const roomB = resB["roomId"] as string;

    expect(roomA).not.toBe(roomB);

    const [docA, docB] = await Promise.all([
      adminFirestoreDoc(`rooms/${roomA}`),
      adminFirestoreDoc(`rooms/${roomB}`),
    ]);
    expect(docA!["backgroundTheme"]).toBe("kao_tapu");
    expect(docA!["memberCount"]).toBe(1);
    expect(docB!["backgroundTheme"]).toBe("red_lotus_lake");
    expect(docB!["memberCount"]).toBe(1);

    await Promise.all([tryLeaveRoom(roomA), tryLeaveRoom(roomB)]);
  }, 30_000);

  test("themed user ignores unthemed rooms and creates a new themed room", async () => {
    // Build an unthemed room (backgroundTheme: null — excluded from themed queries).
    const unthermedRoomId = await buildRoom(1);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom", {
      backgroundTheme: "sea_of_cloud",
    });
    const newRoomId = res["roomId"] as string;

    expect(newRoomId).not.toBe(unthermedRoomId);

    const [unthemed, themed] = await Promise.all([
      adminFirestoreDoc(`rooms/${unthermedRoomId}`),
      adminFirestoreDoc(`rooms/${newRoomId}`),
    ]);
    expect(unthemed!["memberCount"]).toBe(1);
    expect(themed!["backgroundTheme"]).toBe("sea_of_cloud");
    expect(themed!["memberCount"]).toBe(1);

    await tryLeaveRoom(newRoomId);
  }, 30_000);

  test("unthemed user joins any available room (including themed rooms)", async () => {
    signOut();
    await signInAnon();
    const resA = await callFn("joinGroupRoom", {
      backgroundTheme: "lumphini_park",
    });
    const themedRoomId = resA["roomId"] as string;

    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom"); // no theme — Phase 1 picks any 1-member room

    // Unthemed user joins the themed room because no filter is applied.
    expect(resB["roomId"]).toBe(themedRoomId);

    const room = await adminFirestoreDoc(`rooms/${themedRoomId}`);
    expect(room!["memberCount"]).toBe(2);

    await tryLeaveRoom(themedRoomId);
  }, 30_000);

  test("three different themes produce three isolated rooms", async () => {
    const themes = ["kao_tapu", "red_lotus_lake", "sea_of_cloud"] as const;
    const roomIds: string[] = [];

    for (const theme of themes) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom", {backgroundTheme: theme});
      roomIds.push(res["roomId"] as string);
    }

    // All room IDs must be distinct.
    expect(new Set(roomIds).size).toBe(3);

    const docs = await Promise.all(
      roomIds.map((id) => adminFirestoreDoc(`rooms/${id}`)),
    );
    for (let i = 0; i < 3; i++) {
      expect(docs[i]!["backgroundTheme"]).toBe(themes[i]);
      expect(docs[i]!["memberCount"]).toBe(1);
    }

    await Promise.all(roomIds.map(tryLeaveRoom));
  }, 60_000);
});

// ── Background theme: 1v1 pool partitioning ───────────────────────────────────

describe("background theme: 1v1 pool partitioning", () => {
  test("join1v1Pool stores backgroundTheme in pool doc", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["backgroundTheme"]).toBe("kao_tapu");
    expect(doc!["status"]).toBe("waiting");
    expect(doc!["mode"]).toBe("1v1");

    await tryCancelPool();
  }, 15_000);

  test("join1v1Pool without theme stores null backgroundTheme (backward compat)", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["backgroundTheme"]).toBeNull();

    await tryCancelPool();
  }, 15_000);

  test("same-theme users are matched together", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "red_lotus_lake"});
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "red_lotus_lake"});

    const poolDocB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDocB!["roomId"] as string;
    expect(roomId).toHaveLength(5);

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidB]),
    );
    expect(room!["backgroundTheme"]).toBe("red_lotus_lake");

    await callFn("leaveRoom", {roomId});
  }, 30_000);

  test("different-theme users are NOT matched — each stays waiting", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "lumphini_park"});

    // Give the trigger CF time to run for both users.
    await sleep(5000);

    const [docA, docB] = await Promise.all([
      adminFirestoreDoc(`waiting_pool/${uidA}`),
      adminFirestoreDoc(`waiting_pool/${uidB}`),
    ]);
    expect(docA!["status"]).toBe("waiting");
    expect(docB!["status"]).toBe("waiting");

    await Promise.all([tryCancelPool(), tryCancelPool()]);
  }, 20_000);

  test("themed matched 1v1 room carries backgroundTheme field", async () => {
    // Write pool docs directly to bypass Vertex AI embedding.
    signOut();
    const uidA = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidA}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
      interestText: null,
      interestVector: null,
      backgroundTheme: "sea_of_cloud",
    });

    signOut();
    const uidB = await signInAnon();
    // Writing uidB triggers match1v1Users.
    await adminFirestoreSet(`waiting_pool/${uidB}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
      interestText: null,
      interestVector: null,
      backgroundTheme: "sea_of_cloud",
    });

    const poolDocB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
      {timeout: 20_000},
    );
    const roomId = poolDocB!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["backgroundTheme"]).toBe("sea_of_cloud");
    expect(room!["mode"]).toBe("1v1");

    await adminFirestoreUpdate(`rooms/${roomId}`, {status: "expired"});
  }, 30_000);

  test("theme does not affect interest sorting — interest still preferred within same theme", async () => {
    // Stage uidC: same theme, no interest (becomes FIFO-oldest waiting candidate).
    signOut();
    const uidC = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidC}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "matching",
      mode: "1v1",
      roomId: null,
      backgroundTheme: "kao_tapu",
    });

    // Stage uidB: same theme, has matching interest vector.
    signOut();
    const uidB = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidB}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "matching",
      mode: "1v1",
      roomId: null,
      interestText: "football",
      interestVector: Array.from({length: 256}, (_, i) => (i === 0 ? 1 : 0)),
      backgroundTheme: "kao_tapu",
    });

    await adminFirestoreUpdate(`waiting_pool/${uidC}`, {status: "waiting"});
    await adminFirestoreUpdate(`waiting_pool/${uidB}`, {status: "waiting"});

    // uidA: same theme + matching interest — trigger fires, interest sort should
    // prefer uidB over uidC despite uidC being FIFO-oldest.
    signOut();
    const uidA = await signInAnon();
    await adminFirestoreSet(`waiting_pool/${uidA}`, {
      createdAt: new Date(),
      updatedAt: new Date(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
      interestText: "soccer",
      interestVector: Array.from({length: 256}, (_, i) => (i === 0 ? 1 : 0)),
      backgroundTheme: "kao_tapu",
    });

    const poolDocA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d?.["status"] === "matched",
      {timeout: 15_000},
    );
    const roomId = poolDocA!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    // Interest-matched uidB was preferred over FIFO-first uidC within the same theme.
    expect(room!["users"] as string[]).toContain(uidB);
    expect(room!["users"] as string[]).not.toContain(uidC);
    expect(room!["backgroundTheme"]).toBe("kao_tapu");

    await adminFirestoreUpdate(`rooms/${roomId}`, {status: "expired"});
  }, 30_000);
});

// ── Background theme: 1v1 re-queue after partner leaves ───────────────────────
//
// When one user leaves a matched 1v1 room the leaveRoom CF re-queues the
// remaining user. The re-queue pool doc must carry the same backgroundTheme
// that was on the room so match1v1Users can still apply the theme filter.

describe("background theme: 1v1 re-queue after partner leaves", () => {
  test("leaveRoom re-queues remaining user with backgroundTheme preserved", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});
    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});

    // Wait for the two to be matched.
    const poolDocC = await waitUntilAdminDocMatches(
      `waiting_pool/${uidC}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDocC!["roomId"] as string;

    // C leaves — leaveRoom should re-queue A.
    await callFn("leaveRoom", {roomId});

    // Give leaveRoom time to write the re-queue pool doc.
    await sleep(2000);

    const poolDocA = await adminFirestoreDoc(`waiting_pool/${uidA}`);
    expect(poolDocA!["status"]).toBe("waiting");
    expect(poolDocA!["backgroundTheme"]).toBe("kao_tapu");

    await tryCancelPool();
  }, 30_000);

  test("re-queued themed user does NOT match a different-theme candidate", async () => {
    // B joins with Red Lotus Lake and waits.
    const uidB = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "red_lotus_lake"});

    // A and C both join with Kao Tapu and match each other.
    signOut();
    const uidA = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});
    signOut();
    await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});

    const poolDocA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDocA!["roomId"] as string;

    // C (current user) leaves. leaveRoom re-queues A.
    await callFn("leaveRoom", {roomId});

    // Give match1v1Users time to run for the re-queued A.
    await sleep(5000);

    // A should still be waiting — B has a different theme.
    const poolDocAAfter = await adminFirestoreDoc(`waiting_pool/${uidA}`);
    expect(poolDocAAfter!["status"]).toBe("waiting");
    expect(poolDocAAfter!["backgroundTheme"]).toBe("kao_tapu");

    // B should still be waiting — A's theme filter excluded B.
    const uidBSnap = await adminFirestoreDoc(`waiting_pool/${uidB}`);
    expect(uidBSnap!["status"]).toBe("waiting");

    await tryCancelPool();
  }, 40_000);

  test("re-queued themed user matches same-theme new candidate", async () => {
    // A and C match on Kao Tapu.
    const uidA = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});
    signOut();
    await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});

    const poolDocA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDocA!["roomId"] as string;

    // C leaves — A is re-queued with Kao Tapu.
    await callFn("leaveRoom", {roomId});
    await sleep(2000);

    // D joins with the same Kao Tapu theme and triggers match1v1Users.
    signOut();
    const uidD = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "kao_tapu"});

    const poolDocD = await waitUntilAdminDocMatches(
      `waiting_pool/${uidD}`,
      (d) => d?.["status"] === "matched",
    );
    const newRoomId = poolDocD!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${newRoomId}`);
    expect(room!["users"] as string[]).toContain(uidA);
    expect(room!["users"] as string[]).toContain(uidD);
    expect(room!["backgroundTheme"]).toBe("kao_tapu");

    await callFn("leaveRoom", {roomId: newRoomId});
  }, 40_000);

  test("re-queued unthemed user can match any waiting candidate", async () => {
    // A and C both join with no theme and match.
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    await signInAnon();
    await callFn("join1v1Pool");

    const poolDocA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDocA!["roomId"] as string;

    // C leaves — A is re-queued with null theme.
    await callFn("leaveRoom", {roomId});
    await sleep(2000);

    const poolDocARequeued = await adminFirestoreDoc(`waiting_pool/${uidA}`);
    expect(poolDocARequeued!["backgroundTheme"]).toBeNull();

    // D joins with a theme — A (no theme) should still match D.
    signOut();
    const uidD = await signInAnon();
    await callFn("join1v1Pool", {backgroundTheme: "sea_of_cloud"});

    const poolDocD = await waitUntilAdminDocMatches(
      `waiting_pool/${uidD}`,
      (d) => d?.["status"] === "matched",
    );
    const newRoomId = poolDocD!["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${newRoomId}`);
    expect(room!["users"] as string[]).toContain(uidA);
    expect(room!["users"] as string[]).toContain(uidD);

    await callFn("leaveRoom", {roomId: newRoomId});
  }, 40_000);
});

// ── Background theme: custom rooms ───────────────────────────────────────────
//
// createCustomRoom now accepts backgroundTheme so the room appears in
// theme-filtered joinGroupRoom queries. Without this, themed users creating a
// custom room could never be found by a same-theme joinGroupRoom caller.

describe("background theme: custom rooms", () => {
  test("createCustomRoom stores backgroundTheme in Firestore", async () => {
    await signInAnon();
    const res = await callFn("createCustomRoom", {
      backgroundTheme: "red_lotus_lake",
    });
    const roomId = res["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["backgroundTheme"]).toBe("red_lotus_lake");
    expect(room!["roomType"]).toBe("custom");

    await tryLeaveRoom(roomId);
  }, 15_000);

  test("createCustomRoom without theme stores null backgroundTheme", async () => {
    await signInAnon();
    const res = await callFn("createCustomRoom");
    const roomId = res["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["backgroundTheme"]).toBeNull();

    await tryLeaveRoom(roomId);
  }, 15_000);

  test("joinGroupRoom with matching theme finds a themed custom room", async () => {
    // A creates a custom room with Red Lotus Lake.
    const uidA = await signInAnon();
    const resA = await callFn("createCustomRoom", {
      backgroundTheme: "red_lotus_lake",
    });
    const customRoomId = resA["roomId"] as string;

    // B joins with the same theme — should land in A's custom room.
    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom", {
      backgroundTheme: "red_lotus_lake",
    });

    expect(resB["roomId"]).toBe(customRoomId);
    expect(resB["isNewRoom"]).toBe(false);

    const room = await adminFirestoreDoc(`rooms/${customRoomId}`);
    expect(room!["memberCount"]).toBe(2);
    expect(room!["users"] as string[]).toContain(uidA);

    await tryLeaveRoom(customRoomId);
  }, 30_000);

  test("joinGroupRoom with different theme does NOT join a themed custom room", async () => {
    // A creates a custom room with Red Lotus Lake.
    await signInAnon();
    const resA = await callFn("createCustomRoom", {
      backgroundTheme: "red_lotus_lake",
    });
    const customRoomId = resA["roomId"] as string;

    // B joins with Kao Tapu — should create a brand-new room.
    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom", {backgroundTheme: "kao_tapu"});
    const newRoomId = resB["roomId"] as string;

    expect(newRoomId).not.toBe(customRoomId);

    const [customRoom, newRoom] = await Promise.all([
      adminFirestoreDoc(`rooms/${customRoomId}`),
      adminFirestoreDoc(`rooms/${newRoomId}`),
    ]);
    expect(customRoom!["memberCount"]).toBe(1);
    expect(newRoom!["backgroundTheme"]).toBe("kao_tapu");

    await Promise.all([tryLeaveRoom(customRoomId), tryLeaveRoom(newRoomId)]);
  }, 30_000);

  test("joinGroupRoom with no theme joins any available room including themed custom rooms", async () => {
    // A creates a themed custom room.
    const uidA = await signInAnon();
    const resA = await callFn("createCustomRoom", {
      backgroundTheme: "lumphini_park",
    });
    const customRoomId = resA["roomId"] as string;

    // B joins with no theme — unthemed users see all rooms, so B lands in A's room.
    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom");

    expect(resB["roomId"]).toBe(customRoomId);

    const room = await adminFirestoreDoc(`rooms/${customRoomId}`);
    expect(room!["memberCount"]).toBe(2);
    expect(room!["users"] as string[]).toContain(uidA);

    await tryLeaveRoom(customRoomId);
  }, 30_000);

  test("createCustomRoom with invalid theme stores null backgroundTheme", async () => {
    await signInAnon();
    const res = await callFn("createCustomRoom", {
      backgroundTheme: "not_a_real_theme",
    });
    const roomId = res["roomId"] as string;

    const room = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(room!["backgroundTheme"]).toBeNull();

    await tryLeaveRoom(roomId);
  }, 15_000);
});
