// Security-rules tests for ../firestore.rules and ../storage.rules.
// Run from this folder:  npm install && npm test
// (Starts the Firestore + Storage emulators for a demo project and runs
//  `node --test`; nothing here touches the real kilimomkononi-e1031 data.)

const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc,
  collection, query, where, getDocs, arrayUnion, serverTimestamp,
} = require("firebase/firestore");
const { ref, uploadBytes } = require("firebase/storage");

let env;

// ── Fixture ──────────────────────────────────────────────────────────
const SCHOOL = "St Marys";               // key: St_Marys
const CLASS = "St_Marys_senior_10";
const OTHER_SCHOOL = "Greenwood";
const OTHER_CLASS = "Greenwood_junior_7";

const eduUsers = {
  mainadmin: { role: "mainadmin", approvalStatus: "approved", schoolName: "HQ", requestedRole: "headteacher" },
  head:      { role: "headteacher", approvalStatus: "approved", schoolName: SCHOOL, requestedRole: "headteacher", classIds: [] },
  teacher:   { role: "teacher", approvalStatus: "approved", schoolName: SCHOOL, requestedRole: "teacher", classIds: [CLASS], currentClassId: CLASS },
  student:   { role: "student", approvalStatus: "approved", schoolName: SCHOOL, requestedRole: "student", classIds: [CLASS], currentClassId: CLASS },
  pendStu:   { role: null, approvalStatus: "pending", schoolName: SCHOOL, requestedRole: "student", classIds: [CLASS], currentClassId: CLASS },
  pendTch:   { role: null, approvalStatus: "pending", schoolName: SCHOOL, requestedRole: "teacher", classIds: [] },
  otherTch:  { role: "teacher", approvalStatus: "approved", schoolName: OTHER_SCHOOL, requestedRole: "teacher", classIds: [OTHER_CLASS], currentClassId: OTHER_CLASS },
  otherPend: { role: null, approvalStatus: "pending", schoolName: OTHER_SCHOOL, requestedRole: "student", classIds: [] },
};

const as = (u) => env.authenticatedContext(u).firestore();
const anon = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-kilimomkononi",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
      host: "127.0.0.1", port: 8085,
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, "..", "storage.rules"), "utf8"),
      host: "127.0.0.1", port: 9199,
    },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "Admins/admin"), { added: true });
    for (const [uid, d] of Object.entries(eduUsers)) {
      await setDoc(doc(db, `EducationUsers/${uid}`), { uid, isDisabled: false, fullName: uid, ...d });
    }
    await setDoc(doc(db, "Users/farmer"), { userId: "farmer", fullName: "F", isDisabled: false });
    await setDoc(doc(db, "Users/banned"), { userId: "banned", fullName: "B", isDisabled: true });
    await setDoc(doc(db, "field_costs/c1"), { userId: "farmer", amount: 10 });
    await setDoc(doc(db, "field_costs/c2"), { userId: "other", amount: 99 });
    await setDoc(doc(db, `schools/St_Marys/systems/senior/grades/10/field_submissions/s1`), { v: 1 });
    await setDoc(doc(db, `schools/Greenwood/systems/junior/grades/7/field_submissions/g1`), { v: 1 });
    await setDoc(doc(db, "schools/St_Marys/grades/10/questions/q1"), { text: "hi" });
    await setDoc(doc(db, "submissions/sub1"), { studentId: "student", gradeId: CLASS, module: "farming_content", score: 50 });
    await setDoc(doc(db, "submissions/sub2"), { studentId: "x", gradeId: OTHER_CLASS, module: "farming_content", score: 70 });
    await setDoc(doc(db, "Schools/KME-ABC123"), { schoolName: SCHOOL, schoolCode: "KME-ABC123", headteacherUID: "head" });
  });
});

// ═════════════════════════════════════════════════════════════════════
//  1. Education privilege escalation (critical #1)
// ═════════════════════════════════════════════════════════════════════
test("student cannot promote themselves to teacher or mainadmin", async () => {
  await assertFails(updateDoc(doc(as("student"), "EducationUsers/student"), { role: "teacher" }));
  await assertFails(updateDoc(doc(as("student"), "EducationUsers/student"), { role: "mainadmin" }));
});

