// Tests for functions/agronomist.js.
//   Unit tests: always run.
//   Trigger tests: need the Firestore emulator (FIRESTORE_EMULATOR_HOST) —
//   run with `npm test` from functions/. FCM is replaced by a recorder.

const { test, describe, before, beforeEach } = require("node:test");
const assert = require("node:assert/strict");

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-kilimomkononi";
const a = require("../agronomist");
const n = require("../notifications");

const T = (ms) => ({ toMillis: () => ms });

// ── Pure logic ───────────────────────────────────────────────────────────────
describe("confidenceLevel / isUnidentified", () => {
  test("words, 0–1 and 0–100 scores", () => {
    assert.equal(a.confidenceLevel("High"), "high");
    assert.equal(a.confidenceLevel(0.8), "high");
    assert.equal(a.confidenceLevel(55), "medium");
    assert.equal(a.confidenceLevel("30%"), "low");
    assert.equal(a.confidenceLevel(null), null);
  });
  test("unknown names and low-confidence photo IDs are unidentified", () => {
    assert.equal(a.isUnidentified("", null), true);
    assert.equal(a.isUnidentified("Unknown pest", null), true);
    assert.equal(a.isUnidentified("Not sure", null), true);
    assert.equal(a.isUnidentified("Fall armyworm", "low"), true);
    assert.equal(a.isUnidentified("Fall armyworm", "high"), false);
  });
});

describe("issueRow / dedupeIssues", () => {
  test("normalises all four collections; skips deleted records", () => {
    const issue = a.issueRow("issues", {
      issueType: "pest", issueName: " Fall  armyworm ", cropName: "Maize", cropStage: "Vegetative",
      timestamp: T(1000), source: "aiPhoto", aiConfidence: "medium", photoUrl: "x",
    });
    assert.equal(issue.name, "Fall armyworm");
    assert.equal(issue.src, "photo");
    assert.equal(issue.conf, "medium");
    assert.equal(issue.unidentified, false);
    assert.equal(a.issueRow("pests", { pestName: "Aphids", cropType: "Kales", timestamp: T(5) }).legacy, true);
    assert.equal(a.issueRow("diseases", { diseaseName: "Late blight", timestamp: T(5) }).type, "disease");
    assert.equal(a.issueRow("diagnoses", { selectedName: "Rust", issueType: "disease", createdAt: T(9), confidence: 0.3 }).unidentified, true);
    assert.equal(a.issueRow("issues", { issueName: "X", timestamp: T(1), isDeleted: true }), null);
    assert.equal(a.issueRow("issues", { issueName: "X" }), null); // no time
  });

  test("the legacy copy of a record saved twice is dropped; separate reports stay", () => {
    const rows = [
      { f: "u1", type: "pest", name: "Aphids", at: 1000, legacy: false },
      { f: "u1", type: "pest", name: "aphids", at: 1000 + 30_000, legacy: true }, // same save
      { f: "u1", type: "pest", name: "Aphids", at: 1000 + 10 * 60_000, legacy: true }, // later report
      { f: "u2", type: "pest", name: "Aphids", at: 1000, legacy: true }, // other farmer
    ];
    const out = a.dedupeIssues(rows);
    assert.equal(out.length, 3);
    assert.ok(!out.some((r) => r.f === "u1" && r.at === 31000));
  });
});

