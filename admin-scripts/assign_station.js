// assign_station.js
//
// Assigns a physical NuaSense station (gateway_id) to a farmer's account —
// the same operation the assignStationToUser Cloud Function performs, run
// directly here via the Admin SDK so you don't need the `admin: true`
// custom claim wired up yet to get your first real station live.
//
// Run this ONCE PER FARMER, once per platform (KM, CC) — each project has
// its own Firestore, so the same gateway_id can only ever be "seen" by
// whichever project you assign it in.
//
// IMPORTANT: this is a many-to-one relationship on purpose. More than one
// farmer can legitimately share a single physical station (e.g. several
// office accounts near the same install) — assigning a second farmer to a
// station does NOT remove the first farmer's access. Each (gatewayId, uid)
// pair gets its own Firestore doc, keyed by `${gatewayId}_${uid}`, so
// assignments never overwrite each other. Run this once per person who
// should see the station's data.
//
// ── Setup (one-time per project) ────────────────────────────────────────
// 1. Firebase Console → Project Settings → Service Accounts →
//    "Generate new private key" → save as serviceAccountKey.json next to
//    this script (do NOT commit this file — add it to .gitignore).
// 2. npm install firebase-admin
//
// ── Usage ────────────────────────────────────────────────────────────────
//   node assign_station.js <gatewayId> <uid> <platform: km|cc> [plotId]
//
// Example — assigning the same station to two different office accounts:
//   node assign_station.js b4bfe9fffe06d0d8 uidForPerson1 km
//   node assign_station.js b4bfe9fffe06d0d8 uidForPerson2 km
//   (both now see this station; neither call affected the other)
//
// To find a farmer's uid: Firebase Console → Authentication → Users, or
// Firestore → Users collection (the document ID is the uid).

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

async function assignStation(gatewayId, uid, platform, plotId) {
  if (!["km", "cc"].includes(platform)) {
    throw new Error("platform must be 'km' or 'cc'");
  }

  const docId = `${gatewayId}_${uid}`;

  // Mirrors assignStationToUser: clear this farmer's OTHER assignment(s)
  // on this platform before writing the new one, so a stale gateway_id
  // never lingers as still "owned" by them. This only ever touches docs
  // belonging to THIS uid — it never removes a different farmer's
  // assignment to this or any other station.

  const staleAssignments = await db
    .collection("stationAssignments")
    .where("uid", "==", uid)
    .where("platform", "==", platform)
    .get();

  const batch = db.batch();
  staleAssignments.docs.forEach((doc) => {
    if (doc.id !== docId) {
      console.log(`  Removing this farmer's stale assignment: ${doc.id}`);
      batch.delete(doc.ref);
    }
  });

  batch.set(db.collection("stationAssignments").doc(docId), {
    gatewayId,
    uid,
    platform,
    plotId: plotId || null,
    assignedAt: FieldValue.serverTimestamp(),
    assignedBy: "manual-script",
  });

  await batch.commit();
  console.log(`✅ Assigned station ${gatewayId} → uid ${uid} (${platform})`);
}

const [gatewayId, uid, platform, plotId] = process.argv.slice(2);

if (!gatewayId || !uid || !platform) {
  console.error(
    "Usage: node assign_station.js <gatewayId> <uid> <platform: km|cc> [plotId]"
  );
  process.exit(1);
}

assignStation(gatewayId, uid, platform, plotId)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Failed:", err.message);
    process.exit(1);
  });