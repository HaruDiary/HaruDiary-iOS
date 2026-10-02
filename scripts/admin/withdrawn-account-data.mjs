// Finds diaries, photos and user documents left by accounts that no longer exist in Firebase Auth
// (withdrawn before account deletion erased data, or anonymous accounts removed when linking).
//
// Also reports guest (anonymous) accounts unused for a long time: a guest left behind when switching to an
// existing Google/Apple account cannot always be deleted by the app (Firebase requires a recent sign-in).
//
// Default is a dry run that prints counts only. `--delete` erases the withdrawn accounts' data;
// `--delete-inactive-guests` also deletes inactive guests (data and the Auth account). `--guest-days=180` sets "inactive".
// Diary contents, e-mails and names are never printed.
//
//   cd scripts/admin && npm install
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//   FIREBASE_STORAGE_BUCKET=<bucket from the Firebase console> \
//   node withdrawn-account-data.mjs [--delete]
//
// Never commit the service-account file.
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

const shouldDelete = process.argv.includes("--delete");
const shouldDeleteGuests = process.argv.includes("--delete-inactive-guests");
const guestDays = Number(process.argv.find((arg) => arg.startsWith("--guest-days="))?.split("=")[1] ?? 180);
const bucketName = process.env.FIREBASE_STORAGE_BUCKET;
if (!bucketName) {
  console.error("FIREBASE_STORAGE_BUCKET is required.");
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), storageBucket: bucketName });
const auth = getAuth();
const db = getFirestore();
const bucket = getStorage().bucket();

// users/{uid} documents may not exist (only the diaries subcollection does), so owners come from the diaries.
const diariesByUser = new Map();
for (const doc of (await db.collectionGroup("diaries").get()).docs) {
  const uid = doc.ref.parent.parent?.id;
  if (!uid) continue;
  if (!diariesByUser.has(uid)) diariesByUser.set(uid, []);
  diariesByUser.get(uid).push(doc);
}

// users/{uid} itself holds what the app writes about an account (support code, nickname, sign-in method, e-mail).
// Only documents that were written exist here; an account can have one without any diary.
const directoryDocs = new Map();
for (const doc of (await db.collection("users").get()).docs) directoryDocs.set(doc.id, doc.ref);

// The app stores photos as `{uid}/{file}`. Other files (bucket root, older folders such as `diary_…/`)
// cannot be tied to an account and are only reported, never deleted.
const looksLikeUserID = (name) => /^[A-Za-z0-9]{28}$/.test(name);
const filesByOwner = new Map();
const unassigned = new Map();
const [files] = await bucket.getFiles();
for (const file of files) {
  const parts = file.name.split("/");
  const owner = parts[0];
  const target = parts.length > 1 && looksLikeUserID(owner) ? filesByOwner : unassigned;
  const key = parts.length > 1 ? owner : "(bucket root)";
  if (!target.has(key)) target.set(key, []);
  target.get(key).push(file);
}

const candidates = [...new Set([...diariesByUser.keys(), ...filesByOwner.keys(), ...directoryDocs.keys()])];
const existing = new Set();
const records = new Map();
for (let i = 0; i < candidates.length; i += 100) {
  const { users } = await auth.getUsers(candidates.slice(i, i + 100).map((uid) => ({ uid })));
  users.forEach((user) => {
    existing.add(user.uid);
    records.set(user.uid, user);
  });
}

// A guest has no Google/Apple sign-in. "Inactive" uses the last token refresh (app use), else the last sign-in.
const lastActive = (user) => new Date(user.metadata.lastRefreshTime ?? user.metadata.lastSignInTime ?? user.metadata.creationTime);
const isInactiveGuest = (user) =>
  user.providerData.length === 0 && Date.now() - lastActive(user).getTime() > guestDays * 24 * 60 * 60 * 1000;
const inactiveGuests = [...records.values()].filter(isInactiveGuest).map((user) => user.uid);
const withdrawn = candidates.filter((uid) => !existing.has(uid));

