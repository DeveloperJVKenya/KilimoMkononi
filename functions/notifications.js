// functions/notifications.js
//
// Push notifications (Firebase Cloud Messaging) for Kilimo Mkononi.
// Wired into index.js via createNotificationFunctions().
//
//   weatherAlertSweep      hourly, per assigned NuaSense station:
//                          • HIGH/CRITICAL weather alerts to the farmers on
//                            that station, each with the verified advisory
//                            that matches THEIR crops (if one is published);
//                          • condition-targeted verified advice (Raining,
//                            Wet leaves, …) when that condition is actually
//                            occurring at the station — once per farmer per
//                            advisory, repeated at most daily while it lasts.
//   onAdvisoryPublished    a Field Agronomist publishes "Any conditions"
//                          advice (or updates it and ticks "notify") →
//                          farmers on that station growing those crops, or
//                          the crop topics. Condition-targeted advice is NOT
//                          pushed at publish time (it may not apply today);
//                          the sweep delivers it when the condition occurs.
//                          Admin TEST advisories go to the admin only.
//   onEducationSignup      new education account → its approvers.
//   onEducationDecision    approved / denied → the applicant.
//
// Every push to a specific user is also written to
// userNotifications/{uid}/items (the in-app inbox), so the phone and the
// Notifications screen always show the same thing.
//
// Advice pushes (and alerts carrying advice) open the advisory's action
// screen (route "advisory") and carry `sections` (soil / pests / diseases,
// from the advisory's soilActions / pestChecks / diseaseChecks or the alert
// category) and `crops`, so the app files them under each farm section.
//
// Channels / routes / icon must match lib/services/notification_service.dart.

const { createHash } = require("node:crypto");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentWritten,
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const CHANNEL = {
  weather: "km_weather_alerts",
  advisories: "km_advisories",
  approvals: "km_approvals",
  general: "km_general",
};
const ROUTE = {
  weatherStation: "weather_station",
  notifications: "notifications",
  eduHome: "edu_home",
  advisory: "advisory",
};
const ICON = "ic_stat_km";
const COLOR = "#2A6B2A";

// Web app origin — web pushes open `${WEB_APP_URL}/?km_route=…` when tapped
// (read by NotificationService on web start-up). Override with KM_WEB_APP_URL.
const WEB_APP_URL = process.env.KM_WEB_APP_URL || "https://kilimomkononi-e1031.web.app";

// How long an undelivered push stays worth delivering. A phone that's been
// offline longer never gets it (FCM drops it) — no "heavy rain now" three days
// late. The in-app inbox keeps the record regardless.
const TTL_SECONDS = {
  weather_alert: 6 * 60 * 60,
  advisory: 2 * 24 * 60 * 60,
  approval_request: 7 * 24 * 60 * 60,
  approval_decision: 7 * 24 * 60 * 60,
  general: 3 * 24 * 60 * 60,
};

// Re-alert the same station/category only after this long (unless it worsens).
const ALERT_COOLDOWN_MS = 6 * 60 * 60 * 1000;
// Re-send the same condition advice to a farmer at most this often.
const ADVISORY_REPEAT_MS = 24 * 60 * 60 * 1000;
// Ignore stations whose latest reading is older than this (offline).
const STALE_READING_MS = 3 * 60 * 60 * 1000;

// Farm sections a weather-alert category concerns. Mirrors
// kAlertCategorySections in lib/enterprise/features/weather/advisory_actions.dart.
const ALERT_SECTIONS = {
  heavy_rain: ["soil"],
  heat: ["soil"],
  frost: ["soil"],
  fungal: ["diseases"],
  strong_wind: ["pests", "diseases"],
};

// Matches kAdvisoryConditions in lib/enterprise/features/weather/advisory_conditions.dart
const CONDITION_LABELS = {
  general: "Any conditions",
  raining: "Raining now",
  wet_leaves: "Wet leaves",
  high_humidity: "Very humid",
  high_wind: "Windy",
  heat: "Hot",
  cool: "Cool",
  frost: "Frost risk",
  dry_stress: "Dry air / water stress",
  good_spray: "Good spray window",
};

// ── Messaging (injectable for tests) ─────────────────────────────────────────
let messagingOverride = null;
function setMessagingForTests(m) {
  messagingOverride = m;
}
const messaging = () => messagingOverride || getMessaging();

// ═════════════════════════════════════════════════════════════════════════════
//  Pure helpers (unit-tested in functions/test/notifications.test.js)
// ═════════════════════════════════════════════════════════════════════════════

/** FCM topic for a crop — must match NotificationService.cropTopic() in Dart. */
function cropTopic(crop) {
  const slug = String(crop).trim().toLowerCase()
    .replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
  return `km_crop_${slug}`;
}

