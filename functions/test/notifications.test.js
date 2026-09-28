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
  test("each alert links to advisory conditions the app knows", () => {
    const hot = n.computeWeatherAlerts({ airTemp: 39, humidity: 95, rainfall: 30, windSpeed: 13, windGusts: 20, lwdConsecutiveHours: 20 });
    const cold = n.computeWeatherAlerts({ ...calm, airTemp: 1 });
    const known = Object.keys(n.CONDITION_LABELS);
    for (const a of [...hot, ...cold]) {
      assert.ok(a.advisoryConditions.length > 0);
      for (const c of a.advisoryConditions) assert.ok(known.includes(c), c);
    }
  });
  test("frost alerts prefer frost advice, then cool", () => {
    assert.deepEqual(n.computeWeatherAlerts({ ...calm, airTemp: 1 })[0].advisoryConditions, ["frost", "cool"]);
  });
});

describe("parseReading / activeConditions", () => {
  const weather = (pts) => ({ series: [
    { id: "air_temperature", data: pts.map((y) => ({ x: "2026-09-24T10:00:00Z", y })) },
    { id: "humidity", data: pts.map(() => ({ x: "2026-09-24T10:00:00Z", y: 85 })) },
  ] });
  test("offline station (no points) → no data, only general", () => {
    const r = n.parseReading(weather([]), { points: [] });
    assert.equal(r.hasData, false);
    assert.equal(r.timestamp, null);
    assert.deepEqual([...n.activeConditions(r)], ["general"]);
  });
  test("live reading → matching conditions (same rules as the app)", () => {
    const r = n.parseReading(weather([3]), { points: [{ lwd_hour: 1, vpd: 0.2, spray_quality_index: 20, spray_quality_label: "Poor" }] });
    assert.equal(r.hasData, true);
    const keys = n.activeConditions(r);
    for (const k of ["general", "cool", "frost", "high_humidity", "wet_leaves"]) assert.ok(keys.has(k), k);
    assert.ok(!keys.has("good_spray"));
    assert.ok(!keys.has("dry_stress"));
  });
  test("spray window falls back to calm wind when there's no spray score", () => {
    const base = { hasData: true, airTemp: 22, humidity: 60, rainfall: 0, windSpeed: 1, lwdHour: 0, lwdConsecutiveHours: 0, vpd: 1, sprayQualityIndex: 0, sprayQualityLabel: "" };
    assert.ok(n.activeConditions(base).has("good_spray"));
    assert.ok(!n.activeConditions({ ...base, rainfall: 2 }).has("good_spray"));
  });
});