test("pending user cannot self-approve or change requested role / school", async () => {
  const db = as("pendStu");
  await assertFails(updateDoc(doc(db, "EducationUsers/pendStu"), { approvalStatus: "approved" }));
  await assertFails(updateDoc(doc(db, "EducationUsers/pendStu"), { requestedRole: "headteacher" }));
  await assertFails(updateDoc(doc(db, "EducationUsers/pendStu"), { schoolName: OTHER_SCHOOL }));
  await assertFails(updateDoc(doc(db, "EducationUsers/pendStu"), { isDisabled: true }));
});

test("user can still edit ordinary profile fields", async () => {
  await assertSucceeds(updateDoc(doc(as("student"), "EducationUsers/student"), { fullName: "New Name", phone: "0700" }));
});

test("sign-up must be pending with no role", async () => {
  const base = { uid: "newbie", fullName: "N", schoolName: SCHOOL, requestedRole: "student",
    isDisabled: false, currentClassId: CLASS, classIds: [CLASS] };
  await assertSucceeds(setDoc(doc(as("newbie"), "EducationUsers/newbie"), { ...base, role: null, approvalStatus: "pending" }));
  await assertFails(setDoc(doc(as("evil"), "EducationUsers/evil"), { ...base, uid: "evil", role: "teacher", approvalStatus: "pending" }));
  await assertFails(setDoc(doc(as("evil2"), "EducationUsers/evil2"), { ...base, uid: "evil2", role: null, approvalStatus: "approved" }));
  await assertFails(setDoc(doc(as("evil3"), "EducationUsers/evil3"), { ...base, uid: "evil3", role: null, approvalStatus: "pending",
    currentClassId: OTHER_CLASS, classIds: [OTHER_CLASS] }));
});

test("classIds can only gain classes of the user's own school", async () => {
  const db = as("teacher");
  await assertSucceeds(updateDoc(doc(db, "EducationUsers/teacher"), {
    classIds: arrayUnion("St_Marys_senior_11"), currentClassId: "St_Marys_senior_11",
  }));
  await assertFails(updateDoc(doc(db, "EducationUsers/teacher"), {
    classIds: arrayUnion(OTHER_CLASS), currentClassId: OTHER_CLASS,
  }));
  // Can't sneak a class in without it being the validated currentClassId.
  await assertFails(updateDoc(doc(db, "EducationUsers/teacher"), { classIds: arrayUnion("St_Marys_senior_12") }));
});

test("approval chain: teacher→student, headteacher→teacher, same school only", async () => {
  // teacher approves a student of their school
  await assertSucceeds(updateDoc(doc(as("teacher"), "EducationUsers/pendStu"), {
    approvalStatus: "approved", role: "student", approvedBy: "teacher", approvedAt: serverTimestamp(),
  }));
  // …but cannot grant a different role than requested
  await assertFails(updateDoc(doc(as("teacher"), "EducationUsers/pendTch"), {
    approvalStatus: "approved", role: "teacher", approvedBy: "teacher", approvedAt: serverTimestamp(),
  }));
  // headteacher approves the teacher
  await assertSucceeds(updateDoc(doc(as("head"), "EducationUsers/pendTch"), {
    approvalStatus: "approved", role: "teacher", approvedBy: "head", approvedAt: serverTimestamp(),
  }));
  // other school's teacher cannot approve our students
  await assertFails(updateDoc(doc(as("otherTch"), "EducationUsers/student"), {
    approvalStatus: "denied", approvedBy: "otherTch", approvedAt: serverTimestamp(),
  }));
});

test("EducationUsers visibility is scoped to the school", async () => {
  // staff list their own school
  await assertSucceeds(getDocs(query(collection(as("teacher"), "EducationUsers"),
    where("schoolName", "==", SCHOOL), where("approvalStatus", "==", "pending"), where("requestedRole", "==", "student"))));
  // …but not everyone
  await assertFails(getDocs(collection(as("teacher"), "EducationUsers")));
  await assertFails(getDoc(doc(as("teacher"), "EducationUsers/otherTch")));
  // students can list their school's teachers
  await assertSucceeds(getDocs(query(collection(as("student"), "EducationUsers"),
    where("schoolName", "==", SCHOOL), where("role", "==", "teacher"), where("classIds", "array-contains", CLASS))));
  // mainadmin lists all headteacher applications
  await assertSucceeds(getDocs(query(collection(as("mainadmin"), "EducationUsers"),
    where("approvalStatus", "==", "pending"), where("requestedRole", "==", "headteacher"))));
});

