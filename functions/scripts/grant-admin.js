#!/usr/bin/env node
// functions/scripts/grant-admin.js
//
// Grant the app's admin role to an existing account, by email.
// Needed for the FIRST admin (the in-app "Assign Admin" button only works
// for someone who is already an admin) or when locked out.
//
// What it does:
//   • Admins/{uid}                  → farmer-side admin (admin panel, rules' isAdmin())
//   • custom claim  admin: true     → legacy check, kept in sync
//   • with --edu: EducationUsers/{uid}.role = 'mainadmin', approved
//     (education Main Admin — approves headteachers). Requires the account to
//     already have an education profile.
//   • writes an admin_logs entry.
//
// Usage (from the functions/ folder, with credentials for the project):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node scripts/grant-admin.js someone@example.com [--edu] [--dry-run]
//
// Get a service-account key: Firebase Console → Project settings → Service
// accounts → Generate new private key. Keep it out of git; delete it after.

const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const PROJECT_ID = process.env.GCLOUD_PROJECT || "kilimomkononi-e1031";

async function main() {
  const args = process.argv.slice(2);
  const email = args.find((a) => !a.startsWith("--"));
  const edu = args.includes("--edu");
  const dryRun = args.includes("--dry-run");
  if (!email) {
    console.error("Usage: node scripts/grant-admin.js <email> [--edu] [--dry-run]");
    process.exit(2);
  }

  initializeApp({ projectId: PROJECT_ID });
  const auth = getAuth();
  const db = getFirestore();

  const user = await auth.getUserByEmail(email).catch((e) => {
    if (e.code === "auth/user-not-found") {
      console.error(`No account with email ${email} in ${PROJECT_ID}. They must sign up first.`);
      process.exit(1);
    }
    throw e;
  });
  console.log(`Found ${email} → uid ${user.uid} (project ${PROJECT_ID})`);

  const eduRef = db.doc(`EducationUsers/${user.uid}`);
  const eduSnap = edu ? await eduRef.get() : null;
  if (edu && !eduSnap.exists) {
    console.error(
      "--edu: this account has no EducationUsers profile. Register them in " +
      "education mode first, then re-run with --edu."
    );
    process.exit(1);
  }

  console.log("Will grant:");
  console.log(`  • Admins/${user.uid}`);
  console.log("  • custom claim admin: true");
  if (edu) console.log(`  • EducationUsers/${user.uid}: role 'mainadmin', approved`);
  if (dryRun) {
    console.log("--dry-run: nothing written.");
    return;
  }

  const now = FieldValue.serverTimestamp();
  await db.doc(`Admins/${user.uid}`).set(
    { added: true, email, grantedAt: now, grantedBy: "grant-admin script" },
    { merge: true }
  );
  await auth.setCustomUserClaims(user.uid, { ...(user.customClaims || {}), admin: true });
  if (edu) {
    await eduRef.update({
      role: "mainadmin",
      approvalStatus: "approved",
      approvedBy: "grant-admin script",
      approvedAt: now,
      isDisabled: false,
    });
  }
  await db.collection("admin_logs").add({
    action: `Granted admin${edu ? " + education mainadmin" : ""} to ${email} (${user.uid}) via grant-admin script`,
    timestamp: now,
    adminUid: null,
  });

  console.log("Done. The user should sign out and back in so the app picks up the new role.");
}

main().catch((e) => {
  console.error("Failed:", e.message);
  process.exit(1);
});
