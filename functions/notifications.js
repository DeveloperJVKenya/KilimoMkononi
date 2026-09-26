// functions/notifications.js
//
// Push notifications (Firebase Cloud Messaging) for Kilimo Mkononi.
// Wired into index.js via createNotificationFunctions().
//
//   weatherAlertSweep      hourly: reads every assigned NuaSense station,
//                          pushes HIGH/CRITICAL weather alerts to the farmers
//                          on that station (with the matching verified
//                          advisory, if a Field Agronomist has published one).
//   onAdvisoryPublished    a Field Agronomist publishes / updates advice →
//                          farmers on that station, or on the advice's crop
//                          topics. Admin TEST advisories go to the admin only.
//   onEducationSignup      new education account → its approvers.
//   onEducationDecision    approved / denied → the applicant.
//
// Every push to a specific user is also written to
// userNotifications/{uid}/items (the in-app inbox), so the phone and the
// Notifications screen always show the same thing.
//
// Channels / routes / icon must match lib/services/notification_service.dart.

const { onSchedule } = require("firebase-functions/v2/scheduler");
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
};
const ICON = "ic_stat_km";
const COLOR = "#2A6B2A";

// Re-alert the same station/category only after this long (unless it worsens).
const ALERT_COOLDOWN_MS = 6 * 60 * 60 * 1000;
// Ignore stations whose latest reading is older than this (offline).
const STALE_READING_MS = 3 * 60 * 60 * 1000;

// Matches kAdvisoryConditions in lib/enterprise/features/weather/advisory_conditions.dart
const CONDITION_LABELS = {
  general: "Any conditions",
  raining: "Raining now",
  wet_leaves: "Wet leaves",
  high_humidity: "Very humid",
  high_wind: "Windy",
  heat: "Hot",
  cool: "Cool",
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
  const last = (id) => {
    const s = (weather?.series || []).find((x) => x.id === id);
    const pts = s?.data || [];
    return pts.length ? Number(pts[pts.length - 1].y) || 0 : 0;
  };
  const lastTime = () => {
    const s = (weather?.series || [])[0];
    const pts = s?.data || [];
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
    lwdHour: Number(d.lwd_hour) || 0,
    lwdConsecutiveHours: Number(d.lwd_consecutive_hours) || 0,
    timestamp: lastTime(),
  };
}

/**
 * HIGH / CRITICAL alerts worth waking a farmer for. Milder conditions are
 * already covered by the in-app day plan — pushes are for real risk only.
 * `advisoryCondition` links an alert to a Field Agronomist advisory condition.
 */