describe("plotRow / activities", () => {
  test("plot row keeps crops, soil test and saved bands", () => {
    const r = a.plotRow({
      plotId: "Plot A", crops: [{ type: "Maize", stage: "Vegetative" }, { type: "" }],
      npk: { N: 20, P: null, K: "x" }, nutrientBands: { N: "low", P: "weird" }, area: 2, timestamp: T(7),
    });
    assert.deepEqual(r.crops, [{ type: "Maize", stage: "Vegetative" }]);
    assert.deepEqual(r.npk, { N: 20 });
    assert.deepEqual(r.bands, { N: "low" });
    assert.equal(r.at, 7);
  });

  test("new field record: notable only when a nutrient is low", () => {
    const low = a.activityFromFieldData("d1", null, {
      userId: "u1", plotId: "Plot A", crops: [{ type: "Maize" }], nutrientBands: { N: "low", K: "low", P: "high" },
    });
    assert.equal(low.notable, true);
    assert.deepEqual(low.flags, ["low_N", "low_K"]);
    assert.match(low.title, /low in N, K/);
    const ok = a.activityFromFieldData("d2", null, { userId: "u1", plotId: "Plot A", crops: [] });
    assert.equal(ok.notable, false);
  });

  test("interventions added to a record → soil action; other edits → nothing", () => {
    const before = { userId: "u1", plotId: "P", interventions: [{}] };
    const act = a.activityFromFieldData("d1", before, { ...before, interventions: [{}, { type: "Top-dressing" }] });
    assert.equal(act.kind, "soil_action");
    assert.equal(act.id, "fd_d1_i2");
    assert.equal(a.activityFromFieldData("d1", before, { ...before, area: 3 }), null);
  });

  test("pest record activity: one id for the same save in two collections", () => {
    const row = a.issueRow("issues", { issueType: "pest", issueName: "Aphids", cropName: "Kales", timestamp: T(42) });
    const legacy = a.issueRow("pests", { pestName: "Aphids", cropType: "Kales", timestamp: T(42) });
    assert.equal(a.activityFromIssue("u1", row).id, a.activityFromIssue("u1", legacy).id);
    assert.equal(a.activityFromIssue("u1", row).notable, true);
    const unknown = a.activityFromIssue("u1", a.issueRow("issues", { issueName: "unknown", timestamp: T(1) }));
    assert.ok(unknown.flags.includes("unidentified"));
    assert.match(unknown.title, /unidentified pest problem/);
  });

  test("advice responses: only newly found / logged items count", () => {
    const acts = a.newResponseActions(
      { items: { "pests:Aphids": "found" } },
      { items: { "pests:Aphids": "found", "diseases:Late blight": "found", "soil:N@Plot A": "logged:low", "pests:Mites": "not_found" } }
    );
    assert.deepEqual(acts.map((x) => x.name), ["Late blight", "N"]);
    const act = a.activityFromResponse("r1", { userId: "u1", advisoryId: "fa1" }, acts, { direct: true, main: "Spray" });
    assert.equal(act.notable, true);
    assert.match(act.title, /your advice: found Late blight; logged N/);
  });
});

describe("notifications", () => {
  test("activity push: named farmer, place, opens their records", () => {
    const m = a.activityNotification({
      farmerUid: "u1", farmerName: "Jane", county: "Nakuru", ward: "Njoro",
      title: "reported Aphids on Kales", detail: "Stage: Vegetative", flags: [], notable: true, kind: "pest", id: "x",
    });
    assert.equal(m.title, "Jane reported Aphids on Kales");
    assert.match(m.body, /^Njoro, Nakuru/);
    assert.equal(m.route, n.ROUTE.agronomistFarmer);
    assert.equal(m.channel, n.CHANNEL.farmerActivity);
    assert.equal(n.collapseKeyFor(m), "farm_u1");
  });

  test("at most one push per farmer per hour", () => {
    assert.equal(a.shouldPushFarmer(null, 0), true);
    assert.equal(a.shouldPushFarmer({ lastPushAt: T(1000) }, 1000 + 30 * 60_000), false);
    assert.equal(a.shouldPushFarmer({ lastPushAt: T(1000) }, 1000 + 61 * 60_000), true);
  });

  test("daily digest summarises the day", () => {
    assert.equal(a.digestSummary([]), null);
    const d = a.digestSummary([
      { farmerUid: "u1", kind: "pest", issueName: "Aphids", flags: [] },
      { farmerUid: "u2", kind: "pest", issueName: "Aphids", flags: [] },
      { farmerUid: "u2", kind: "disease", issueName: "", flags: ["unidentified"] },
      { farmerUid: "u3", kind: "field_record", flags: ["low_N"] },
    ]);
    assert.match(d.title, /4 entries from 3 farmers/);
    assert.match(d.body, /2 pest reports \(Aphids ×2\)/);
    assert.match(d.body, /1 unidentified problem/);
    assert.match(d.body, /1 plot low in nutrients/);
    assert.equal(d.type, "farmer_digest");
  });

  test("custom advice: pushed when sent, and on updates only when re-notified", () => {
    assert.equal(a.adviceSendKind(null, { status: "draft" }), null);
    assert.equal(a.adviceSendKind({ status: "draft", version: 1 }, { status: "sent", version: 2 }), "new");
    assert.equal(a.adviceSendKind({ status: "sent", version: 2, notifyVersion: 2 },
      { status: "sent", version: 3, notifyVersion: 2 }), null);
    assert.equal(a.adviceSendKind({ status: "sent", version: 2, notifyVersion: 2 },
      { status: "sent", version: 3, notifyVersion: 3 }), "updated");
    const m = a.farmerAdviceNotification({
      __id: "fa1", sentByName: "Dr Otieno", title: "Your maize", main: "Top-dress with CAN",
      crops: ["Maize"], soilActions: [{ nutrient: "N" }],
    }, "new");
    assert.equal(m.title, "Advice for you from Dr Otieno");
    assert.equal(m.route, n.ROUTE.advisory);
    assert.equal(m.data.direct, "true");
    assert.equal(m.data.sections, "soil");
    assert.equal(n.wantsPush({ advisories: false }, m.type), false);
  });

  test("farmer-activity pushes follow their own switch", () => {
    assert.equal(n.wantsPush({ farmerActivity: false }, "farmer_activity"), false);
    assert.equal(n.wantsPush({ farmerActivity: false }, "farmer_digest"), false);
    assert.equal(n.wantsPush({ farmerActivity: true }, "farmer_activity"), true);
  });
});

