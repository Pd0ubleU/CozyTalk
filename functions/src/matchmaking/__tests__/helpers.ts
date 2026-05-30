let currentIdToken: string | null = null;

export const sleep = (ms: number): Promise<void> =>
  new Promise((r) => setTimeout(r, ms));

export const signInAnon = async (): Promise<string> => {
  const res = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key",
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({returnSecureToken: true}),
    },
  );
  const body = (await res.json()) as {idToken: string; localId: string};
  currentIdToken = body.idToken;
  return body.localId;
};

export const signOut = (): void => {
  currentIdToken = null;
};

export const callFn = async (
  name: string,
  data: Record<string, unknown> = {},
): Promise<Record<string, unknown>> => {
  const headers: Record<string, string> = {"Content-Type": "application/json"};
  if (currentIdToken) {
    headers["Authorization"] = `Bearer ${currentIdToken}`;
  }
  const res = await fetch(
    `http://127.0.0.1:5001/cozytalk-5d984/us-central1/${name}`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({data}),
    },
  );
  const body = (await res.json()) as {
    result?: Record<string, unknown>;
    error?: {status: string; message: string};
  };
  if (body.error) {
    const code = body.error.status.toLowerCase().replace(/_/g, "-");
    throw new Error(`${code}: ${body.error.message}`);
  }
  return body.result ?? {};
};

export const resetEmulatorData = async (): Promise<void> => {
  await Promise.all([
    fetch(
      "http://127.0.0.1:8080/emulator/v1/projects/cozytalk-5d984/databases/(default)/documents",
      {method: "DELETE"},
    ),
    fetch("http://127.0.0.1:9000/.json?ns=cozytalk-5d984-default-rtdb", {
      method: "DELETE",
    }),
  ]);
};

export const rtdbGet = async (
  path: string,
): Promise<{value: unknown; exists: boolean}> => {
  const params = new URLSearchParams({ns: "cozytalk-5d984-default-rtdb"});
  const res = await fetch(`http://127.0.0.1:9000/${path}.json?${params}`, {
    headers: {Authorization: "Bearer owner"},
  });
  if (!res.ok) {
    throw new Error(
      `RTDB read failed (HTTP ${res.status}): ${await res.text()}`,
    );
  }
  const data: unknown = await res.json();
  return {value: data, exists: data !== null};
};

/**
 * Polls an RTDB path until the predicate returns true or the timeout expires.
 * Use this when an async CF event (e.g. a Firestore trigger) writes RTDB data
 * after its Firestore update — the Firestore poll may return before RTDB is
 * written.
 */
export const waitUntilRtdbValue = async (
  path: string,
  predicate: (snap: {value: unknown; exists: boolean}) => boolean,
  options: {timeout?: number; interval?: number} = {},
): Promise<{value: unknown; exists: boolean}> => {
  const timeout = options.timeout ?? 10_000;
  const interval = options.interval ?? 200;
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const snap = await rtdbGet(path);
    if (predicate(snap)) return snap;
    await sleep(interval);
  }
  return rtdbGet(path);
};

const decodeFirestoreValue = (v: unknown): unknown => {
  if (typeof v !== "object" || v === null) return v;
  const m = v as Record<string, unknown>;
  if ("stringValue" in m) return m["stringValue"];
  if ("integerValue" in m) return parseInt(String(m["integerValue"]), 10);
  if ("doubleValue" in m) return Number(m["doubleValue"]);
  if ("booleanValue" in m) return m["booleanValue"] as boolean;
  if ("nullValue" in m) return null;
  if ("timestampValue" in m) return m["timestampValue"];
  if ("arrayValue" in m) {
    const arr = m["arrayValue"] as {values?: unknown[]};
    const vals = arr.values ?? [];
    return vals.map(decodeFirestoreValue);
  }
  if ("mapValue" in m) {
    const mv = m["mapValue"] as {fields?: Record<string, unknown>};
    if (!mv.fields) return {};
    return decodeFirestoreFields(mv.fields);
  }
  return m;
};

const decodeFirestoreFields = (
  fields: Record<string, unknown>,
): Record<string, unknown> =>
  Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [k, decodeFirestoreValue(v)]),
  );

export const adminFirestoreDoc = async (
  path: string,
): Promise<Record<string, unknown> | null> => {
  const res = await fetch(
    `http://127.0.0.1:8080/v1/projects/cozytalk-5d984/databases/(default)/documents/${path}`,
    {headers: {Authorization: "Bearer owner"}},
  );
  if (res.status === 404) return null;
  const body = (await res.json()) as {
    fields?: Record<string, unknown>;
  };
  if (!body.fields) return {};
  return decodeFirestoreFields(body.fields);
};

export const waitUntilAdminDocMatches = async (
  path: string,
  predicate: (doc: Record<string, unknown> | null) => boolean,
  options: {timeout?: number; interval?: number} = {},
): Promise<Record<string, unknown> | null> => {
  const timeout = options.timeout ?? 20000;
  const interval = options.interval ?? 200;
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const doc = await adminFirestoreDoc(path);
    if (predicate(doc)) return doc;
    await sleep(interval);
  }
  return adminFirestoreDoc(path);
};

export const tryLeaveRoom = async (roomId: string): Promise<void> => {
  try {
    await callFn("leaveRoom", {roomId});
  } catch (_) {}
};

export const tryCancelPool = async (): Promise<void> => {
  try {
    await callFn("cancel1v1Pool");
  } catch (_) {}
};