// Photos still shown by an existing account's diary are never deleted, whatever folder they are in.
const storagePath = (url) => {
  const match = /\/o\/([^?]+)/.exec(url);
  return match ? decodeURIComponent(match[1]) : null;
};
const referencedByExisting = new Set();
for (const uid of existing) {
  for (const doc of diariesByUser.get(uid) ?? []) {
    const urls = doc.get("imageURL") ?? [];
    urls.map(storagePath).filter(Boolean).forEach((path) => referencedByExisting.add(path));
  }
}
for (const uid of withdrawn) {
  const kept = (filesByOwner.get(uid) ?? []).filter((file) => !referencedByExisting.has(file.name));
  filesByOwner.set(uid, kept);
}

let diaryCount = 0;
let fileCount = 0;
withdrawn.forEach((uid, index) => {
  const diaries = diariesByUser.get(uid)?.length ?? 0;
  const photos = filesByOwner.get(uid)?.length ?? 0;
  diaryCount += diaries;
  fileCount += photos;
  // Account IDs are shortened so the output can be shared.
  console.log(`#${index + 1} ${uid.slice(0, 6)}…  diaries ${diaries}, photo files ${photos}, user document ${directoryDocs.has(uid) ? "yes" : "no"}`);
});
console.log(`Accounts checked: ${candidates.length}, still existing: ${existing.size}`);
const withdrawnDocs = withdrawn.filter((uid) => directoryDocs.has(uid)).length;
console.log(`Withdrawn accounts with data: ${withdrawn.length} (diaries ${diaryCount}, photo files ${fileCount}, user documents ${withdrawnDocs})`);
let guestDiaries = 0;
let guestFiles = 0;
inactiveGuests.forEach((uid) => {
  guestDiaries += diariesByUser.get(uid)?.length ?? 0;
  guestFiles += filesByOwner.get(uid)?.length ?? 0;
});
console.log(`Guest accounts unused for ${guestDays}+ days with data: ${inactiveGuests.length} (diaries ${guestDiaries}, photo files ${guestFiles})`);
for (const [folder, list] of unassigned) {
  const inUse = list.filter((file) => referencedByExisting.has(file.name)).length;
  console.log(`Not tied to an account (kept): ${folder.slice(0, 12)} ${list.length} files, ${inUse} shown in existing diaries`);
}

if (!shouldDelete && !shouldDeleteGuests) {
  console.log("Dry run. Nothing was deleted. --delete erases withdrawn accounts' data; --delete-inactive-guests removes inactive guests.");
  process.exit(0);
}

const eraseData = async (uid) => {
  for (const file of filesByOwner.get(uid) ?? []) await file.delete({ ignoreNotFound: true });
  const refs = (diariesByUser.get(uid) ?? []).map((doc) => doc.ref);
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    refs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
  // Last, like the app's own withdrawal: the user document goes once the diaries are gone.
  await directoryDocs.get(uid)?.delete();
};

if (shouldDeleteGuests) {
  let removedGuests = 0;
  for (const uid of inactiveGuests) {
    // Recheck: the guest may have been used again or linked to Google/Apple since the listing.
    const current = await auth.getUser(uid).catch(() => null);
    if (!current || !isInactiveGuest(current)) continue;
    await eraseData(uid);
    await auth.deleteUser(uid);
    removedGuests += 1;
  }
  console.log(`Deleted ${removedGuests} inactive guest accounts and their data.`);
  if (!shouldDelete) process.exit(0);
}

let erased = 0;
for (const uid of withdrawn) {
  // Recheck right before deleting, in case the account signed in again since the listing.
  const stillMissing = await auth.getUser(uid).then(() => false, (error) => error.code === "auth/user-not-found");
  if (!stillMissing) continue;
  await eraseData(uid);
  erased += 1;
}
console.log(`Deleted data of ${erased} withdrawn accounts (${withdrawn.length - erased} skipped because the account exists again).`);