// ═════════════════════════════════════════════════════════════════════
//  2. Farmer self re-enable (critical #2)
// ═════════════════════════════════════════════════════════════════════
test("disabled farmer cannot re-enable themselves", async () => {
  await assertFails(updateDoc(doc(as("banned"), "Users/banned"), { isDisabled: false }));
  await assertFails(setDoc(doc(as("banned"), "Users/banned"), { userId: "banned", fullName: "B", isDisabled: false }));
});

test("farmer can edit their profile (incl. full .set) but not others'", async () => {
  await assertSucceeds(updateDoc(doc(as("farmer"), "Users/farmer"), { fullName: "Farmer F" }));
  await assertSucceeds(setDoc(doc(as("farmer"), "Users/farmer"), { userId: "farmer", fullName: "F2", isDisabled: false }));
  await assertFails(updateDoc(doc(as("farmer"), "Users/farmer"), { isDisabled: true }));
  await assertFails(getDoc(doc(as("farmer"), "Users/banned")));
});

test("admin can disable a farmer", async () => {
  await assertSucceeds(updateDoc(doc(as("admin"), "Users/farmer"), { isDisabled: true }));
});

test("non-admin can check their own admin status", async () => {
  await assertSucceeds(getDoc(doc(as("farmer"), "Admins/farmer")));
  await assertFails(getDoc(doc(as("farmer"), "Admins/admin")));
});

// ═════════════════════════════════════════════════════════════════════
//  5. Coverage of the real paths (critical #5)
// ═════════════════════════════════════════════════════════════════════
test("grade content: members of the class only", async () => {
  const mine = "schools/St_Marys/systems/senior/grades/10/field_submissions/s1";
  const theirs = "schools/Greenwood/systems/junior/grades/7/field_submissions/g1";
  await assertSucceeds(getDoc(doc(as("student"), mine)));
  await assertSucceeds(getDoc(doc(as("teacher"), mine)));
  await assertSucceeds(getDoc(doc(as("head"), mine)));
  await assertFails(getDoc(doc(as("student"), theirs)));
  await assertFails(getDoc(doc(as("otherTch"), mine)));
  await assertFails(getDoc(doc(as("pendStu"), mine)));   // not approved yet
  await assertSucceeds(addDoc(collection(as("student"), "schools/St_Marys/systems/senior/grades/10/field_submissions"), { v: 2 }));
  await assertFails(deleteDoc(doc(as("student"), mine)));
  await assertSucceeds(deleteDoc(doc(as("teacher"), mine)));
});

test("legacy grade path: student asks a question in own grade", async () => {
  await assertSucceeds(addDoc(collection(as("student"), "schools/St_Marys/grades/10/questions"), { text: "q" }));
  await assertFails(addDoc(collection(as("otherTch"), "schools/St_Marys/grades/10/questions"), { text: "q" }));
});