/** Parses NuaSense /weather + /derived responses (same shape the app parses). */
function parseReading(weather, derived) {
  const series = weather?.series || [];
  const last = (id) => {
    const s = series.find((x) => x.id === id);
    const pts = s?.data || [];
    return pts.length ? Number(pts[pts.length - 1].y) || 0 : 0;
  };
  const lastTime = () => {
    const pts = series[0]?.data || [];
    return pts.length ? new Date(pts[pts.length - 1].x) : null;
  };
  const pts = derived?.points || [];
  const d = pts.length ? pts[pts.length - 1] : {};
  return {
    airTemp: last("air_temperature"),
    humidity: last("humidity"),
    rainfall: last("rainfall"),
    windSpeed: last("wind_speed"),
    windGusts: last("wind_gusts"),
    lwdHour: Math.round(Number(d.lwd_hour) || 0),
    lwdConsecutiveHours: Number(d.lwd_consecutive_hours) || 0,
    vpd: Number(d.vpd) || 0,
    sprayQualityIndex: Number(d.spray_quality_index) || 0,
    sprayQualityLabel: d.spray_quality_label ? String(d.spray_quality_label) : "",
    // No points in the window = offline station; every value above is then a
    // placeholder 0 and must not be read as 0°C / 0% humidity.
    hasData: series.some((s) => (s?.data || []).length > 0),
    timestamp: lastTime(),
  };
}

/**
 * Advisory condition keys active for a reading — mirrors
 * activeConditionKeys() in advisory_conditions.dart. Always has "general".
 */
function activeConditions(r) {
  const keys = new Set(["general"]);
  if (!r || !r.hasData) return keys;
  const raining = r.rainfall > 0.1;
  if (raining) keys.add("raining");
  if (r.lwdHour === 1 || r.lwdConsecutiveHours >= 6) keys.add("wet_leaves");
  if (r.humidity > 80) keys.add("high_humidity");
  if (r.windSpeed > 5) keys.add("high_wind");
  if (r.airTemp > 32) keys.add("heat");
  if (r.airTemp < 15) keys.add("cool");
  if (r.airTemp <= 4) keys.add("frost");
  if (r.vpd > 2.5 || r.humidity < 40) keys.add("dry_stress");
  const goodSpray = r.sprayQualityLabel ? r.sprayQualityIndex >= 70 : r.windSpeed < 3.0;
  if (goodSpray && !raining) keys.add("good_spray");
  return keys;
}

/**
 * HIGH / CRITICAL alerts worth waking a farmer for. Milder conditions are
 * already covered by the in-app day plan — pushes are for real risk only.
 * `advisoryConditions` links an alert to Field Agronomist advisory
 * conditions, most specific first.
 */
function computeWeatherAlerts(r) {
  const alerts = [];
  const add = (category, severity, title, body, advisoryConditions) =>
    alerts.push({ category, severity, title, body, advisoryConditions });

  if (r.rainfall >= 25) {
    add("heavy_rain", "critical", "Very heavy rain at your farm",
      `${r.rainfall.toFixed(1)} mm in the last hour. Check drainage and hold spraying, fertiliser and field work.`, ["raining"]);
  } else if (r.rainfall >= 10) {
    add("heavy_rain", "high", "Heavy rain at your farm",
      `${r.rainfall.toFixed(1)} mm in the last hour. Hold spraying and top-dressing until it clears.`, ["raining"]);
  }

  if (r.windSpeed >= 12 || r.windGusts >= 18) {
    add("strong_wind", "critical", "Dangerous wind at your farm",
      `Wind ${r.windSpeed.toFixed(1)} m/s (gusts ${r.windGusts.toFixed(0)}). Do not spray; secure nurseries and structures.`, ["high_wind"]);
  } else if (r.windSpeed >= 8) {
    add("strong_wind", "high", "Strong wind — don't spray",
      `Wind ${r.windSpeed.toFixed(1)} m/s. Spray will drift; wait for calmer conditions.`, ["high_wind"]);
  }

  if (r.airTemp >= 38) {
    add("heat", "critical", "Extreme heat at your farm",
      `${r.airTemp.toFixed(1)}°C. Irrigate early or late, shade seedlings, avoid field work at midday.`, ["heat"]);
  } else if (r.airTemp >= 35) {
    add("heat", "high", "Heat stress risk",
      `${r.airTemp.toFixed(1)}°C. Water crops early morning and watch for wilting.`, ["heat"]);
  }

  // Frost advice first; general cool-weather advice only if there's none.
  if (r.airTemp <= 2) {
    add("frost", "critical", "Frost at your farm",
      `${r.airTemp.toFixed(1)}°C. Cover seedlings and sensitive crops now.`, ["frost", "cool"]);
  } else if (r.airTemp <= 4) {
    add("frost", "high", "Frost risk tonight",
      `${r.airTemp.toFixed(1)}°C and falling. Protect seedlings and sensitive crops.`, ["frost", "cool"]);
  }

  if (r.lwdConsecutiveHours >= 18 && r.humidity >= 85) {
    add("fungal", "critical", "Severe fungal disease risk",
      `Leaves wet for ${r.lwdConsecutiveHours}h. Scout for blight and leaf spot today.`, ["wet_leaves"]);
  } else if (r.lwdConsecutiveHours >= 10 && r.humidity >= 85) {
    add("fungal", "high", "High fungal disease risk",
      `Leaves wet for ${r.lwdConsecutiveHours}h in humid air. Scout lower leaves for disease.`, ["wet_leaves"]);
  }
  return alerts;
}

