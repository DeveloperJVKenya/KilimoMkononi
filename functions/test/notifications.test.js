// Tests for functions/notifications.js.
//   Unit tests: always run.
//   Trigger tests: need the Firestore emulator (FIRESTORE_EMULATOR_HOST) —
//   run with `npm test` from functions/, which starts it for a demo project.
// FCM is replaced by a recorder, so nothing is ever sent.

const { test, describe, before, beforeEach } = require("node:test");
const assert = require("node:assert/strict");

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-kilimomkononi";
const n = require("../notifications");

// ── Pure logic ───────────────────────────────────────────────────────────────
describe("cropTopic", () => {
  test("matches the Dart slug", () => {
    assert.equal(n.cropTopic("Cabbages/Kales"), "km_crop_cabbages_kales");
    assert.equal(n.cropTopic("Irish Potatoes"), "km_crop_irish_potatoes");
    assert.equal(n.cropTopic(" Maize "), "km_crop_maize");
  });
});

describe("computeWeatherAlerts", () => {
  const calm = { airTemp: 22, humidity: 60, rainfall: 0, windSpeed: 2, windGusts: 4, lwdConsecutiveHours: 0 };
  test("calm weather → no pushes", () => {
    assert.deepEqual(n.computeWeatherAlerts(calm), []);
  });
  test("thresholds and severities", () => {
    const cats = (r) => n.computeWeatherAlerts({ ...calm, ...r }).map((a) => `${a.category}:${a.severity}`);
    assert.deepEqual(cats({ rainfall: 12 }), ["heavy_rain:high"]);
    assert.deepEqual(cats({ rainfall: 30 }), ["heavy_rain:critical"]);
    assert.deepEqual(cats({ windSpeed: 9 }), ["strong_wind:high"]);
    assert.deepEqual(cats({ windGusts: 20 }), ["strong_wind:critical"]);
    assert.deepEqual(cats({ airTemp: 36 }), ["heat:high"]);
    assert.deepEqual(cats({ airTemp: 3 }), ["frost:high"]);
    assert.deepEqual(cats({ lwdConsecutiveHours: 12, humidity: 90 }), ["fungal:high"]);
    assert.deepEqual(cats({ lwdConsecutiveHours: 12, humidity: 70 }), []); // dry air → no fungal push
  });
  test("each alert links to an advisory condition the app knows", () => {
    const all = n.computeWeatherAlerts({ airTemp: 39, humidity: 95, rainfall: 30, windSpeed: 13, windGusts: 20, lwdConsecutiveHours: 20 });
    const known = ["raining", "wet_leaves", "high_humidity", "high_wind", "heat", "cool", "dry_stress", "good_spray", "general"];
    for (const a of all) assert.ok(known.includes(a.advisoryCondition), a.advisoryCondition);
  });
});

describe("shouldSendAlert", () => {
  const now = Date.UTC(2026, 8, 24, 12);
  const hoursAgo = (h) => ({ toMillis: () => now - h * 3600e3 });
  test("dedupes within 6h unless it gets worse", () => {
    assert.equal(n.shouldSendAlert(null, { severity: "high" }, now), true);
    assert.equal(n.shouldSendAlert({ lastSentAt: hoursAgo(2), severity: "high" }, { severity: "high" }, now), false);
    assert.equal(n.shouldSendAlert({ lastSentAt: hoursAgo(2), severity: "high" }, { severity: "critical" }, now), true);
    assert.equal(n.shouldSendAlert({ lastSentAt: hoursAgo(7), severity: "high" }, { severity: "high" }, now), true);
  });
});