test("submissions: students see own, teachers see their class (filtered)", async () => {
  await assertSucceeds(getDocs(query(collection(as("student"), "submissions"),
    where("studentId", "==", "student"), where("gradeId", "==", CLASS))));
  await assertSucceeds(getDocs(query(collection(as("teacher"), "submissions"),
    where("gradeId", "==", CLASS), where("module", "in", ["farming_content", "market_content"]))));
  // the old unfiltered teacher query leaked every school's work
  await assertFails(getDocs(query(collection(as("teacher"), "submissions"),
    where("module", "in", ["farming_content", "market_content"]))));
  await assertSucceeds(updateDoc(doc(as("teacher"), "submissions/sub1"), { score: 80, gradedBy: "teacher", gradedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(as("teacher"), "submissions/sub2"), { score: 100 }));
});

test("owner-scoped farmer collections", async () => {
  await assertSucceeds(getDocs(query(collection(as("farmer"), "field_costs"), where("userId", "==", "farmer"))));
  await assertFails(getDocs(collection(as("farmer"), "field_costs")));
  await assertFails(getDoc(doc(as("farmer"), "field_costs/c2")));
  await assertSucceeds(setDoc(doc(as("farmer"), "field_costs/c3"), { userId: "farmer", amount: 1 }));
  await assertFails(setDoc(doc(as("farmer"), "field_costs/c4"), { userId: "other", amount: 1 }));
  await assertSucceeds(addDoc(collection(as("farmer"), "farmer_issues/farmer/records"), { isDeleted: false }));
  await assertFails(addDoc(collection(as("farmer"), "farmer_issues/other/records"), { isDeleted: false }));
});

test("direct messages are private to the two participants", async () => {
  const conv = ["student", "teacher"].sort().join("_");
  await assertSucceeds(addDoc(collection(as("student"), `DirectMessages/${conv}/messages`), { userId: "student", message: "hi" }));
  await assertFails(getDocs(collection(as("otherTch"), `DirectMessages/${conv}/messages`)));
});

test("school code lookup works before sign-in, but not listing", async () => {
  await assertSucceeds(getDoc(doc(anon(), "Schools/KME-ABC123")));
  await assertFails(getDocs(collection(anon(), "Schools")));
});

test("unknown collections stay denied; admin catch-all works", async () => {
  await assertFails(getDoc(doc(as("farmer"), "secret/x")));
  await assertSucceeds(getDoc(doc(as("admin"), "secret/x")));
});

// ═════════════════════════════════════════════════════════════════════
//  6. Storage (critical #6)
// ═════════════════════════════════════════════════════════════════════
test("storage: diagnosis photos are private; manuals admin/staff only", async () => {
  const bytes = new Uint8Array([1, 2, 3]);
  const st = (u) => env.authenticatedContext(u).storage();
  await assertSucceeds(uploadBytes(ref(st("farmer"), "ai_diagnoses/farmer/a.jpg"), bytes, { contentType: "image/jpeg" }));
  await assertFails(uploadBytes(ref(st("farmer"), "ai_diagnoses/other/a.jpg"), bytes, { contentType: "image/jpeg" }));
  await assertFails(uploadBytes(ref(st("farmer"), "manuals/x.pdf"), bytes, { contentType: "application/pdf" }));
  await assertSucceeds(uploadBytes(ref(st("admin"), "manuals/x.pdf"), bytes, { contentType: "application/pdf" }));
  await assertFails(uploadBytes(ref(st("farmer"), "random/x.bin"), bytes));
});

// ═════════════════════════════════════════════════════════════════════
//  Field Agronomist advisories
// ═════════════════════════════════════════════════════════════════════
const { writeBatch } = require("firebase/firestore");

function advisoryData(uid, { version = 1, status = "draft", extra = {} } = {}) {
  return {
    title: "Wet leaves — Maize", main: "Hold fungicide until leaves dry",
    doList: ["Scout lower leaves"], avoidList: ["Spraying now"], why: "Spores spread on wet leaves.",
    crops: ["Maize"], condition: "wet_leaves", gatewayId: null, stationName: null,
    source: "manual", aiDraft: null, platform: "km", status, version, testOnly: false,
    updatedBy: uid, updatedByName: uid, updatedAt: serverTimestamp(),
    ...(version === 1 ? { createdBy: uid, createdByName: uid, createdAt: serverTimestamp() } : {}),
    ...(status === "published" ? { publishedBy: uid, publishedByName: uid, publishedAt: serverTimestamp() } : {}),
    ...extra,
  };
}

function writeAdvisory(db, id, data, { withHistory = true, create = true } = {}) {
  const b = writeBatch(db);
  const ref = doc(db, `agronomic_advisories/${id}`);
  create ? b.set(ref, data) : b.update(ref, data);
  if (withHistory) {
    b.set(doc(db, `agronomic_advisories/${id}/history/v${data.version}`), {
      version: data.version, action: "x", status: data.status,
      byUid: data.updatedBy, byName: data.updatedBy, at: serverTimestamp(), snapshot: {},
    });
  }
  return b.commit();
}

async function seedAgronomist() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "Agronomists/agro"), { added: true });
  });
}

test("advisories: only Field Agronomists write, always with an audit entry", async () => {
  await seedAgronomist();
  await assertFails(writeAdvisory(as("farmer"), "a1", advisoryData("farmer")));
  await assertFails(writeAdvisory(as("agro"), "a1", advisoryData("agro"), { withHistory: false }));
  await assertSucceeds(writeAdvisory(as("agro"), "a1", advisoryData("agro")));
  // publish (v2) — verifier recorded as the publisher
  await assertSucceeds(writeAdvisory(as("agro"), "a1",
    advisoryData("agro", { version: 2, status: "published" }), { create: false }));
  // skipping a version or forging the verifier is rejected
  await assertFails(writeAdvisory(as("agro"), "a1",
    advisoryData("agro", { version: 5, status: "published" }), { create: false }));
  await assertFails(writeAdvisory(as("agro"), "a1",
    advisoryData("agro", { version: 3, status: "published", extra: { publishedBy: "someoneElse" } }), { create: false }));
});