/** Send again? Only after the cooldown, or if it got worse. */
function shouldSendAlert(previous, alert, nowMs) {
  if (!previous) return true;
  const lastMs = previous.lastSentAt?.toMillis ? previous.lastSentAt.toMillis() : Number(previous.lastSentAt) || 0;
  if (previous.severity === "high" && alert.severity === "critical") return true;
  return nowMs - lastMs >= ALERT_COOLDOWN_MS;
}

// ── Crops (mirror of cropsMatch() in advisory_conditions.dart) ───────────────
const norm = (s) => String(s).trim().toLowerCase();

function isForAllCrops(advisoryCrops) {
  return (advisoryCrops || []).some((c) => norm(c) === "all crops");
}

/**
 * Does advice for `advisoryCrops` apply to a farmer growing `farmerCrops`?
 * [] = farmer recorded no crops → matches everything (same as the app).
 * null = crops unknown (lookup failed) → only "All crops" advice.
 */
function cropsMatch(advisoryCrops, farmerCrops) {
  if (isForAllCrops(advisoryCrops)) return true;
  if (farmerCrops === null || farmerCrops === undefined) return false;
  if (!farmerCrops.length) return true;
  const mine = new Set(farmerCrops.map(norm));
  return (advisoryCrops || []).some((c) => mine.has(norm(c)));
}

const publishedMs = (a) => a.publishedAt?.toMillis?.() || Number(a.publishedAt) || 0;

/**
 * Advisories that apply at `gatewayId`, most specific first: station-scoped
 * before all-stations, a specific condition before "general", then newest.
 * Same order as AgronomicAdvisoryService.publishedFor() in the app.
 */
function rankAdvisories(advisories, gatewayId) {
  const rank = (a) => (a.gatewayId ? 0 : 2) + ((a.condition || "general") === "general" ? 1 : 0);
  return advisories
    .filter((a) => !a.gatewayId || a.gatewayId === gatewayId)
    .sort((a, b) => rank(a) - rank(b) || publishedMs(b) - publishedMs(a));
}

/** The best advisory for one farmer (their crops, their station), or null. */
function bestAdvisoryFor(advisories, farmerCrops, gatewayId) {
  return rankAdvisories(advisories, gatewayId).find((a) => cropsMatch(a.crops, farmerCrops)) || null;
}

/** Version farmers were last (to be) notified about; older docs lack it. */
function notifyVersionOf(a) {
  return Number.isInteger(a.notifyVersion) ? a.notifyVersion : a.version;
}

/** Deliver condition advice to a farmer? New, re-notified, or a day old. */
function shouldDeliverAdvisory(previous, advisory, nowMs) {
  if (!previous) return true;
  if (previous.notifyVersion !== notifyVersionOf(advisory)) return true;
  const lastMs = previous.lastSentAt?.toMillis ? previous.lastSentAt.toMillis() : Number(previous.lastSentAt) || 0;
  return nowMs - lastMs >= ADVISORY_REPEAT_MS;
}

/**
 * Does this advisory write warrant a publish-time push? null | "new" | "updated".
 * Updates only notify when the agronomist ticked "Notify farmers" — the app
 * then sets notifyVersion to the new version.
 */
function advisoryPushKind(before, after) {
  if (!after || after.status !== "published") return null;
  if (!before || before.status !== "published") return "new";
  if (before.version === after.version) return null;
  if (Number.isInteger(after.notifyVersion) &&
      after.notifyVersion === after.version &&
      after.notifyVersion !== before.notifyVersion) {
    return "updated";
  }
  return null;
}

/**
 * Pushed when published? Only "Any conditions" advice — condition-targeted
 * advice is delivered by the sweep when its condition occurs. Admin TEST
 * advisories always go to the admin straight away, to try the flow.
 */
function pushesAtPublish(a) {
  return !!a.testOnly || (a.condition || "general") === "general";
}

/** Who a publish-time advisory push goes to. */
function advisoryAudience(a) {
  if (a.testOnly) return { type: "users", uids: [a.publishedBy].filter(Boolean) };
  if (a.gatewayId) return { type: "station", gatewayId: a.gatewayId };
  const crops = a.crops || [];
  if (!crops.length || isForAllCrops(crops)) {
    return { type: "topics", topics: ["km_farmers"] };
  }
  return { type: "topics", topics: [...new Set(crops.map(cropTopic))] };
}