describe("advisory pushes", () => {
  test("push only on publish or re-publish", () => {
    assert.equal(n.advisoryPushKind(null, { status: "draft" }), null);
    assert.equal(n.advisoryPushKind({ status: "draft" }, { status: "published", version: 2 }), "new");
    assert.equal(n.advisoryPushKind({ status: "published", version: 2 }, { status: "published", version: 3 }), "updated");
    assert.equal(n.advisoryPushKind({ status: "published", version: 3 }, { status: "published", version: 3 }), null);
    assert.equal(n.advisoryPushKind({ status: "published", version: 3 }, { status: "archived", version: 4 }), null);
  });
  test("audience: test → publisher only; station → station farmers; else crop topics", () => {
    assert.deepEqual(n.advisoryAudience({ testOnly: true, publishedBy: "admin1", crops: ["Maize"] }),
      { type: "users", uids: ["admin1"] });
    assert.deepEqual(n.advisoryAudience({ gatewayId: "gw1", crops: ["Maize"] }), { type: "station", gatewayId: "gw1" });
    assert.deepEqual(n.advisoryAudience({ crops: ["All crops"] }), { type: "topics", topics: ["km_farmers"] });
    assert.deepEqual(n.advisoryAudience({ crops: ["Maize", "Beans"] }),
      { type: "topics", topics: ["km_crop_maize", "km_crop_beans"] });
  });
  test("TEST advisories are clearly labelled", () => {
    const msg = n.advisoryNotification({ testOnly: true, condition: "wet_leaves", crops: ["Maize"], main: "Hold spraying" }, "new");
    assert.match(msg.title, /^TEST · Verified advice · Wet leaves$/);
    assert.equal(msg.body, "Maize: Hold spraying");
  });
  test("topic conditions are chunked at 5 (FCM limit)", () => {
    const c = n.topicConditions(["a", "b", "c", "d", "e", "f"]);
    assert.equal(c.length, 2);
    assert.equal(c[1], "'f' in topics");
  });
});

describe("buildMessage", () => {
  test("uses the app's channel, icon and colour; data values are strings", () => {
    const m = n.buildMessage({ title: "t", body: "b", channel: n.CHANNEL.weather, route: n.ROUTE.weatherStation, data: { x: 1 } });
    assert.equal(m.android.notification.channelId, "km_weather_alerts");
    assert.equal(m.android.notification.icon, "ic_stat_km");
    assert.equal(m.android.priority, "high");
    assert.deepEqual(m.data, { route: "weather_station", channel: "km_weather_alerts", type: "general", x: "1" });
  });
});

// ── Triggers against the Firestore emulator ─────────────────────────────────
const emulator = !!process.env.FIRESTORE_EMULATOR_HOST;