test("advisories: farmers see published only; history is private and immutable", async () => {
  await seedAgronomist();
  await writeAdvisory(as("agro"), "pub", advisoryData("agro", { status: "published" }));
  await writeAdvisory(as("agro"), "drf", advisoryData("agro"));

  await assertSucceeds(getDocs(query(collection(as("farmer"), "agronomic_advisories"),
    where("status", "==", "published"), where("condition", "in", ["wet_leaves", "general"]),
    where("testOnly", "==", false))));
  // Without the testOnly filter the query could include test advice — refused.
  await assertFails(getDocs(query(collection(as("farmer"), "agronomic_advisories"),
    where("status", "==", "published"), where("condition", "in", ["wet_leaves", "general"]))));
  await assertFails(getDocs(collection(as("farmer"), "agronomic_advisories")));
  await assertFails(getDoc(doc(as("farmer"), "agronomic_advisories/drf")));
  await assertFails(getDocs(collection(as("farmer"), "agronomic_advisories/pub/history")));

  await assertSucceeds(getDocs(collection(as("agro"), "agronomic_advisories/pub/history")));
  await assertFails(updateDoc(doc(as("agro"), "agronomic_advisories/pub/history/v1"), { action: "tampered" }));
  await assertFails(deleteDoc(doc(as("agro"), "agronomic_advisories/pub/history/v1")));
});

test("advisories: published advice is archived, not deleted; drafts can be deleted", async () => {
  await seedAgronomist();
  await writeAdvisory(as("agro"), "pub", advisoryData("agro", { status: "published" }));
  await writeAdvisory(as("agro"), "drf", advisoryData("agro"));
  await assertFails(deleteDoc(doc(as("agro"), "agronomic_advisories/pub")));
  await assertSucceeds(deleteDoc(doc(as("agro"), "agronomic_advisories/drf")));
});

test("advisories: verifier and notify fields only change by publishing", async () => {
  await seedAgronomist();
  // publish (v1) with a notification, then unpublish (v2) keeping the verifier
  await assertSucceeds(writeAdvisory(as("agro"), "v1",
    advisoryData("agro", { status: "published", extra: { notifyVersion: 1 } })));
  await assertSucceeds(writeAdvisory(as("agro"), "v1",
    advisoryData("agro", { version: 2 }), { create: false }));
  // can't make it look never-published, then delete it
  await assertFails(writeAdvisory(as("agro"), "v1",
    advisoryData("agro", { version: 3, extra: { publishedAt: null } }), { create: false }));
  await assertFails(writeAdvisory(as("agro"), "v1",
    advisoryData("agro", { version: 3, extra: { publishedByName: "someoneElse" } }), { create: false }));
  await assertFails(deleteDoc(doc(as("agro"), "agronomic_advisories/v1")));
  // can't re-notify farmers without publishing
  await assertFails(writeAdvisory(as("agro"), "v1",
    advisoryData("agro", { version: 3, extra: { notifyVersion: 3 } }), { create: false }));
  // republish with a new notification; notifyVersion can't run ahead
  await assertFails(writeAdvisory(as("agro"), "v1",
    advisoryData("agro", { version: 3, status: "published", extra: { notifyVersion: 4 } }), { create: false }));
  await assertSucceeds(writeAdvisory(as("agro"), "v1",
    advisoryData("agro", { version: 3, status: "published", extra: { notifyVersion: 3 } }), { create: false }));
});

test("advisories: frost is a valid condition; titles are bounded", async () => {
  await seedAgronomist();
  await assertSucceeds(writeAdvisory(as("agro"), "f1",
    advisoryData("agro", { extra: { condition: "frost" } })));
  await assertFails(writeAdvisory(as("agro"), "f2",
    advisoryData("agro", { extra: { condition: "blizzard" } })));
  await assertFails(writeAdvisory(as("agro"), "f3",
    advisoryData("agro", { extra: { title: "x".repeat(201) } })));
});

test("advisories: agronomists can't edit or delete admin TEST advisories", async () => {
  await seedAgronomist();
  await assertSucceeds(writeAdvisory(as("admin"), "t1",
    advisoryData("admin", { extra: { testOnly: true } })));
  // flipping it live is refused too
  await assertFails(writeAdvisory(as("agro"), "t1",
    advisoryData("agro", { version: 2 }), { create: false }));
  await assertFails(deleteDoc(doc(as("agro"), "agronomic_advisories/t1")));
});