/** Farm sections an advisory has actions for: ["soil", "pests", "diseases"]. */
function advisorySections(a) {
  const out = [];
  if ((a.soilActions || []).length) out.push("soil");
  if ((a.pestChecks || []).length) out.push("pests");
  if ((a.diseaseChecks || []).length) out.push("diseases");
  return out;
}

/** "Check for: Aphids, Late blight · Soil: N, P" — or "" without actions. */
function advisoryChecksLine(a) {
  const names = (list) => (list || []).map((c) => c && c.name).filter(Boolean);
  const checks = [...names(a.pestChecks), ...names(a.diseaseChecks)];
  const soil = (a.soilActions || []).map((x) => x && x.nutrient).filter(Boolean)
    .map((n) => (n === "general" ? "soil care" : n));
  const parts = [];
  if (checks.length) parts.push(`Check for: ${checks.join(", ")}`);
  if (soil.length) parts.push(`Soil: ${soil.join(", ")}`);
  return parts.join(" · ");
}

function advisoryNotification(a, kind, gatewayId = a.gatewayId) {
  const label = CONDITION_LABELS[a.condition] || "Weather";
  const prefix = a.testOnly ? "TEST · " : "";
  const verb = kind === "updated" ? "Updated verified advice" : "Verified advice";
  const data = { advisoryId: a.__id || "", testOnly: a.testOnly ? "true" : "false" };
  if (gatewayId) data.gatewayId = gatewayId;
  const sections = advisorySections(a);
  if (sections.length) data.sections = sections.join(",");
  if ((a.crops || []).length) data.crops = a.crops.join(",");
  const checks = advisoryChecksLine(a);
  return {
    title: `${prefix}${verb} · ${label}`,
    body: `${(a.crops || []).join(", ")}: ${a.main || ""}`.trim() + (checks ? `\n${checks}` : ""),
    channel: CHANNEL.advisories,
    route: ROUTE.advisory,
    type: "advisory",
    data,
  };
}

/** Route + data for a weather alert; opens its advice when it carries some. */
function alertPayload(alert, gatewayId, advice) {
  const sections = new Set(ALERT_SECTIONS[alert.category] || []);
  if (advice) advisorySections(advice).forEach((x) => sections.add(x));
  const data = { category: alert.category, gatewayId };
  if (sections.size) data.sections = [...sections].join(",");
  if (!advice) return { route: ROUTE.weatherStation, data };
  data.advisoryId = advice.__id;
  data.alertTitle = alert.title;
  if ((advice.crops || []).length) data.crops = advice.crops.join(",");
  return { route: ROUTE.advisory, data };
}

/** Which EducationUsers must approve this new account. */
function approverFilter(user) {
  switch (user.requestedRole) {
    case "headteacher":
      return { role: "mainadmin" };
    case "teacher":
      return { role: "headteacher", schoolName: user.schoolName };
    case "student":
      return { role: "teacher", schoolName: user.schoolName, classId: user.currentClassId || null };
    default:
      return null;
  }
}

/** FCM condition strings — at most 5 topics each. */
function topicConditions(topics) {
  const out = [];
  for (let i = 0; i < topics.length; i += 5) {
    out.push(topics.slice(i, i + 5).map((t) => `'${t}' in topics`).join(" || "));
  }
  return out;
}

/**
 * Pushes that supersede each other share a collapse key: a newer alert for
 * the same station + hazard (or a re-send of the same advice) replaces the
 * older one — in the tray, and in FCM's queue for offline phones.
 */
function collapseKeyFor(n) {
  const d = n.data || {};
  if (n.type === "weather_alert" && d.gatewayId && d.category) return `wx_${d.gatewayId}_${d.category}`;
  if (n.type === "advisory" && d.advisoryId) return `adv_${d.advisoryId}`;
  return null;
}

/** Where a web push opens: the web app, with the route + its data. */
function webLink(route, extra) {
  const qs = new URLSearchParams({ km_route: route });
  for (const [k, v] of Object.entries(extra || {})) qs.set(k, String(v));
  return `${WEB_APP_URL}/?${qs}`;
}

// Web Push "Topic" header: max 32 URL-safe chars.
const webPushTopic = (key) => createHash("sha256").update(key).digest("base64url").slice(0, 32);

