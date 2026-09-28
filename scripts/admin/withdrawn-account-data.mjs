// Finds diaries and photos left by accounts that no longer exist in Firebase Auth
// (withdrawn before account deletion erased data, or anonymous accounts removed when linking).
//
// Default is a dry run that prints counts only. `--delete` erases what the dry run reported.
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

const candidates = [...new Set([...diariesByUser.keys(), ...filesByOwner.keys()])];
const existing = new Set();
for (let i = 0; i < candidates.length; i += 100) {
  const { users } = await auth.getUsers(candidates.slice(i, i + 100).map((uid) => ({ uid })));
  users.forEach((user) => existing.add(user.uid));
}
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
  console.log(`#${index + 1} ${uid.slice(0, 6)}…  diaries ${diaries}, photo files ${photos}`);
});
console.log(`Accounts checked: ${candidates.length}, still existing: ${existing.size}`);
console.log(`Withdrawn accounts with data: ${withdrawn.length} (diaries ${diaryCount}, photo files ${fileCount})`);
for (const [folder, list] of unassigned) {
  const inUse = list.filter((file) => referencedByExisting.has(file.name)).length;
  console.log(`Not tied to an account (kept): ${folder.slice(0, 12)} ${list.length} files, ${inUse} shown in existing diaries`);
}

if (!shouldDelete) {
  console.log("Dry run. Nothing was deleted. Run again with --delete to erase the data above.");
  process.exit(0);
}

for (const uid of withdrawn) {
  // Recheck right before deleting, in case the account signed in again since the listing.
  const stillMissing = await auth.getUser(uid).then(() => false, (error) => error.code === "auth/user-not-found");
  if (!stillMissing) continue;
  for (const file of filesByOwner.get(uid) ?? []) await file.delete({ ignoreNotFound: true });
  const refs = (diariesByUser.get(uid) ?? []).map((doc) => doc.ref);
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    refs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}
console.log(`Deleted data of ${withdrawn.length} withdrawn accounts.`);