test("advisories: a deleted draft takes its history with it — nothing else does", async () => {
  await seedAgronomist();
  await writeAdvisory(as("agro"), "d1", advisoryData("agro"));
  await writeAdvisory(as("agro"), "d1", advisoryData("agro", { version: 2 }), { create: false });
  // history alone can't be removed while the advisory exists
  await assertFails(deleteDoc(doc(as("agro"), "agronomic_advisories/d1/history/v1")));
  const agro = as("agro");
  const b = writeBatch(agro);
  b.delete(doc(agro, "agronomic_advisories/d1/history/v1"));
  b.delete(doc(agro, "agronomic_advisories/d1/history/v2"));
  b.delete(doc(agro, "agronomic_advisories/d1"));
  await assertSucceeds(b.commit());

  // published advice keeps its history, even alongside a (refused) delete
  await writeAdvisory(as("agro"), "p1", advisoryData("agro", { status: "published" }));
  const b2 = writeBatch(agro);
  b2.delete(doc(agro, "agronomic_advisories/p1/history/v1"));
  b2.delete(doc(agro, "agronomic_advisories/p1"));
  await assertFails(b2.commit());
});

test("agronomist role can only be granted by an admin", async () => {
  await assertFails(setDoc(doc(as("farmer"), "Agronomists/farmer"), { added: true }));
  await assertSucceeds(setDoc(doc(as("admin"), "Agronomists/farmer"), { added: true }));
  await assertSucceeds(getDoc(doc(as("farmer"), "Agronomists/farmer")));
});

test("admin test mode: test advisories never reach farmers", async () => {
  await seedAgronomist();
  // Admin publishes a TEST advisory (allowed through the admin catch-all).
  await assertSucceeds(writeAdvisory(as("admin"), "t1",
    advisoryData("admin", { status: "published", extra: { testOnly: true } })));
  // Agronomists can't create test advisories — theirs are always live.
  await assertFails(writeAdvisory(as("agro"), "t2",
    advisoryData("agro", { status: "published", extra: { testOnly: true } })));

  await assertFails(getDoc(doc(as("farmer"), "agronomic_advisories/t1")));
  const farmerView = await getDocs(query(collection(as("farmer"), "agronomic_advisories"),
    where("status", "==", "published"), where("condition", "in", ["wet_leaves"]),
    where("testOnly", "==", false)));
  assert.equal(farmerView.size, 0);
  // Admin sees it in the farmer view (includeTest).
  const adminView = await getDocs(query(collection(as("admin"), "agronomic_advisories"),
    where("status", "==", "published"), where("condition", "in", ["wet_leaves"])));
  assert.equal(adminView.size, 1);
});

test("market prices: everyone signed in reads the board; only the reporter edits", async () => {
  const report = { userId: "farmer", cropType: "Maize", market: "Nakuru Wakulima", region: "Nakuru",
    retailPrice: 3500, unit: "per 90 kg bag", timestamp: serverTimestamp() };
  await assertSucceeds(setDoc(doc(as("farmer"), "marketdata/m1"), report));
  await assertSucceeds(getDoc(doc(as("stranger"), "marketdata/m1")));
  await assertSucceeds(getDocs(query(collection(as("stranger"), "marketdata"), where("cropType", "==", "Maize"))));
  await assertFails(getDoc(doc(anon(), "marketdata/m1")));
  await assertFails(updateDoc(doc(as("stranger"), "marketdata/m1"), { retailPrice: 1 }));
  await assertFails(deleteDoc(doc(as("stranger"), "marketdata/m1")));
  await assertSucceeds(updateDoc(doc(as("farmer"), "marketdata/m1"), { retailPrice: 3600 }));
  // invalid reports are refused
  await assertFails(setDoc(doc(as("farmer"), "marketdata/m2"), { ...report, retailPrice: -5 }));
  await assertFails(setDoc(doc(as("farmer"), "marketdata/m3"), { ...report, cropType: "" }));
  await assertFails(setDoc(doc(as("farmer"), "marketdata/m4"), { ...report, userId: "someoneElse" }));
});

