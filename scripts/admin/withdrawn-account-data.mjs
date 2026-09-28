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
  diariesByUser.get(uid).push(doc.ref);
}

// Photos are stored as `{uid}/{file}`.
const filesByOwner = new Map();
const [files] = await bucket.getFiles();
for (const file of files) {
  const owner = file.name.split("/")[0];
  if (!filesByOwner.has(owner)) filesByOwner.set(owner, []);
  filesByOwner.get(owner).push(file);
}

const candidates = [...new Set([...diariesByUser.keys(), ...filesByOwner.keys()])].filter((id) => id !== "UnknownUser");
const existing = new Set();
for (let i = 0; i < candidates.length; i += 100) {
  const { users } = await auth.getUsers(candidates.slice(i, i + 100).map((uid) => ({ uid })));
  users.forEach((user) => existing.add(user.uid));
}
const withdrawn = candidates.filter((uid) => !existing.has(uid));

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
const unknownFiles = filesByOwner.get("UnknownUser")?.length ?? 0;
if (unknownFiles > 0) console.log(`Photo files uploaded without a user (UnknownUser/): ${unknownFiles} (not deleted)`);

if (!shouldDelete) {
  console.log("Dry run. Nothing was deleted. Run again with --delete to erase the data above.");
  process.exit(0);
}

for (const uid of withdrawn) {
  // Recheck right before deleting, in case the account signed in again since the listing.
  const stillMissing = await auth.getUser(uid).then(() => false, (error) => error.code === "auth/user-not-found");
  if (!stillMissing) continue;
  for (const file of filesByOwner.get(uid) ?? []) await file.delete({ ignoreNotFound: true });
  const refs = diariesByUser.get(uid) ?? [];
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    refs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}
console.log(`Deleted data of ${withdrawn.length} withdrawn accounts.`);