/** Common message shape (notification + data + per-platform delivery rules). */
function buildMessage(n, nowMs = Date.now()) {
  const data = { route: n.route || ROUTE.notifications, channel: n.channel, type: n.type || "general" };
  for (const [k, v] of Object.entries(n.data || {})) data[k] = String(v);
  const ttl = TTL_SECONDS[n.type] ?? TTL_SECONDS.general;
  const collapse = collapseKeyFor(n);
  return {
    notification: { title: n.title, body: n.body },
    data,
    android: {
      priority: "high",
      ttl: ttl * 1000,
      ...(collapse ? { collapseKey: collapse } : {}),
      notification: { channelId: n.channel, icon: ICON, color: COLOR, ...(collapse ? { tag: collapse } : {}) },
    },
    apns: {
      headers: {
        "apns-expiration": String(Math.floor(nowMs / 1000) + ttl),
        ...(collapse ? { "apns-collapse-id": collapse.slice(0, 64) } : {}),
      },
      payload: { aps: { sound: "default" } },
    },
    webpush: {
      headers: {
        TTL: String(ttl),
        Urgency: n.type === "weather_alert" ? "high" : "normal",
        ...(collapse ? { Topic: webPushTopic(collapse) } : {}),
      },
      notification: { icon: "/icons/Icon-192.png", ...(collapse ? { tag: collapse } : {}) },
      fcmOptions: { link: webLink(data.route, n.data) },
    },
  };
}

// ── Web topics ───────────────────────────────────────────────────────────────
// Browsers can't subscribe themselves to FCM topics (mobile SDKs can), so
// the web app asks this function to do it for its token — then web farmers
// get crop-topic advice too.
const TOPIC_RE = /^km_(farmers|crop_[a-z0-9_]{1,40})$/;

/** Topics to subscribe / unsubscribe to go from `had` to `wanted`. */
function topicDiff(had, wanted) {
  const h = new Set(had || []);
  const w = new Set(wanted || []);
  return { add: [...w].filter((t) => !h.has(t)), remove: [...h].filter((t) => !w.has(t)) };
}

function validateWebTopics(data) {
  const token = String(data?.token ?? "");
  const topics = Array.isArray(data?.topics) ? [...new Set(data.topics.map(String))] : null;
  if (token.length < 20 || token.length > 4096 || token.includes("/")) {
    throw new HttpsError("invalid-argument", "Invalid device token.");
  }
  if (!topics || topics.length > 25 || !topics.every((t) => TOPIC_RE.test(t))) {
    throw new HttpsError("invalid-argument", "Invalid topics.");
  }
  return { token, topics };
}

function createWebTopicsFunction() {
  return onCall({ timeoutSeconds: 30, memory: "256MiB", maxInstances: 10 }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
    const { token, topics } = validateWebTopics(request.data);
    const db = getFirestore();
    const device = await db.collection("deviceTokens").doc(token).get();
    if (!device.exists || device.data().uid !== request.auth.uid) {
      throw new HttpsError("permission-denied", "That device isn't registered to you.");
    }
    const stateRef = db.collection("webTopicState").doc(token);
    const state = await stateRef.get();
    const { add, remove } = topicDiff(state.exists ? state.data().topics : [], topics);
    for (const t of add) await messaging().subscribeToTopic([token], t);
    for (const t of remove) await messaging().unsubscribeFromTopic([token], t);
    await stateRef.set({ uid: request.auth.uid, topics, updatedAt: FieldValue.serverTimestamp() });
    return { added: add, removed: remove };
  });
}

// ═════════════════════════════════════════════════════════════════════════════
//  Delivery
// ═════════════════════════════════════════════════════════════════════════════

const chunk = (arr, n) => {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
};

/** Groups items into Map(key → [items]). */
function groupBy(items, keyOf) {
  const out = new Map();
  for (const item of items) {
    const k = keyOf(item);
    if (!out.has(k)) out.set(k, []);
    out.get(k).push(item);
  }
  return out;
}

async function tokensFor(uids) {
  const db = getFirestore();
  const tokens = [];
  for (const part of chunk([...new Set(uids)], 30)) {
    const snap = await db.collection("deviceTokens").where("uid", "in", part).get();
    snap.docs.forEach((d) => tokens.push(d.id));
  }
  return tokens;
}

/**
 * Which Notification Settings switch controls a push of this type
 * (mirrors lib/services/notification_prefs.dart). null = only the master
 * "push" switch applies.
 */
function prefKeyFor(type) {
  switch (type) {
    case "weather_alert": return "weatherAlerts";
    case "advisory": return "advisories";
    case "approval_request":
    case "approval_decision": return "approvals";
    default: return null;
  }
}

/** Does this user want a phone push of `type`? Missing prefs = defaults (on). */
function wantsPush(prefs, type) {
  if (!prefs) return true;
  if (prefs.push === false) return false;
  const key = prefKeyFor(type);
  return !key || prefs[key] !== false;
}

/** Users (of `uids`) whose settings allow a push of `type`. */
async function usersWantingPush(uids, type) {
  const db = getFirestore();
  const out = [];
  for (const part of chunk(uids, 100)) {
    const snaps = await db.getAll(...part.map((u) => db.collection("notificationPrefs").doc(u)));
    snaps.forEach((s, i) => {
      if (wantsPush(s.exists ? s.data() : null, type)) out.push(part[i]);
    });
  }
  return out;
}