test("support messages: sender creates and reads their own; strangers can't", async () => {
  const msg = { userId: "farmer", topic: "problem", name: "Jane", email: "jane@farm.ke",
    message: "The weather screen is blank", status: "open", createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(as("farmer"), "supportMessages/s1"), msg));
  await assertSucceeds(getDoc(doc(as("farmer"), "supportMessages/s1")));
  await assertSucceeds(getDocs(query(collection(as("farmer"), "supportMessages"), where("userId", "==", "farmer"))));
  await assertFails(getDoc(doc(as("stranger"), "supportMessages/s1")));
  await assertFails(updateDoc(doc(as("farmer"), "supportMessages/s1"), { status: "resolved" }));
  await assertFails(setDoc(doc(as("farmer"), "supportMessages/s2"), { ...msg, userId: "someoneElse" }));
  await assertFails(setDoc(doc(as("farmer"), "supportMessages/s3"), { ...msg, topic: "spam" }));
  await assertFails(setDoc(doc(as("farmer"), "supportMessages/s4"), { ...msg, message: "" }));
  await assertFails(setDoc(doc(as("farmer"), "supportMessages/s5"), { ...msg, reply: "Fixed!" }));
  await assertFails(setDoc(doc(anon(), "supportMessages/s6"), msg));
});

test("notification settings: owner only, valid fields only", async () => {
  const prefs = {
    push: true, weatherAlerts: false, advisories: true, approvals: true,
    fieldReminders: true, pestReminders: false, diseaseReminders: true, taskReminders: true,
    taskReminderHour: 7, taskReminderMinute: 30, updatedAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(as("farmer"), "notificationPrefs/farmer"), prefs));
  await assertSucceeds(getDoc(doc(as("farmer"), "notificationPrefs/farmer")));
  await assertFails(getDoc(doc(as("stranger"), "notificationPrefs/farmer")));
  await assertFails(setDoc(doc(as("stranger"), "notificationPrefs/farmer"), prefs));
  await assertFails(setDoc(doc(as("farmer"), "notificationPrefs/farmer"), { ...prefs, taskReminderHour: 24 }));
  await assertFails(setDoc(doc(as("farmer"), "notificationPrefs/farmer"), { ...prefs, push: "yes" }));
  await assertFails(setDoc(doc(as("farmer"), "notificationPrefs/farmer"), { ...prefs, isAdmin: true }));
});

test("push: device tokens and inbox are private to their owner", async () => {
  await assertSucceeds(setDoc(doc(as("farmer"), "deviceTokens/tokA"), { uid: "farmer", platform: "android", updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(as("farmer"), "deviceTokens/tokB"), { uid: "someoneElse", platform: "android" }));
  await assertFails(getDoc(doc(as("student"), "deviceTokens/tokA")));
  // Shared phone: next user signs in and takes over the device.
  await assertSucceeds(setDoc(doc(as("student"), "deviceTokens/tokA"), { uid: "student", platform: "android", updatedAt: serverTimestamp() }));

  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "userNotifications/farmer/items/n1"), { title: "Heavy rain", read: false });
  });
  await assertSucceeds(getDocs(collection(as("farmer"), "userNotifications/farmer/items")));
  await assertFails(getDocs(collection(as("student"), "userNotifications/farmer/items")));
  await assertSucceeds(updateDoc(doc(as("farmer"), "userNotifications/farmer/items/n1"), { read: true }));
  await assertFails(updateDoc(doc(as("farmer"), "userNotifications/farmer/items/n1"), { title: "forged" }));
  await assertFails(addDoc(collection(as("farmer"), "userNotifications/farmer/items"), { title: "self-made" }));
  await assertFails(getDoc(doc(as("farmer"), "alertState/gw1_heat")));
});

test("advisories: soil / pest / disease actions are allowed but bounded", async () => {
  await seedAgronomist();
  const actions = {
    soilActions: [{ nutrient: "N", low: { action: "Top-dress CAN", rate: "50 kg/acre" } }],
    pestChecks: [{ name: "Aphids", signs: "Curled leaves", ifFound: "Spray neem" }],
    diseaseChecks: [{ name: "Late Blight", signs: "Dark lesions", ifFound: "Remove infected leaves" }],
  };
  await assertSucceeds(writeAdvisory(as("agro"), "act1", advisoryData("agro", { extra: actions })));
  const tooMany = Array.from({ length: 11 }, (_, i) => ({ name: `Pest ${i}` }));
  await assertFails(writeAdvisory(as("agro"), "act2", advisoryData("agro", { extra: { pestChecks: tooMany } })));
  await assertFails(writeAdvisory(as("agro"), "act3", advisoryData("agro", { extra: { soilActions: "N low" } })));
});

