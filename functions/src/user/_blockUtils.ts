import * as admin from "firebase-admin";

export interface BlockListEntry {
  blockedBy: string;
  userId: string;
  amount: number;
}

/**
 * Fetches the UIDs blocked by a given user from Firestore.
 * @param {admin.firestore.Firestore} db
 * @param {string} uid
 * @return {Promise<string[]>}
 */
export async function getBlockedUids(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<string[]> {
  const snap = await db.collection("users").doc(uid).collection("blocked").get();
  return snap.docs.map((d) => d.id);
}

/**
 * Merges a joiner's blocked UIDs into the room blockList.
 * Increments amount for existing entries; adds new entries.
 * @param {BlockListEntry[]} current
 * @param {string} joinerUid
 * @param {string[]} blockedUids
 * @return {BlockListEntry[]}
 */
export function mergeIntoBlockList(
  current: BlockListEntry[],
  joinerUid: string,
  blockedUids: string[],
): BlockListEntry[] {
  const result = current.map((e) => ({...e}));
  for (const userId of blockedUids) {
    const existing = result.find((e) => e.userId === userId);
    if (existing) {
      existing.amount++;
    } else {
      result.push({blockedBy: joinerUid, userId, amount: 1});
    }
  }
  return result;
}

/**
 * Decrements/removes a leaver's blocked entries from the room blockList.
 * @param {BlockListEntry[]} current
 * @param {string[]} blockedUids
 * @return {BlockListEntry[]}
 */
export function removeFromBlockList(
  current: BlockListEntry[],
  blockedUids: string[],
): BlockListEntry[] {
  return current
    .map((e) =>
      blockedUids.includes(e.userId) ? {...e, amount: e.amount - 1} : e,
    )
    .filter((e) => e.amount > 0);
}

/**
 * Returns true if the given uid is blocked by anyone in the room.
 * @param {BlockListEntry[]} blockList
 * @param {string} uid
 * @return {boolean}
 */
export function isBlockedByRoom(blockList: BlockListEntry[], uid: string): boolean {
  return blockList.some((e) => e.userId === uid);
}