function computeWeatherAlerts(r) {
  const alerts = [];
  const add = (category, severity, title, body, advisoryCondition) =>
    alerts.push({ category, severity, title, body, advisoryCondition });

  if (r.rainfall >= 25) {
    add("heavy_rain", "critical", "Very heavy rain at your farm",
      `${r.rainfall.toFixed(1)} mm in the last hour. Check drainage and hold spraying, fertiliser and field work.`, "raining");
  } else if (r.rainfall >= 10) {
    add("heavy_rain", "high", "Heavy rain at your farm",
      `${r.rainfall.toFixed(1)} mm in the last hour. Hold spraying and top-dressing until it clears.`, "raining");
  }

  if (r.windSpeed >= 12 || r.windGusts >= 18) {
    add("strong_wind", "critical", "Dangerous wind at your farm",
      `Wind ${r.windSpeed.toFixed(1)} m/s (gusts ${r.windGusts.toFixed(0)}). Do not spray; secure nurseries and structures.`, "high_wind");
  } else if (r.windSpeed >= 8) {
    add("strong_wind", "high", "Strong wind — don't spray",
      `Wind ${r.windSpeed.toFixed(1)} m/s. Spray will drift; wait for calmer conditions.`, "high_wind");
  }

  if (r.airTemp >= 38) {
    add("heat", "critical", "Extreme heat at your farm",
      `${r.airTemp.toFixed(1)}°C. Irrigate early or late, shade seedlings, avoid field work at midday.`, "heat");
  } else if (r.airTemp >= 35) {
    add("heat", "high", "Heat stress risk",
      `${r.airTemp.toFixed(1)}°C. Water crops early morning and watch for wilting.`, "heat");
  }

  if (r.airTemp <= 2) {
    add("frost", "critical", "Frost at your farm",
      `${r.airTemp.toFixed(1)}°C. Cover seedlings and sensitive crops now.`, "cool");
  } else if (r.airTemp <= 4) {
    add("frost", "high", "Frost risk tonight",
      `${r.airTemp.toFixed(1)}°C and falling. Protect seedlings and sensitive crops.`, "cool");
  }

  if (r.lwdConsecutiveHours >= 18 && r.humidity >= 85) {
    add("fungal", "critical", "Severe fungal disease risk",
      `Leaves wet for ${r.lwdConsecutiveHours}h. Scout for blight and leaf spot today.`, "wet_leaves");
  } else if (r.lwdConsecutiveHours >= 10 && r.humidity >= 85) {
    add("fungal", "high", "High fungal disease risk",
      `Leaves wet for ${r.lwdConsecutiveHours}h in humid air. Scout lower leaves for disease.`, "wet_leaves");
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

/** Does this advisory write warrant a push? null | "new" | "updated". */
function advisoryPushKind(before, after) {
  if (!after || after.status !== "published") return null;
  if (!before || before.status !== "published") return "new";
  if (before.version !== after.version) return "updated";
  return null;
}

/** Who an advisory push goes to. */
function advisoryAudience(a) {
  if (a.testOnly) return { type: "users", uids: [a.publishedBy].filter(Boolean) };
  if (a.gatewayId) return { type: "station", gatewayId: a.gatewayId };
  const crops = a.crops || [];
  if (!crops.length || crops.some((c) => String(c).toLowerCase() === "all crops")) {
    return { type: "topics", topics: ["km_farmers"] };
  }
  return { type: "topics", topics: [...new Set(crops.map(cropTopic))] };
}

function advisoryNotification(a, kind) {
  const label = CONDITION_LABELS[a.condition] || "Weather";
  const prefix = a.testOnly ? "TEST · " : "";
  const verb = kind === "updated" ? "Updated verified advice" : "Verified advice";
  return {
    title: `${prefix}${verb} · ${label}`,
    body: `${(a.crops || []).join(", ")}: ${a.main || ""}`.trim(),
    channel: CHANNEL.advisories,
    route: ROUTE.weatherStation,
    type: "advisory",
    data: { advisoryId: a.__id || "", testOnly: a.testOnly ? "true" : "false" },
  };
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

/** Common message shape (notification + data) for every push. */
function buildMessage(n) {
  const data = { route: n.route || ROUTE.notifications, channel: n.channel, type: n.type || "general" };
  for (const [k, v] of Object.entries(n.data || {})) data[k] = String(v);
  return {
    notification: { title: n.title, body: n.body },
    data,
    android: {
      priority: "high",
      notification: { channelId: n.channel, icon: ICON, color: COLOR },
    },
    apns: { payload: { aps: { sound: "default" } } },
  };
}

// ═════════════════════════════════════════════════════════════════════════════
//  Delivery
// ═════════════════════════════════════════════════════════════════════════════

const chunk = (arr, n) => {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
};

async function tokensFor(uids) {
  const db = getFirestore();
  const tokens = [];
  for (const part of chunk([...new Set(uids)], 30)) {
    const snap = await db.collection("deviceTokens").where("uid", "in", part).get();
    snap.docs.forEach((d) => tokens.push(d.id));
  }
  return tokens;
}

/** Inbox item + push for each user. Removes tokens FCM says are dead. */
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

  const tokens = await tokensFor(unique);
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
  return { users: unique.length, sent };
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

/** Latest live verified advisory for a condition at a station (or null). */
async function verifiedAdviceFor(condition, gatewayId) {
  const snap = await getFirestore().collection("agronomic_advisories")
    .where("status", "==", "published")
    .where("testOnly", "==", false)
    .where("condition", "==", condition)
    .get();
  const list = snap.docs.map((d) => d.data())
    .filter((a) => !a.gatewayId || a.gatewayId === gatewayId)
    .sort((a, b) => (b.publishedAt?.toMillis?.() || 0) - (a.publishedAt?.toMillis?.() || 0));
  return list[0] || null;
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
      get("derived", { fields: "lwd_hour,lwd_consecutive_hours", start: "-2h" }),
    ]);
    if (!weather || !derived) return null;
    return parseReading(weather, derived);
  }

  const weatherAlertSweep = onSchedule(
    {
      schedule: "every 60 minutes",
      timeZone: "Africa/Nairobi",
      secrets: [NUASENSE_KEY],
      timeoutSeconds: 540,
      memory: "256MiB",
      maxInstances: 1,
    },
    async () => {
      const db = getFirestore();
      const assignments = await db.collection("stationAssignments")
        .where("platform", "==", PLATFORM).get();
      const byStation = new Map();
      assignments.docs.forEach((d) => {
        const { gatewayId, uid } = d.data();
        if (!byStation.has(gatewayId)) byStation.set(gatewayId, []);
        byStation.get(gatewayId).push(uid);
      });

      const now = Date.now();
      for (const [gatewayId, uids] of byStation) {
        let reading;
        try {
          reading = await fetchStationReading(gatewayId);
        } catch (e) {
          console.warn(`[weatherAlertSweep] ${gatewayId}: ${e.message}`);
          continue;
        }
        if (!reading || !reading.timestamp || now - reading.timestamp.getTime() > STALE_READING_MS) continue;

        for (const alert of computeWeatherAlerts(reading)) {
          const stateRef = db.collection("alertState").doc(`${gatewayId}_${alert.category}`);
          const prev = await stateRef.get();
          if (!shouldSendAlert(prev.exists ? prev.data() : null, alert, now)) continue;

          const advice = await verifiedAdviceFor(alert.advisoryCondition, gatewayId);
          const body = advice ? `${alert.body}\nVerified advice: ${advice.main}` : alert.body;
          await deliverToUsers(uids, {
            title: `${alert.severity === "critical" ? "⚠ " : ""}${alert.title}`,
            body,
            channel: CHANNEL.weather,
            route: ROUTE.weatherStation,
            type: "weather_alert",
            severity: alert.severity,
            data: { category: alert.category, gatewayId },
          });
          await stateRef.set({ lastSentAt: Timestamp.fromMillis(now), severity: alert.severity });
          console.log(`[weatherAlertSweep] ${gatewayId} ${alert.category}/${alert.severity} → ${uids.length} farmer(s)`);
        }
      }
    }
  );

  const onAdvisoryPublished = onDocumentWritten("agronomic_advisories/{advisoryId}", async (event) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    const kind = advisoryPushKind(before, after);
    if (!kind) return;

    const advisory = { ...after, __id: event.params.advisoryId };
    const n = advisoryNotification(advisory, kind);
    const audience = advisoryAudience(advisory);
    if (audience.type === "users") {
      await deliverToUsers(audience.uids, n);
    } else if (audience.type === "station") {
      await deliverToUsers(await farmersOnStation(audience.gatewayId, PLATFORM), n);
    } else {
      await deliverToTopics(audience.topics, n);
    }
    console.log(`[onAdvisoryPublished] ${event.params.advisoryId} ${kind} → ${audience.type}`);
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
  // exported for tests
  cropTopic,
  parseReading,
  computeWeatherAlerts,
  shouldSendAlert,
  advisoryPushKind,
  advisoryAudience,
  advisoryNotification,
  approverFilter,
  topicConditions,
  buildMessage,
  deliverToUsers,
  setMessagingForTests,
  CHANNEL,
  ROUTE,
};