test("advisories: moderate weather and typed conditions (named, ranges optional)", async () => {
  await seedAgronomist();
  await assertSucceeds(writeAdvisory(as("agro"), "m1",
    advisoryData("agro", { extra: { condition: "moderate" } })));
  await assertSucceeds(writeAdvisory(as("agro"), "c1",
    advisoryData("agro", { extra: { condition: "custom",
      customCondition: { label: "Warm and humid", tempMin: 20, tempMax: 30, humidityMin: 75 } } })));
  await assertSucceeds(writeAdvisory(as("agro"), "c2",
    advisoryData("agro", { extra: { condition: "custom", customCondition: { label: "Before planting" } } })));
  // A typed condition needs its name.
  await assertFails(writeAdvisory(as("agro"), "c3",
    advisoryData("agro", { extra: { condition: "custom" } })));
  await assertFails(writeAdvisory(as("agro"), "c4",
    advisoryData("agro", { extra: { condition: "custom", customCondition: { label: "" } } })));
  await assertFails(writeAdvisory(as("agro"), "c5",
    advisoryData("agro", { extra: { condition: "custom", customCondition: { label: "x".repeat(61) } } })));
});

test("advisories: soil actions by crop stage with per-acre rates, up to 20", async () => {
  await seedAgronomist();
  const staged = (i) => ({
    nutrient: "N", stages: [`Stage ${i}`],
    general: { action: "Top-dress CAN", rate: "50 kg per acre", amount: 50, unit: "kg", per: "acre" },
  });
  await assertSucceeds(writeAdvisory(as("agro"), "s1",
    advisoryData("agro", { extra: { soilActions: Array.from({ length: 20 }, (_, i) => staged(i)) } })));
  await assertFails(writeAdvisory(as("agro"), "s2",
    advisoryData("agro", { extra: { soilActions: Array.from({ length: 21 }, (_, i) => staged(i)) } })));
});

test("advisory responses: farmers keep their own answers only", async () => {
  const mine = doc(as("farmer"), "advisoryResponses/farmer_adv1");
  const ok = { userId: "farmer", advisoryId: "adv1", items: { "pests:Aphids": "found" }, updatedAt: serverTimestamp() };
  await assertSucceeds(setDoc(mine, ok));
  await assertSucceeds(getDoc(mine));
  await assertSucceeds(setDoc(mine, { items: { "soil:N@SingleCrop": "logged:low" } }, { merge: true }));
  await assertFails(getDoc(doc(as("student"), "advisoryResponses/farmer_adv1")));
  // Someone else's id, a forged owner, or extra fields are rejected.
  await assertFails(setDoc(doc(as("student"), "advisoryResponses/farmer_adv2"), { ...ok, userId: "student" }));
  await assertFails(setDoc(doc(as("farmer"), "advisoryResponses/farmer_adv3"), { ...ok, userId: "student" }));
  await assertFails(setDoc(doc(as("farmer"), "advisoryResponses/farmer_adv4"), { ...ok, isAdmin: true }));
});

test("weather stations: registry, providers and keys are admin / server only", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "weatherStations/gw1"), { gatewayId: "gw1", label: "Kamau's farm", providerId: "nuasense" });
    await setDoc(doc(db, "stationProviders/coast"), { name: "Coast", baseUrl: "https://x.example" });
    await setDoc(doc(db, "stationProviderSecrets/coast"), { apiKey: "secret" });
    await setDoc(doc(db, "Admins/boss"), { added: true });
  });
  for (const path of ["weatherStations/gw1", "stationProviders/coast", "stationProviderSecrets/coast"]) {
    await assertFails(getDoc(doc(as("farmer"), path)));
    await assertFails(setDoc(doc(as("farmer"), path), { label: "mine" }));
  }
  await assertFails(setDoc(doc(as("farmer"), "stationAssignments/gw1_farmer"), { gatewayId: "gw1", uid: "farmer", platform: "km" }));
  await assertSucceeds(getDoc(doc(as("boss"), "weatherStations/gw1")));
});

test("station preferences: each farmer picks their own farms' stations, nobody else", async () => {
  const mine = doc(as("farmer"), "stationPreferences/farmer");
  await assertSucceeds(setDoc(mine, { userId: "farmer", plots: { "Plot 1": "gw1" }, updatedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(mine));
  await assertSucceeds(setDoc(mine, { userId: "farmer", plots: { "Plot 2": "gw2" } }, { merge: true }));
  await assertFails(getDoc(doc(as("student"), "stationPreferences/farmer")));
  await assertFails(setDoc(doc(as("student"), "stationPreferences/farmer"), { userId: "student", plots: {} }));
  await assertFails(setDoc(mine, { userId: "farmer", plots: {}, isAdmin: true }));
  await assertFails(setDoc(mine, { userId: "farmer", plots: "gw1" }));
});