/**
 * Inbox item for each user, and a push to the devices of those whose
 * Notification Settings allow it (the inbox keeps a dated record either
 * way). Removes tokens FCM says are dead.
 */
async function deliverToUsers(uids, n) {
  const db = getFirestore();
  const unique = [...new Set(uids.filter(Boolean))];
  if (!unique.length) return { users: 0, sent: 0 };

  for (const part of chunk(unique, 400)) {
    const batch = db.batch();
    for (const uid of part) {
      batch.set(db.collection("userNotifications").doc(uid).collection("items").doc(), {
        type: n.type || "general",
        channel: n.channel,
        title: n.title,
        body: n.body,
        route: n.route || ROUTE.notifications,
        severity: n.severity || null,
        data: n.data || {},
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  const pushTo = await usersWantingPush(unique, n.type || "general");
  const tokens = pushTo.length ? await tokensFor(pushTo) : [];
  let sent = 0;
  for (const part of chunk(tokens, 500)) {
    const res = await messaging().sendEachForMulticast({ ...buildMessage(n), tokens: part });
    sent += res.successCount;
    const dead = [];
    res.responses.forEach((r, i) => {
      const code = r.error?.code || "";
      if (code.includes("registration-token-not-registered") || code.includes("invalid-registration-token")) {
        dead.push(part[i]);
      }
    });
    await Promise.all(dead.map((t) => db.collection("deviceTokens").doc(t).delete()));
  }
  return { users: unique.length, pushed: pushTo.length, sent };
}

async function deliverToTopics(topics, n) {
  let sent = 0;
  for (const condition of topicConditions(topics)) {
    await messaging().send({ ...buildMessage(n), condition });
    sent++;
  }
  return sent;
}

async function farmersOnStation(gatewayId, platform) {
  const snap = await getFirestore().collection("stationAssignments")
    .where("gatewayId", "==", gatewayId)
    .where("platform", "==", platform)
    .get();
  return snap.docs.map((d) => d.data().uid);
}

/**
 * Each farmer's crops, from their recent field records (fielddata.crops[].type)
 * — the same source the app uses. Map(uid → [crops] | null when unknown).
 */
async function farmerCrops(uids) {
  const db = getFirestore();
  const out = new Map();
  await Promise.all([...new Set(uids)].map(async (uid) => {
    try {
      const snap = await db.collection("fielddata")
        .where("userId", "==", uid)
        .orderBy("timestamp", "desc")
        .limit(30)
        .get();
      const crops = new Set();
      for (const d of snap.docs) {
        for (const c of d.data().crops || []) {
          const type = c && typeof c === "object" ? String(c.type || "").trim() : "";
          if (type) crops.add(type);
        }
      }
      out.set(uid, [...crops]);
    } catch (e) {
      console.warn(`[farmerCrops] ${uid}: ${e.message}`);
      out.set(uid, null);
    }
  }));
  return out;
}

/** Live (non-test) published advisories for any of `conditions`. */
async function publishedLiveAdvisories(conditions) {
  const out = [];
  for (const part of chunk([...new Set(conditions)], 30)) {
    const snap = await getFirestore().collection("agronomic_advisories")
      .where("status", "==", "published")
      .where("testOnly", "==", false)
      .where("condition", "in", part)
      .get();
    snap.docs.forEach((d) => out.push({ ...d.data(), __id: d.id }));
  }
  return out;
}

const deliveryRef = (uid, advisoryId) =>
  getFirestore().collection("advisoryDelivery").doc(`${uid}_${advisoryId}`);

/** Records that `uids` got `advisory` now (for the daily repeat limit). */
async function markDelivered(uids, advisory, gatewayId, nowMs) {
  const db = getFirestore();
  for (const part of chunk(uids, 400)) {
    const batch = db.batch();
    for (const uid of part) {
      batch.set(deliveryRef(uid, advisory.__id), {
        uid,
        advisoryId: advisory.__id,
        gatewayId,
        notifyVersion: notifyVersionOf(advisory),
        lastSentAt: Timestamp.fromMillis(nowMs),
      });
    }
    await batch.commit();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Weather sweep (the body of weatherAlertSweep; exported for tests)
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Builds the hourly sweep. `fetchReading(gatewayId)` returns parseReading()
 * output (or null); injected so tests don't call NuaSense.
 */
function createWeatherSweep({ PLATFORM, fetchReading }) {
  return async function runWeatherSweep(nowMs = Date.now()) {
    const db = getFirestore();
    const assignments = await db.collection("stationAssignments")
      .where("platform", "==", PLATFORM).get();
    const byStation = groupBy(assignments.docs.map((d) => d.data()), (a) => a.gatewayId);

    for (const [gatewayId, rows] of byStation) {
      const uids = [...new Set(rows.map((r) => r.uid).filter(Boolean))];
      let reading;
      try {
        reading = await fetchReading(gatewayId);
      } catch (e) {
        console.warn(`[weatherAlertSweep] ${gatewayId}: ${e.message}`);
        continue;
      }
      if (!reading || !reading.hasData || !reading.timestamp ||
          nowMs - reading.timestamp.getTime() > STALE_READING_MS) {
        continue;
      }

      const alerts = computeWeatherAlerts(reading);
      const active = [...activeConditions(reading)].filter((c) => c !== "general");
      const conditions = [...new Set([...active, ...alerts.flatMap((a) => a.advisoryConditions)])];
      if (!alerts.length && !active.length) continue;

      const crops = await farmerCrops(uids);
      const advisories = conditions.length ? await publishedLiveAdvisories(conditions) : [];
      // Conditions each farmer already heard about in an alert this run — no
      // second push about the same weather.
      const covered = new Map(uids.map((u) => [u, new Set()]));

      // 1) Alerts, each farmer's copy carrying the advice for THEIR crops.
      for (const alert of alerts) {
        const stateRef = db.collection("alertState").doc(`${gatewayId}_${alert.category}`);
        const prev = await stateRef.get();
        if (!shouldSendAlert(prev.exists ? prev.data() : null, alert, nowMs)) continue;

        const adviceFor = (uid) => {
          for (const cond of alert.advisoryConditions) {
            const a = bestAdvisoryFor(advisories.filter((x) => x.condition === cond), crops.get(uid), gatewayId);
            if (a) return a;
          }
          return null;
        };
        const picks = uids.map((uid) => ({ uid, advice: adviceFor(uid) }));
        for (const group of groupBy(picks, (p) => p.advice?.__id || "").values()) {
          const advice = group[0].advice;
          const groupUids = group.map((p) => p.uid);
          await deliverToUsers(groupUids, {
            title: `${alert.severity === "critical" ? "⚠ " : ""}${alert.title}`,
            body: advice
              ? `${alert.body}\nVerified advice: ${advice.main}` +
                (advisoryChecksLine(advice) ? `\n${advisoryChecksLine(advice)}` : "")
              : alert.body,
            channel: CHANNEL.weather,
            type: "weather_alert",
            severity: alert.severity,
            ...alertPayload(alert, gatewayId, advice),
          });
          if (advice) await markDelivered(groupUids, advice, gatewayId, nowMs);
          groupUids.forEach((u) => alert.advisoryConditions.forEach((c) => covered.get(u).add(c)));
        }
        await stateRef.set({ lastSentAt: Timestamp.fromMillis(nowMs), severity: alert.severity });
        console.log(`[weatherAlertSweep] ${gatewayId} ${alert.category}/${alert.severity} → ${uids.length} farmer(s)`);
      }

      // 2) Condition advice now in effect — at most one per farmer per run
      //    (the most specific one due); the rest follow in later runs.
      const conditionAdvice = advisories.filter((a) => active.includes(a.condition));
      if (!conditionAdvice.length) continue;
      const candidates = new Map(uids.map((uid) => [
        uid,
        rankAdvisories(conditionAdvice, gatewayId)
          .filter((a) => cropsMatch(a.crops, crops.get(uid)) && !covered.get(uid).has(a.condition)),
      ]));
      const refs = [];
      for (const [uid, list] of candidates) list.forEach((a) => refs.push(deliveryRef(uid, a.__id)));
      const state = new Map();
      for (const part of chunk(refs, 100)) {
        (await db.getAll(...part)).forEach((s) => state.set(s.id, s.exists ? s.data() : null));
      }

      const picks = [];
      for (const [uid, list] of candidates) {
        const due = list.find((a) => shouldDeliverAdvisory(state.get(`${uid}_${a.__id}`), a, nowMs));
        if (due) picks.push({ uid, advice: due });
      }
      for (const group of groupBy(picks, (p) => p.advice.__id).values()) {
        const advice = group[0].advice;
        const groupUids = group.map((p) => p.uid);
        await deliverToUsers(groupUids, advisoryNotification(advice, "condition", gatewayId));
        await markDelivered(groupUids, advice, gatewayId, nowMs);
        console.log(`[weatherAlertSweep] ${gatewayId} advice ${advice.__id} (${advice.condition}) → ${groupUids.length} farmer(s)`);
      }
    }
  };
}

// ═════════════════════════════════════════════════════════════════════════════
//  Cloud Functions
// ═════════════════════════════════════════════════════════════════════════════

function createNotificationFunctions({ NUASENSE_KEY, NUASENSE_BASE, PLATFORM }) {
  async function fetchStationReading(gatewayId) {
    const get = async (endpoint, params) => {
      const qs = new URLSearchParams({ ...params, gateway_id: gatewayId });
      const res = await fetch(`${NUASENSE_BASE}/${endpoint}?${qs}`, {
        headers: { Authorization: `Bearer ${NUASENSE_KEY.value()}`, Accept: "application/json" },
      });
      return res.ok ? res.json() : null;
    };
    const [weather, derived] = await Promise.all([
      get("weather", {
        metrics: "air_temperature,humidity,rainfall,wind_speed,wind_gusts",
        start: "-2h", resolution: "hourly", aggregate: "last",
      }),
      get("derived", {
        fields: "lwd_hour,lwd_consecutive_hours,vpd,spray_quality_index,spray_quality_label",
        start: "-2h",
      }),
    ]);
    if (!weather || !derived) return null;
    return parseReading(weather, derived);
  }

  const runWeatherSweep = createWeatherSweep({ PLATFORM, fetchReading: fetchStationReading });

  const weatherAlertSweep = onSchedule(
    {
      schedule: "every 60 minutes",
      timeZone: "Africa/Nairobi",
      secrets: [NUASENSE_KEY],
      timeoutSeconds: 540,
      memory: "256MiB",
      maxInstances: 1,
    },
    () => runWeatherSweep()
  );

  const onAdvisoryPublished = onDocumentWritten("agronomic_advisories/{advisoryId}", async (event) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    const kind = advisoryPushKind(before, after);
    if (!kind) return;

    const advisory = { ...after, __id: event.params.advisoryId };
    if (!pushesAtPublish(advisory)) {
      console.log(`[onAdvisoryPublished] ${advisory.__id} ${kind} — "${advisory.condition}" advice is delivered when the condition occurs`);
      return;
    }
    const n = advisoryNotification(advisory, kind);
    const audience = advisoryAudience(advisory);
    if (audience.type === "users") {
      await deliverToUsers(audience.uids, n);
    } else if (audience.type === "station") {
      const uids = await farmersOnStation(audience.gatewayId, PLATFORM);
      const crops = await farmerCrops(uids);
      await deliverToUsers(uids.filter((u) => cropsMatch(advisory.crops, crops.get(u))), n);
    } else {
      await deliverToTopics(audience.topics, n);
    }
    console.log(`[onAdvisoryPublished] ${advisory.__id} ${kind} → ${audience.type}`);
  });

  const onEducationSignup = onDocumentCreated("EducationUsers/{uid}", async (event) => {
    const user = event.data?.data();
    if (!user || (user.approvalStatus || "pending") !== "pending") return;
    const f = approverFilter(user);
    if (!f) return;

    let q = getFirestore().collection("EducationUsers")
      .where("role", "==", f.role)
      .where("approvalStatus", "==", "approved");
    if (f.schoolName) q = q.where("schoolName", "==", f.schoolName);
    let approvers = (await q.get()).docs;
    // Students: prefer teachers of their class, else any teacher at the school.
    if (f.classId) {
      const ofClass = approvers.filter((d) => (d.data().classIds || []).includes(f.classId));
      if (ofClass.length) approvers = ofClass;
    }
    await deliverToUsers(approvers.map((d) => d.id), {
      title: "New account waiting for approval",
      body: `${user.fullName || "Someone"} (${user.requestedRole}) at ${user.schoolName || "your school"} is waiting for your approval.`,
      channel: CHANNEL.approvals,
      route: ROUTE.eduHome,
      type: "approval_request",
      data: { applicantUid: event.params.uid },
    });
  });

  const onEducationDecision = onDocumentUpdated("EducationUsers/{uid}", async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (before.approvalStatus === after.approvalStatus) return;
    if (!["approved", "denied"].includes(after.approvalStatus)) return;
    const approved = after.approvalStatus === "approved";
    await deliverToUsers([event.params.uid], {
      title: approved ? "Your account is approved" : "Your account request was not approved",
      body: approved
        ? `You can now use Kilimo Mkononi Education as a ${after.role}.`
        : "Contact your school administrator if you think this is a mistake.",
      channel: CHANNEL.approvals,
      route: ROUTE.eduHome,
      type: "approval_decision",
    });
  });

  return { weatherAlertSweep, onAdvisoryPublished, onEducationSignup, onEducationDecision };
}

module.exports = {
  createNotificationFunctions,
  createWebTopicsFunction,
  // exported for tests
  createWeatherSweep,
  collapseKeyFor,
  wantsPush,
  webLink,
  topicDiff,
  validateWebTopics,
  TTL_SECONDS,
  cropTopic,
  parseReading,
  activeConditions,
  computeWeatherAlerts,
  shouldSendAlert,
  cropsMatch,
  rankAdvisories,
  bestAdvisoryFor,
  shouldDeliverAdvisory,
  advisoryPushKind,
  pushesAtPublish,
  advisoryAudience,
  advisoryNotification,
  advisorySections,
  advisoryChecksLine,
  alertPayload,
  ALERT_SECTIONS,
  approverFilter,
  topicConditions,
  buildMessage,
  deliverToUsers,
  setMessagingForTests,
  CHANNEL,
  ROUTE,
  CONDITION_LABELS,
};