// ── Admin write helpers ───────────────────────────────────────────────────────

function _toFirestoreValue(val: unknown): Record<string, unknown> {
  if (val === null || val === undefined) return {nullValue: null};
  if (typeof val === "boolean") return {booleanValue: val};
  if (typeof val === "number") {
    return Number.isInteger(val)
      ? {integerValue: String(val)}
      : {doubleValue: val};
  }
  if (val instanceof Date) return {timestampValue: val.toISOString()};
  if (typeof val === "string") return {stringValue: val};
  if (Array.isArray(val)) {
    return {arrayValue: {values: val.map(_toFirestoreValue)}};
  }
  if (typeof val === "object") {
    const fields: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(val as Record<string, unknown>)) {
      fields[k] = _toFirestoreValue(v);
    }
    return {mapValue: {fields}};
  }
  return {stringValue: String(val)};
}

/**
 * Partially updates a Firestore document using a field mask so existing fields
 * are preserved. Accepts Date values, which are encoded as Firestore timestamps.
 * Bypasses security rules (Bearer owner).
 */
export const adminFirestoreUpdate = async (
  path: string,
  data: Record<string, unknown>,
): Promise<void> => {
  const fields: Record<string, unknown> = {};
  const fieldPaths: string[] = [];
  for (const [k, v] of Object.entries(data)) {
    fields[k] = _toFirestoreValue(v);
    fieldPaths.push(k);
  }
  const mask = fieldPaths
    .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
    .join("&");
  const res = await fetch(
    `http://127.0.0.1:8080/v1/projects/cozytalk-5d984/databases/(default)/documents/${path}?${mask}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer owner",
      },
      body: JSON.stringify({fields}),
    },
  );
  if (!res.ok) {
    throw new Error(
      `adminFirestoreUpdate failed (${res.status}): ${await res.text()}`,
    );
  }
};

/**
 * Triggers a scheduled Cloud Function via the local emulator HTTP endpoint.
 * Does not parse the response body — scheduled functions return a plain 200.
 * Note: the Firebase emulator appends "-0" to v2 onSchedule function names.
 */
export const callScheduledFn = async (name: string): Promise<void> => {
  const res = await fetch(
    `http://127.0.0.1:5001/cozytalk-5d984/us-central1/${name}-0`,
    {method: "POST"},
  );
  if (!res.ok) {
    throw new Error(`${name} failed (HTTP ${res.status}): ${await res.text()}`);
  }
};

/**
 * Creates or overwrites a Firestore document via the emulator admin REST API.
 * Bypasses security rules (Bearer owner).
 */
export const adminFirestoreSet = async (
  path: string,
  data: Record<string, unknown>,
): Promise<void> => {
  const fields: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = _toFirestoreValue(v);
  }
  const res = await fetch(
    `http://127.0.0.1:8080/v1/projects/cozytalk-5d984/databases/(default)/documents/${path}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer owner",
      },
      body: JSON.stringify({fields}),
    },
  );
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`adminFirestoreSet failed (${res.status}): ${body}`);
  }
};

/**
 * Lists all documents in a Firestore collection or subcollection path.
 * Returns an array of decoded document data objects.
 */
export const adminFirestoreList = async (
  collectionPath: string,
): Promise<Array<Record<string, unknown>>> => {
  const res = await fetch(
    `http://127.0.0.1:8080/v1/projects/cozytalk-5d984/databases/(default)/documents/${collectionPath}`,
    {headers: {Authorization: "Bearer owner"}},
  );
  if (res.status === 404) return [];
  const body = (await res.json()) as {
    documents?: Array<{fields?: Record<string, unknown>}>;
  };
  if (!body.documents) return [];
  return body.documents.map((d) =>
    d.fields ? decodeFirestoreFields(d.fields) : {},
  );
};

/**
 * Deletes a Firestore document via the emulator admin REST API.
 * Bypasses security rules (Bearer owner). No-ops if the document does not exist.
 */
export const adminFirestoreDelete = async (path: string): Promise<void> => {
  const res = await fetch(
    `http://127.0.0.1:8080/v1/projects/cozytalk-5d984/databases/(default)/documents/${path}`,
    {
      method: "DELETE",
      headers: {Authorization: "Bearer owner"},
    },
  );
  if (!res.ok && res.status !== 404) {
    throw new Error(
      `adminFirestoreDelete failed (${res.status}): ${await res.text()}`,
    );
  }
};

/**
 * Writes a value to an RTDB path via the emulator admin REST API.
 * Bypasses security rules (Authorization: Bearer owner).
 * @param {string} path - RTDB path (no leading slash)
 * @param {unknown} value - JSON-serialisable value; null removes the node
 */
export const rtdbSet = async (path: string, value: unknown): Promise<void> => {
  const params = new URLSearchParams({ns: "cozytalk-5d984-default-rtdb"});
  const res = await fetch(`http://127.0.0.1:9000/${path}.json?${params}`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer owner",
    },
    body: JSON.stringify(value),
  });
  if (!res.ok) {
    throw new Error(`rtdbSet failed (${res.status}): ${await res.text()}`);
  }
};

export const buildRoom = async (targetSize: number): Promise<string> => {
  signOut();
  await signInAnon();
  const res = await callFn("createCustomRoom");
  const roomId = res["roomId"] as string;
  for (let i = 1; i < targetSize; i++) {
    signOut();
    await signInAnon();
    await callFn("joinRoomById", {roomId});
  }
  return roomId;
};