describe("triggers (Firestore emulator)", { skip: !emulator && "FIRESTORE_EMULATOR_HOST not set" }, () => {
  let db, fns, sent;
  const snap = (data) => (data ? { exists: true, data: () => data } : { exists: false, data: () => undefined });

  before(() => {
    const { initializeApp, getApps } = require("firebase-admin/app");
    if (!getApps().length) initializeApp({ projectId: process.env.GCLOUD_PROJECT });
    db = require("firebase-admin/firestore").getFirestore();
    const fakeSecret = { value: () => "test-key" };
    fns = n.createNotificationFunctions({ NUASENSE_KEY: fakeSecret, NUASENSE_BASE: "http://unused", PLATFORM: "km" });
    n.setMessagingForTests({
      sendEachForMulticast: async (m) => {
        sent.push({ kind: "tokens", ...m });
        return {
          successCount: m.tokens.filter((t) => !t.startsWith("dead")).length,
          responses: m.tokens.map((t) => (t.startsWith("dead")
            ? { success: false, error: { code: "messaging/registration-token-not-registered" } }
            : { success: true })),
        };
      },
      send: async (m) => { sent.push({ kind: "condition", ...m }); return "id"; },
    });
  });

  beforeEach(async () => {
    sent = [];
    const cols = ["deviceTokens", "stationAssignments", "EducationUsers", "userNotifications"];
    for (const c of cols) {
      const docs = await db.collection(c).listDocuments();
      await Promise.all(docs.map((d) => db.recursiveDelete(d)));
    }
    await db.doc("deviceTokens/tok-farmer1").set({ uid: "farmer1" });
    await db.doc("deviceTokens/dead-token").set({ uid: "farmer1" });
    await db.doc("deviceTokens/tok-admin").set({ uid: "admin1" });
    await db.doc("stationAssignments/gw1_farmer1").set({ gatewayId: "gw1", uid: "farmer1", platform: "km" });
  });

  const advisoryEvent = (before, after) => ({
    params: { advisoryId: "adv1" },
    data: { before: snap(before), after: snap(after) },
  });

  test("TEST advisory publish → only the admin, with inbox item", async () => {
    await fns.onAdvisoryPublished.run(advisoryEvent({ status: "draft", version: 1 }, {
      status: "published", version: 2, testOnly: true, publishedBy: "admin1",
      condition: "wet_leaves", crops: ["Maize"], main: "Hold spraying",
    }));
    assert.equal(sent.length, 1);
    assert.deepEqual(sent[0].tokens, ["tok-admin"]);
    assert.match(sent[0].notification.title, /^TEST · /);
    const inbox = await db.collection("userNotifications/admin1/items").get();
    assert.equal(inbox.size, 1);
    assert.equal((await db.collection("userNotifications/farmer1/items").get()).size, 0);
  });

  test("station advisory → that station's farmers; dead tokens are cleaned up", async () => {
    await fns.onAdvisoryPublished.run(advisoryEvent(null, {
      status: "published", version: 1, testOnly: false, gatewayId: "gw1",
      condition: "high_wind", crops: ["Beans"], main: "Delay spraying",
    }));
    assert.equal(sent.length, 1);
    assert.deepEqual(sent[0].tokens.sort(), ["dead-token", "tok-farmer1"]);
    assert.equal((await db.doc("deviceTokens/dead-token").get()).exists, false);
    assert.equal((await db.collection("userNotifications/farmer1/items").get()).size, 1);
  });

  test("crop advisory → crop topics, no per-user inbox", async () => {
    await fns.onAdvisoryPublished.run(advisoryEvent(null, {
      status: "published", version: 1, testOnly: false, gatewayId: null,
      condition: "heat", crops: ["Maize", "Tomatoes"], main: "Irrigate early",
    }));
    assert.equal(sent.length, 1);
    assert.equal(sent[0].condition, "'km_crop_maize' in topics || 'km_crop_tomatoes' in topics");
    assert.equal(sent[0].android.notification.channelId, "km_advisories");
  });

  test("draft saves and archives don't push", async () => {
    await fns.onAdvisoryPublished.run(advisoryEvent(null, { status: "draft", version: 1 }));
    await fns.onAdvisoryPublished.run(advisoryEvent({ status: "published", version: 2 }, { status: "archived", version: 3 }));
    assert.equal(sent.length, 0);
  });

  test("education sign-up → approvers of the right role and school; decision → applicant", async () => {
    await db.doc("EducationUsers/t1").set({ role: "teacher", approvalStatus: "approved", schoolName: "St Marys", classIds: ["St_Marys_senior_10"] });
    await db.doc("EducationUsers/t2").set({ role: "teacher", approvalStatus: "approved", schoolName: "Greenwood", classIds: [] });
    await db.doc("deviceTokens/tok-t1").set({ uid: "t1" });
    await db.doc("deviceTokens/tok-t2").set({ uid: "t2" });
    await db.doc("deviceTokens/tok-s1").set({ uid: "s1" });

    const applicant = { fullName: "Amina", requestedRole: "student", approvalStatus: "pending", schoolName: "St Marys", currentClassId: "St_Marys_senior_10" };
    await fns.onEducationSignup.run({ params: { uid: "s1" }, data: snap(applicant) });
    assert.deepEqual(sent.map((s) => s.tokens).flat(), ["tok-t1"]);
    assert.equal(sent[0].android.notification.channelId, "km_approvals");

    sent = [];
    await fns.onEducationDecision.run({
      params: { uid: "s1" },
      data: { before: snap(applicant), after: snap({ ...applicant, approvalStatus: "approved", role: "student" }) },
    });
    assert.deepEqual(sent[0].tokens, ["tok-s1"]);
    assert.equal(sent[0].notification.title, "Your account is approved");
  });
});