// ── Triggers against the Firestore emulator ─────────────────────────────────
const emulator = !!process.env.FIRESTORE_EMULATOR_HOST;

describe("agronomist triggers (Firestore emulator)", { skip: !emulator && "FIRESTORE_EMULATOR_HOST not set" }, () => {
  let db, fns, sent;
  const snap = (data) => (data ? { exists: true, data: () => data } : { exists: false, data: () => undefined });
  const created = (params, data) => ({ params, data: { data: () => data } });
  const written = (params, before, after) => ({ params, data: { before: snap(before), after: snap(after) } });

  before(() => {
    const { initializeApp, getApps } = require("firebase-admin/app");
    if (!getApps().length) initializeApp({ projectId: process.env.GCLOUD_PROJECT });
    db = require("firebase-admin/firestore").getFirestore();
    fns = a.createAgronomistFunctions({ isPlatformAdmin: async (auth) => auth?.uid === "admin1" });
    n.setMessagingForTests({
      sendEachForMulticast: async (m) => {
        sent.push(m);
        return { successCount: m.tokens.length, responses: m.tokens.map(() => ({ success: true })) };
      },
      send: async () => "id",
    });
  });

  beforeEach(async () => {
    sent = [];
    for (const c of ["deviceTokens", "userNotifications", "farmerActivity", "agronomistPushState",
      "Agronomists", "Users", "privacySettings", "farmer_advice", "agronomistAccessLog",
      "farmer_issues", "fielddata", "notificationPrefs"]) {
      const docs = await db.collection(c).listDocuments();
      await Promise.all(docs.map((d) => db.recursiveDelete(d)));
    }
    await db.doc("Agronomists/agro1").set({ added: true });
    await db.doc("deviceTokens/tok-agro").set({ uid: "agro1" });
    await db.doc("deviceTokens/tok-farmer").set({ uid: "farmer1" });
    await db.doc("Users/farmer1").set({ fullName: "Jane Wanjiku", county: "Nakuru", ward: "Njoro" });
    await db.doc("Users/farmer2").set({ fullName: "Hidden", county: "Kisii" });
    await db.doc("privacySettings/farmer2").set({ shareWithAgronomists: false });
  });

  const pest = (name, ms) => ({ issueType: "pest", issueName: name, cropName: "Maize", timestamp: require("firebase-admin/firestore").Timestamp.fromMillis(ms) });

  test("a pest report → feed entry, inbox and one push; the legacy copy adds nothing", async () => {
    await fns.onFarmerIssueRecord.run(created({ uid: "farmer1", id: "r1" }, pest("Fall armyworm", 1000)));
    await fns.onPestRecord.run(created({ id: "p1" }, { pestName: "Fall armyworm", cropType: "Maize", userId: "farmer1", timestamp: pest("x", 1000).timestamp }));
    assert.equal((await db.collection("farmerActivity").get()).size, 1);
    assert.equal((await db.collection("userNotifications/agro1/items").get()).size, 1);
    assert.equal(sent.length, 1);
    assert.equal(sent[0].notification.title, "Jane Wanjiku reported Fall armyworm on Maize");
  });

  test("second notable entry within the hour → inbox only", async () => {
    await fns.onFarmerIssueRecord.run(created({ uid: "farmer1", id: "r1" }, pest("Aphids", 1000)));
    await fns.onFarmerIssueRecord.run(created({ uid: "farmer1", id: "r2" }, pest("Thrips", 2000)));
    assert.equal((await db.collection("userNotifications/agro1/items").get()).size, 2);
    assert.equal(sent.length, 1);
  });

  test("farmers who don't share are invisible to the feed and notifications", async () => {
    await fns.onFarmerIssueRecord.run(created({ uid: "farmer2", id: "r1" }, pest("Aphids", 1000)));
    assert.equal((await db.collection("farmerActivity").get()).size, 0);
    assert.equal(sent.length, 0);
  });

  test("custom advice reaches only its farmer; TEST advice only the admin", async () => {
    const advice = { farmerUid: "farmer1", status: "sent", version: 1, sentBy: "agro1", sentByName: "Agro", main: "Scout", crops: ["Maize"] };
    await fns.onFarmerAdviceSent.run(written({ id: "fa1" }, null, advice));
    assert.equal(sent.length, 1);
    assert.deepEqual(sent[0].tokens, ["tok-farmer"]);
    assert.equal((await db.collection("userNotifications/farmer1/items").get()).size, 1);

    sent = [];
    await db.doc("deviceTokens/tok-admin").set({ uid: "admin1" });
    await fns.onFarmerAdviceSent.run(written({ id: "fa2" }, null, { ...advice, testOnly: true, sentBy: "admin1" }));
    assert.deepEqual(sent[0].tokens, ["tok-admin"]);
    assert.match(sent[0].notification.title, /^TEST · /);
  });

  test("insights hide farmers who don't share; farmer records are refused for them and logged otherwise", async () => {
    const { Timestamp } = require("firebase-admin/firestore");
    const now = Date.now();
    await db.doc("farmer_issues/farmer1/records/r1").set(pest("Aphids", now - 1000));
    await db.doc("farmer_issues/farmer2/records/r1").set({ ...pest("Aphids", now - 1000) });
    await db.doc("fielddata/f1").set({ userId: "farmer1", plotId: "A", crops: [{ type: "Maize" }], npk: { N: 10 }, timestamp: Timestamp.fromMillis(now) });
    const out = await a.loadInsights(7, now + 10 * 60 * 1000);
    assert.equal(out.issues.length, 2);
    assert.ok(out.issues.some((r) => r.f === "farmer1"));
    assert.ok(out.issues.some((r) => r.f === null && r.county === "Kisii"));
    assert.deepEqual(out.farmers.map((f) => f.uid), ["farmer1"]);
    assert.equal(out.totals.optedOut, 1);

    const call = (uid, data) => fns.agronomistData.run({ auth: uid ? { uid, token: {} } : null, data });
    await assert.rejects(call("farmer1", { action: "insights" }), /permission-denied|Only Field Agronomists/);
    await assert.rejects(call("agro1", { action: "farmer", farmerUid: "farmer2" }), /chosen not to share/);
    const rec = await call("agro1", { action: "farmer", farmerUid: "farmer1" });
    assert.equal(rec.profile.name, "Jane Wanjiku");
    assert.equal(rec.issues.length, 1);
    assert.equal((await db.collection("agronomistAccessLog").get()).size, 1);
  });
});