describe("crop matching and ranking", () => {
  test("cropsMatch mirrors the app; unknown crops only get All crops advice", () => {
    assert.equal(n.cropsMatch(["All crops"], ["Maize"]), true);
    assert.equal(n.cropsMatch(["Tomatoes"], []), true);
    assert.equal(n.cropsMatch(["Tomatoes"], ["maize"]), false);
    assert.equal(n.cropsMatch(["Irish Potatoes"], [" irish potatoes "]), true);
    assert.equal(n.cropsMatch(["Tomatoes"], null), false);
    assert.equal(n.cropsMatch(["All crops"], null), true);
  });
  test("best advice: this station first, then specific condition, then newest", () => {
    const list = [
      { __id: "old-all", condition: "raining", crops: ["Maize"], publishedAt: 1 },
      { __id: "new-all", condition: "raining", crops: ["Maize"], publishedAt: 5 },
      { __id: "station", condition: "raining", crops: ["Maize"], gatewayId: "gw1", publishedAt: 2 },
      { __id: "other-station", condition: "raining", crops: ["Maize"], gatewayId: "gw2", publishedAt: 9 },
      { __id: "tomato", condition: "raining", crops: ["Tomatoes"], gatewayId: "gw1", publishedAt: 9 },
    ];
    assert.equal(n.bestAdvisoryFor(list, ["Maize"], "gw1").__id, "station");
    assert.equal(n.bestAdvisoryFor(list, ["Maize"], "gw3").__id, "new-all");
    assert.equal(n.bestAdvisoryFor(list, ["Beans"], "gw1"), null);
  });
  test("condition advice repeats at most daily, or when re-notified", () => {
    const now = Date.UTC(2026, 8, 24, 12);
    const a = { version: 3, notifyVersion: 2 };
    assert.equal(n.shouldDeliverAdvisory(null, a, now), true);
    assert.equal(n.shouldDeliverAdvisory({ notifyVersion: 2, lastSentAt: now - 3600e3 }, a, now), false);
    assert.equal(n.shouldDeliverAdvisory({ notifyVersion: 2, lastSentAt: now - 25 * 3600e3 }, a, now), true);
    assert.equal(n.shouldDeliverAdvisory({ notifyVersion: 1, lastSentAt: now - 3600e3 }, a, now), true);
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
  test("push on publish; updates only when the agronomist asked to notify", () => {
    assert.equal(n.advisoryPushKind(null, { status: "draft" }), null);
    assert.equal(n.advisoryPushKind({ status: "draft" }, { status: "published", version: 2 }), "new");
    // edit without "notify farmers" — notifyVersion unchanged
    assert.equal(n.advisoryPushKind({ status: "published", version: 2, notifyVersion: 2 },
      { status: "published", version: 3, notifyVersion: 2 }), null);
    assert.equal(n.advisoryPushKind({ status: "published", version: 2 }, { status: "published", version: 3 }), null);
    // edit with "notify farmers"
    assert.equal(n.advisoryPushKind({ status: "published", version: 2, notifyVersion: 2 },
      { status: "published", version: 3, notifyVersion: 3 }), "updated");
    assert.equal(n.advisoryPushKind({ status: "published", version: 3 }, { status: "published", version: 3 }), null);
    assert.equal(n.advisoryPushKind({ status: "published", version: 3 }, { status: "archived", version: 4 }), null);
  });
  test("only 'Any conditions' (or admin TEST) advice is pushed at publish time", () => {
    assert.equal(n.pushesAtPublish({ condition: "general" }), true);
    assert.equal(n.pushesAtPublish({ condition: "raining" }), false);
    assert.equal(n.pushesAtPublish({ condition: "raining", testOnly: true }), true);
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
  test("station advice carries the station, so a tap opens it", () => {
    const msg = n.advisoryNotification({ __id: "a1", condition: "raining", crops: ["Maize"], main: "x" }, "condition", "gw1");
    assert.deepEqual(msg.data, { advisoryId: "a1", testOnly: "false", gatewayId: "gw1" });
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

describe("delivery rules: expiry, collapsing, web links", () => {
  const now = Date.UTC(2026, 8, 24, 12);
  test("weather alerts expire in 6h and replace the previous alert of the same kind", () => {
    const m = n.buildMessage({ title: "t", body: "b", channel: n.CHANNEL.weather, route: n.ROUTE.weatherStation,
      type: "weather_alert", data: { category: "heavy_rain", gatewayId: "gw1" } }, now);
    assert.equal(m.android.ttl, 6 * 3600 * 1000);
    assert.equal(m.android.collapseKey, "wx_gw1_heavy_rain");
    assert.equal(m.android.notification.tag, "wx_gw1_heavy_rain");
    assert.equal(m.apns.headers["apns-expiration"], String(now / 1000 + 6 * 3600));
    assert.equal(m.apns.headers["apns-collapse-id"], "wx_gw1_heavy_rain");
    assert.equal(m.webpush.headers.TTL, String(6 * 3600));
    assert.equal(m.webpush.headers.Urgency, "high");
    assert.ok(m.webpush.headers.Topic.length <= 32);
  });
  test("approvals keep for a week and never collapse", () => {
    const m = n.buildMessage({ title: "t", body: "b", channel: n.CHANNEL.approvals, route: n.ROUTE.eduHome, type: "approval_decision" }, now);
    assert.equal(m.android.ttl, 7 * 86400 * 1000);
    assert.equal(m.android.collapseKey, undefined);
    assert.equal(m.webpush.headers.Topic, undefined);
  });
  test("web pushes open the web app on the right screen", () => {
    const m = n.buildMessage({ title: "t", body: "b", channel: n.CHANNEL.advisories, route: n.ROUTE.weatherStation,
      type: "advisory", data: { advisoryId: "a1", gatewayId: "gw1" } }, now);
    const url = new URL(m.webpush.fcmOptions.link);
    assert.equal(url.protocol, "https:");
    assert.equal(url.searchParams.get("km_route"), "weather_station");
    assert.equal(url.searchParams.get("gatewayId"), "gw1");
    assert.equal(m.android.collapseKey, "adv_a1");
  });
});

describe("notification settings", () => {
  test("master switch and per-type switches; missing prefs = everything on", () => {
    assert.equal(n.wantsPush(null, "weather_alert"), true);
    assert.equal(n.wantsPush({ push: false }, "general"), false);
    assert.equal(n.wantsPush({ weatherAlerts: false }, "weather_alert"), false);
    assert.equal(n.wantsPush({ weatherAlerts: false }, "advisory"), true);
    assert.equal(n.wantsPush({ advisories: false }, "advisory"), false);
    assert.equal(n.wantsPush({ approvals: false }, "approval_request"), false);
    assert.equal(n.wantsPush({ approvals: false }, "approval_decision"), false);
    assert.equal(n.wantsPush({ approvals: false }, "general"), true);
  });
});

describe("web topics", () => {
  test("diff and validation", () => {
    assert.deepEqual(n.topicDiff(["km_farmers", "km_crop_maize"], ["km_farmers", "km_crop_beans"]),
      { add: ["km_crop_beans"], remove: ["km_crop_maize"] });
    const token = "t".repeat(40);
    assert.deepEqual(n.validateWebTopics({ token, topics: ["km_farmers", "km_crop_irish_potatoes"] }).topics,
      ["km_farmers", "km_crop_irish_potatoes"]);
    assert.throws(() => n.validateWebTopics({ token, topics: ["news"] }));
    assert.throws(() => n.validateWebTopics({ token: "short", topics: [] }));
    assert.throws(() => n.validateWebTopics({ token: token + "/x", topics: [] }));
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
      subscribeToTopic: async (tokens, topic) => { sent.push({ kind: "sub", tokens, topic }); },
      unsubscribeFromTopic: async (tokens, topic) => { sent.push({ kind: "unsub", tokens, topic }); },
    });
  });

  beforeEach(async () => {
    sent = [];
    const cols = ["deviceTokens", "stationAssignments", "EducationUsers", "userNotifications",
      "fielddata", "agronomic_advisories", "advisoryDelivery", "alertState", "webTopicState",
      "notificationPrefs"];
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

  test("station advisory → that station's farmers who grow the crop; dead tokens are cleaned up", async () => {
    // farmer2 is on the same station but grows only tomatoes.
    await db.doc("stationAssignments/gw1_farmer2").set({ gatewayId: "gw1", uid: "farmer2", platform: "km" });
    await db.doc("deviceTokens/tok-farmer2").set({ uid: "farmer2" });
    await db.doc("fielddata/f2").set({ userId: "farmer2", timestamp: new Date(), crops: [{ type: "Tomatoes" }] });

    await fns.onAdvisoryPublished.run(advisoryEvent(null, {
      status: "published", version: 1, testOnly: false, gatewayId: "gw1",
      condition: "general", crops: ["Beans"], main: "Delay spraying",
    }));
    assert.equal(sent.length, 1);
    assert.deepEqual(sent[0].tokens.sort(), ["dead-token", "tok-farmer1"]);
    assert.equal(sent[0].data.gatewayId, "gw1");
    assert.equal((await db.doc("deviceTokens/dead-token").get()).exists, false);
    assert.equal((await db.collection("userNotifications/farmer1/items").get()).size, 1);
    assert.equal((await db.collection("userNotifications/farmer2/items").get()).size, 0);
  });

  test("condition advice isn't pushed at publish time (the sweep delivers it)", async () => {
    await fns.onAdvisoryPublished.run(advisoryEvent(null, {
      status: "published", version: 1, testOnly: false, gatewayId: "gw1",
      condition: "high_wind", crops: ["Beans"], main: "Delay spraying",
    }));
    assert.equal(sent.length, 0);
  });

  test("updates re-notify only when notifyVersion moves", async () => {
    const base = { status: "published", testOnly: false, gatewayId: null, condition: "general", crops: ["All crops"], main: "x" };
    await fns.onAdvisoryPublished.run(advisoryEvent({ ...base, version: 1, notifyVersion: 1 }, { ...base, version: 2, notifyVersion: 1 }));
    assert.equal(sent.length, 0);
    await fns.onAdvisoryPublished.run(advisoryEvent({ ...base, version: 2, notifyVersion: 1 }, { ...base, version: 3, notifyVersion: 3 }));
    assert.equal(sent.length, 1);
    assert.match(sent[0].notification.title, /^Updated verified advice/);
    assert.equal(sent[0].condition, "'km_farmers' in topics");
  });

  test("crop advisory → crop topics, no per-user inbox", async () => {
    await fns.onAdvisoryPublished.run(advisoryEvent(null, {
      status: "published", version: 1, testOnly: false, gatewayId: null,
      condition: "general", crops: ["Maize", "Tomatoes"], main: "Irrigate early",
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

  // ── Hourly sweep ────────────────────────────────────────────────────────
  const NOW = Date.UTC(2026, 8, 24, 12);
  const liveReading = (over = {}) => ({
    hasData: true, timestamp: new Date(NOW - 20 * 60e3),
    airTemp: 22, humidity: 60, rainfall: 0, windSpeed: 2, windGusts: 4,
    lwdHour: 0, lwdConsecutiveHours: 0, vpd: 1, sprayQualityIndex: 30, sprayQualityLabel: "Poor",
    ...over,
  });
  const publish = (id, data) => db.doc(`agronomic_advisories/${id}`).set({
    status: "published", testOnly: false, version: 1, notifyVersion: 1,
    gatewayId: null, publishedAt: new Date(NOW - 86400e3), ...data,
  });
  const sweep = (reading) => n.createWeatherSweep({ PLATFORM: "km", fetchReading: async () => reading });
  const tokensOf = (m) => (m.tokens || []).filter((t) => !t.startsWith("dead")).sort();

  async function twoFarmers() {
    // farmer1 grows maize, farmer2 tomatoes — both on gw1.
    await db.doc("deviceTokens/dead-token").delete();
    await db.doc("stationAssignments/gw1_farmer2").set({ gatewayId: "gw1", uid: "farmer2", platform: "km" });
    await db.doc("deviceTokens/tok-farmer2").set({ uid: "farmer2" });
    await db.doc("fielddata/f1").set({ userId: "farmer1", timestamp: new Date(), crops: [{ type: "Maize" }] });
    await db.doc("fielddata/f2").set({ userId: "farmer2", timestamp: new Date(), crops: [{ type: "Tomatoes" }] });
  }

  test("sweep: each farmer's alert carries the advice for their own crop", async () => {
    await twoFarmers();
    await publish("rain-maize", { condition: "raining", crops: ["Maize"], main: "Open maize drainage" });
    await publish("rain-tomato", { condition: "raining", crops: ["Tomatoes"], main: "Stake tomatoes" });

    await sweep(liveReading({ rainfall: 12 }))(NOW);
    const alerts = sent.filter((m) => m.data.type === "weather_alert");
    assert.equal(alerts.length, 2);
    const forF1 = alerts.find((m) => tokensOf(m).includes("tok-farmer1"));
    const forF2 = alerts.find((m) => tokensOf(m).includes("tok-farmer2"));
    assert.match(forF1.notification.body, /Verified advice: Open maize drainage/);
    assert.match(forF2.notification.body, /Verified advice: Stake tomatoes/);
    assert.equal(forF1.data.gatewayId, "gw1");
    // The advice came with the alert — no separate advisory push for it.
    assert.equal(sent.filter((m) => m.data.type === "advisory").length, 0);
  });

  test("sweep: condition advice is delivered when it occurs, to matching crops, not repeated", async () => {
    await twoFarmers();
    await publish("humid-maize", { condition: "high_humidity", crops: ["Maize"], main: "Scout maize for rust" });
    await publish("cool-any", { condition: "cool", crops: ["All crops"], main: "Delay planting" });

    // Warm, humid (no alerts): only the humidity advice applies, only to farmer1.
    await sweep(liveReading({ humidity: 85 }))(NOW);
    assert.equal(sent.length, 1);
    assert.equal(sent[0].data.type, "advisory");
    assert.equal(sent[0].data.advisoryId, "humid-maize");
    assert.deepEqual(tokensOf(sent[0]), ["tok-farmer1"]);
    assert.equal((await db.collection("userNotifications/farmer1/items").get()).size, 1);

    // An hour later, still humid → nothing new.
    sent = [];
    await sweep(liveReading({ humidity: 85, timestamp: new Date(NOW + 3600e3 - 60e3) }))(NOW + 3600e3);
    assert.equal(sent.length, 0);

    // After a day it's sent again; re-notified versions go straight out.
    await sweep(liveReading({ humidity: 85, timestamp: new Date(NOW + 25 * 3600e3 - 60e3) }))(NOW + 25 * 3600e3);
    assert.equal(sent.length, 1);
    sent = [];
    await db.doc("agronomic_advisories/humid-maize").update({ version: 2, notifyVersion: 2 });
    await sweep(liveReading({ humidity: 85, timestamp: new Date(NOW + 26 * 3600e3 - 60e3) }))(NOW + 26 * 3600e3);
    assert.equal(sent.length, 1);
    sent = [];
    // A version bump WITHOUT notify doesn't.
    await db.doc("agronomic_advisories/humid-maize").update({ version: 3 });
    await sweep(liveReading({ humidity: 85, timestamp: new Date(NOW + 27 * 3600e3 - 60e3) }))(NOW + 27 * 3600e3);
    assert.equal(sent.length, 0);
  });

  test("sweep: an offline or stale station sends nothing", async () => {
    await twoFarmers();
    await publish("cool-any", { condition: "cool", crops: ["All crops"], main: "Delay planting" });
    await sweep(liveReading({ hasData: false, airTemp: 0, humidity: 0 }))(NOW);
    await sweep(liveReading({ airTemp: 1, timestamp: new Date(NOW - 4 * 3600e3) }))(NOW);
    assert.equal(sent.length, 0);
  });

  test("sweep: station-scoped advice beats all-station advice; TEST advice never goes out", async () => {
    await twoFarmers();
    await publish("wind-all", { condition: "high_wind", crops: ["All crops"], main: "General wind advice", publishedAt: new Date(NOW - 1000) });
    await publish("wind-gw1", { condition: "high_wind", crops: ["All crops"], main: "gw1 wind advice", gatewayId: "gw1" });
    await publish("wind-test", { condition: "high_wind", crops: ["All crops"], main: "TEST", testOnly: true, gatewayId: "gw1" });
    await sweep(liveReading({ windSpeed: 9 }))(NOW);
    const alerts = sent.filter((m) => m.data.type === "weather_alert");
    assert.equal(alerts.length, 1);
    assert.match(alerts[0].notification.body, /Verified advice: gw1 wind advice/);
    // The alert covered "windy" — no second wind push in the same run.
    assert.equal(sent.length, 1);
    assert.ok(!sent.some((m) => /TEST/.test(m.notification.body)));
  });

  test("settings: pushes skip users who turned them off, but the inbox keeps the record", async () => {
    await db.doc("notificationPrefs/farmer1").set({ push: true, weatherAlerts: false });
    await n.deliverToUsers(["farmer1", "admin1"], {
      title: "Heavy rain", body: "b", channel: n.CHANNEL.weather, type: "weather_alert",
      data: { category: "heavy_rain", gatewayId: "gw1" },
    });
    // Only admin1's device is pushed…
    assert.equal(sent.length, 1);
    assert.deepEqual(sent[0].tokens, ["tok-admin"]);
    // …but both inboxes have it.
    assert.equal((await db.collection("userNotifications/farmer1/items").get()).size, 1);
    assert.equal((await db.collection("userNotifications/admin1/items").get()).size, 1);

    sent = [];
    await db.doc("notificationPrefs/farmer1").set({ push: false });
    await n.deliverToUsers(["farmer1"], { title: "t", body: "b", channel: n.CHANNEL.approvals, type: "approval_decision" });
    assert.equal(sent.length, 0);
  });

  test("web topics: only the token's owner can subscribe it; changes are diffed", async () => {
    const webTokens = n.createWebTopicsFunction();
    const token = "web-token-farmer1-0123456789";
    await db.doc(`deviceTokens/${token}`).set({ uid: "farmer1", platform: "web" });
    await assert.rejects(webTokens.run({ auth: { uid: "intruder" }, data: { token, topics: ["km_farmers"] } }),
      /isn't registered to you/);
    await webTokens.run({ auth: { uid: "farmer1" }, data: { token, topics: ["km_farmers", "km_crop_maize"] } });
    assert.deepEqual(sent.map((m) => `${m.kind}:${m.topic}`).sort(), ["sub:km_crop_maize", "sub:km_farmers"]);
    sent = [];
    await webTokens.run({ auth: { uid: "farmer1" }, data: { token, topics: ["km_farmers", "km_crop_beans"] } });
    assert.deepEqual(sent.map((m) => `${m.kind}:${m.topic}`).sort(), ["sub:km_crop_beans", "unsub:km_crop_maize"]);
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
