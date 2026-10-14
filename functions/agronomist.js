// functions/agronomist.js
//
// Field Agronomists and farmers' records. Wired into index.js via
// createAgronomistFunctions().
//
//   agronomistData        callable, Field Agronomists / admins only:
//     action "insights"   every farmer's recent records, normalised into
//                         rows the app aggregates (trends, emerging and
//                         unidentified problems, nutrient status). Farmers
//                         who turned sharing off are in the counts only —
//                         no name, no id.
//     action "farmer"     one farmer's full record (plots + soil, pests and
//                         diseases, photo diagnoses, costs, advice sent and
//                         what they did with it). Refused for farmers who
//                         don't share; every view is logged
//                         (agronomistAccessLog).
//   farmer data triggers  a farmer saves a pest / disease / photo diagnosis /
//                         field record / acts on advice → farmerActivity
//                         (the panel's live feed) + an inbox item for every
//                         agronomist. Phone pushes only for notable entries
//                         (pests, diseases, unidentified problems, low
//                         nutrients), at most one per farmer per hour.
//   agronomistDailyDigest 18:00 Nairobi: one summary push of the day.
//   onFarmerAdviceSent    custom advice for one farmer (farmer_advice/{id})
//                         is pushed to that farmer like verified advice
//                         (route "advisory" → the same action screen).
//   onPrivacyChanged      a farmer turns sharing off → their activity feed
//                         entries are removed.
//
// Sharing: privacySettings/{uid}.shareWithAgronomists (missing = on).
// Records are read here with the Admin SDK — the rules never give
// agronomists direct read access to farmers' collections.

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const {
  deliverToUsers,
  advisorySections,
  advisoryChecksLine,
  CHANNEL,
  ROUTE,
} = require("./notifications");

const DAY_MS = 24 * 60 * 60 * 1000;
// At most one phone push per farmer per hour (the inbox gets every entry).
const FARMER_PUSH_COOLDOWN_MS = 60 * 60 * 1000;
// Two writes of the same pest / disease record (new + legacy collection) land
// within this window of each other.
const DUPLICATE_WINDOW_MS = 2 * 60 * 1000;
const MAX_ROWS = 6000;
// Soil tests older than this don't describe the plot any more.
const PLOT_WINDOW_MS = 365 * DAY_MS;
const INSIGHT_DAYS = [7, 30, 90];
const CACHE_MS = 3 * 60 * 1000;
// Firestore triggers: a few instances are plenty, and each instance a
// function may scale to reserves regional CPU quota at deploy time.
const TRIGGER_OPTS = { maxInstances: 5, memory: "256MiB", timeoutSeconds: 120 };

// ═════════════════════════════════════════════════════════════════════════════
//  Pure helpers (unit-tested in functions/test/agronomist.test.js)
// ═════════════════════════════════════════════════════════════════════════════

/** Timestamp / Date / millis / {_seconds} → millis (0 when unknown). */
function toMs(v) {
  if (!v) return 0;
  if (typeof v === "number") return v;
  if (typeof v.toMillis === "function") return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (typeof v._seconds === "number") return v._seconds * 1000;
  if (typeof v.seconds === "number") return v.seconds * 1000;
  return 0;
}

const clean = (s) => String(s ?? "").trim().replace(/\s+/g, " ");
const slug = (s) => clean(s).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 60);

/** Firestore values → JSON for the app (Timestamps become millis). */
function plain(v) {
  if (v === null || v === undefined) return null;
  if (typeof v.toMillis === "function") return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (Array.isArray(v)) return v.map(plain);
  if (typeof v === "object") {
    // DocumentReference / GeoPoint etc. — not needed by the app.
    if (typeof v.path === "string" && typeof v.firestore === "object") return v.path;
    if (typeof v.latitude === "number" && typeof v.longitude === "number" && Object.keys(v).length <= 2) {
      return { latitude: v.latitude, longitude: v.longitude };
    }
    const out = {};
    for (const [k, x] of Object.entries(v)) out[k] = plain(x);
    return out;
  }
  return v;
}

/** 'high' | 'medium' | 'low' | null from a word or a 0–1 / 0–100 score. */
function confidenceLevel(raw) {
  if (raw === null || raw === undefined || raw === "") return null;
  if (typeof raw === "number" && Number.isFinite(raw)) {
    const p = raw > 1 ? raw / 100 : raw;
    return p >= 0.75 ? "high" : p >= 0.5 ? "medium" : "low";
  }
  const s = String(raw).trim().toLowerCase();
  if (["high", "medium", "low"].includes(s)) return s;
  const n = Number(s.replace("%", ""));
  return Number.isFinite(n) ? confidenceLevel(n) : null;
}

const UNKNOWN_RE = /^(unknown|unidentified|not sure|unsure|other|none|n\/a|-|\?+)$|unknown|unidentified|not sure/i;

/** A problem the farmer (or the photo ID) couldn't name with confidence. */
function isUnidentified(name, conf) {
  const n = clean(name);
  return !n || UNKNOWN_RE.test(n) || conf === "low";
}

/**
 * One pest / disease record from any of its four collections, normalised:
 *   { type, name, crop, stage, at, src, conf, plot, photo, intervention, legacy }
 * null for deleted or empty records.
 */
function issueRow(source, d) {
  if (!d || d.isDeleted === true) return null;
  let r;
  switch (source) {
    case "issues": // farmer_issues/{uid}/records
      r = {
        type: d.issueType === "disease" ? "disease" : "pest",
        name: d.issueName,
        crop: d.cropName,
        stage: d.cropStage,
        at: toMs(d.timestamp) || toMs(d.createdAt),
        src: d.source === "aiPhoto" ? "photo" : "manual",
        conf: confidenceLevel(d.aiConfidence),
        photo: !!d.photoUrl,
        intervention: d.interventionText,
      };
      break;
    case "diagnoses": // farmer_diagnoses/{uid}/records (photo ID)
      r = {
        type: d.issueType === "disease" ? "disease" : "pest",
        name: d.issueName || d.selectedName,
        crop: d.cropName,
        stage: d.cropStage,
        at: toMs(d.timestamp) || toMs(d.createdAt),
        src: "photo",
        conf: confidenceLevel(d.confidence),
        plot: d.plotId,
        photo: !!d.photoUrl,
        intervention: d.interventionText,
      };
      break;
    case "pests": // pestinterventiondata (legacy, still written)
      r = {
        type: "pest", name: d.pestName, crop: d.cropType, stage: d.cropStage,
        at: toMs(d.timestamp), src: "manual", conf: null, intervention: d.intervention, legacy: true,
      };
      break;
    case "diseases": // diseaseinterventiondata (legacy, still written)
      r = {
        type: "disease", name: d.diseaseName, crop: d.cropType, stage: d.cropStage,
        at: toMs(d.timestamp), src: "manual", conf: null, intervention: d.intervention, legacy: true,
      };
      break;
    default:
      return null;
  }
  r.name = clean(r.name);
  r.crop = clean(r.crop);
  r.stage = clean(r.stage);
  r.plot = r.plot ? String(r.plot) : null;
  r.intervention = clean(r.intervention).slice(0, 300) || null;
  r.unidentified = isUnidentified(r.name, r.conf);
  if (!r.at) return null;
  return r;
}

/**
 * Drops the second copy of records saved to both the unified and a legacy
 * collection (same farmer, type and name within two minutes). Rows need `f`.
 */
function dedupeIssues(rows) {
  const keyOf = (r) => `${r.f}|${r.type}|${r.name.toLowerCase()}`;
  const primary = new Map();
  for (const r of rows) {
    if (r.legacy) continue;
    const k = keyOf(r);
    if (!primary.has(k)) primary.set(k, []);
    primary.get(k).push(r.at);
  }
  const seen = new Set();
  return rows.filter((r) => {
    const exact = `${keyOf(r)}|${r.at}|${r.legacy ? "l" : "p"}`;
    if (seen.has(exact)) return false;
    seen.add(exact);
    if (!r.legacy) return true;
    return !(primary.get(keyOf(r)) || []).some((at) => Math.abs(at - r.at) <= DUPLICATE_WINDOW_MS);
  });
}

const withoutLegacy = (r) => {
  const out = { ...r };
  delete out.legacy;
  return out;
};

/** A field record (fielddata) as a plot row: crops, soil test and its bands. */
function plotRow(d) {
  if (!d) return null;
  const crops = (d.crops || [])
    .filter((c) => c && typeof c === "object" && clean(c.type))
    .map((c) => ({ type: clean(c.type), stage: clean(c.stage) }));
  const npk = {};
  for (const k of ["N", "P", "K"]) {
    const v = d.npk && Number(d.npk[k]);
    if (d.npk && d.npk[k] !== null && d.npk[k] !== undefined && Number.isFinite(v)) npk[k] = v;
  }
  const bands = {};
  for (const [k, v] of Object.entries(d.nutrientBands || {})) {
    if (["low", "moderate", "high"].includes(v)) bands[k] = v;
  }
  return {
    plot: clean(d.plotId) || "Plot",
    crops,
    npk,
    bands,
    area: Number.isFinite(Number(d.area)) && d.area !== null ? Number(d.area) : null,
    interventions: Array.isArray(d.interventions) ? d.interventions.length : 0,
    at: toMs(d.timestamp),
  };
}

/** Nutrients a field record marks Low (from nutrientBands saved by the app). */
function lowNutrients(d) {
  return ["N", "P", "K"].filter((k) => (d?.nutrientBands || {})[k] === "low");
}

/** A farmer activity (feed entry) for a pest / disease record. */
function activityFromIssue(uid, row) {
  if (!uid || !row) return null;
  const flags = [];
  if (row.unidentified) flags.push("unidentified");
  if (row.src === "photo") flags.push("photo");
  const what = row.unidentified
    ? `an unidentified ${row.type === "disease" ? "disease" : "pest"} problem`
    : row.name;
  return {
    id: `${uid}_${row.type}_${slug(row.name) || "unknown"}_${row.at}`,
    farmerUid: uid,
    kind: row.type,
    issueName: row.name || null,
    crop: row.crop || null,
    title: `reported ${what}${row.crop ? ` on ${row.crop}` : ""}`,
    detail: [
      row.stage && `Stage: ${row.stage}`,
      row.src === "photo" && `Photo ID${row.conf ? ` (${row.conf} confidence)` : ""}`,
      row.intervention && `Did: ${row.intervention}`,
    ].filter(Boolean).join(" · "),
    flags,
    notable: true,
    at: row.at,
  };
}

/**
 * A farmer activity for a field-record write: a new record (notable when a
 * nutrient is Low), or interventions added to an existing one.
 */
function activityFromFieldData(docId, before, after) {
  if (!after || !after.userId) return null;
  const uid = after.userId;
  const crops = (after.crops || []).map((c) => clean(c && c.type)).filter(Boolean);
  const crop = crops.join(", ") || null;
  const plot = clean(after.plotId) || "a plot";
  if (!before) {
    const low = lowNutrients(after);
    return {
      id: `fd_${docId}`,
      farmerUid: uid,
      kind: "field_record",
      crop,
      issueName: null,
      title: low.length
        ? `recorded ${plot}${crop ? ` (${crop})` : ""} — low in ${low.join(", ")}`
        : `added a field record for ${plot}${crop ? ` (${crop})` : ""}`,
      detail: low.length ? "Soil test below the crop's target" : "",
      flags: low.map((n) => `low_${n}`),
      notable: low.length > 0,
      at: toMs(after.timestamp) || Date.now(),
    };
  }
  const was = Array.isArray(before.interventions) ? before.interventions.length : 0;
  const now = Array.isArray(after.interventions) ? after.interventions.length : 0;
  if (now <= was) return null;
  const last = after.interventions[now - 1] || {};
  const what = clean(last.type || last.description || last.interventionType) || "a soil / field action";
  return {
    id: `fd_${docId}_i${now}`,
    farmerUid: uid,
    kind: "soil_action",
    crop,
    issueName: null,
    title: `logged ${what} on ${plot}`,
    detail: clean(last.product || last.notes || ""),
    flags: [],
    notable: false,
    at: Date.now(),
  };
}

/** Item keys that newly became "found" / "logged…" in an advisory response. */
function newResponseActions(before, after) {
  const was = (before && before.items) || {};
  const now = (after && after.items) || {};
  const out = [];
  for (const [key, v] of Object.entries(now)) {
    const val = String(v || "");
    const acted = val === "found" || val.startsWith("logged");
    if (acted && was[key] !== v) {
      const i = key.indexOf(":");
      const section = i > 0 ? key.slice(0, i) : "";
      const name = (i > 0 ? key.slice(i + 1) : key).split("@")[0];
      out.push({ key, section, name, value: val });
    }
  }
  return out;
}

function activityFromResponse(docId, response, actions, advice) {
  if (!response?.userId || !actions.length) return null;
  const found = actions.filter((a) => a.value === "found").map((a) => a.name);
  const logged = actions.filter((a) => a.value !== "found").map((a) => a.name);
  const parts = [];
  if (found.length) parts.push(`found ${found.join(", ")}`);
  if (logged.length) parts.push(`logged ${logged.join(", ")}`);
  return {
    id: `resp_${docId}_${slug(actions.map((a) => `${a.key}=${a.value}`).join("|")).slice(0, 80)}`,
    farmerUid: response.userId,
    kind: "advice_response",
    crop: null,
    issueName: found[0] || null,
    title: `acted on ${advice?.direct ? "your" : "verified"} advice: ${parts.join("; ")}`,
    detail: advice?.main ? `Advice: ${clean(advice.main).slice(0, 120)}` : "",
    flags: found.length ? ["found"] : [],
    notable: found.length > 0,
    at: Date.now(),
    adviceId: response.advisoryId || null,
  };
}

/** The inbox / push for one activity (farmer named — sharing farmers only). */
function activityNotification(a) {
  const where = [clean(a.ward), clean(a.county)].filter(Boolean).join(", ");
  const flagged = (a.flags || []).includes("unidentified") ? "Unidentified problem · " : "";
  return {
    title: `${a.farmerName || "A farmer"} ${a.title}`.slice(0, 140),
    body: [flagged + (where || "Location not set"), a.detail].filter(Boolean).join("\n"),
    channel: CHANNEL.farmerActivity,
    route: ROUTE.agronomistFarmer,
    type: "farmer_activity",
    severity: a.notable ? "high" : null,
    data: { farmerUid: a.farmerUid, kind: a.kind, activityId: a.id },
  };
}

/** Push this notable entry, or did this farmer get a push within the hour? */
function shouldPushFarmer(state, nowMs) {
  const last = toMs(state?.lastPushAt);
  return !last || nowMs - last >= FARMER_PUSH_COOLDOWN_MS;
}

/** The day's summary for agronomists; null when nothing happened. */
function digestSummary(activities) {
  if (!activities.length) return null;
  const farmers = new Set(activities.map((a) => a.farmerUid));
  const count = (pred) => activities.filter(pred).length;
  const top = (kind) => {
    const by = new Map();
    for (const a of activities.filter((x) => x.kind === kind && x.issueName && !(x.flags || []).includes("unidentified"))) {
      by.set(a.issueName, (by.get(a.issueName) || 0) + 1);
    }
    return [...by.entries()].sort((a, b) => b[1] - a[1]).slice(0, 2)
      .map(([n, c]) => (c > 1 ? `${n} ×${c}` : n));
  };
  const pests = count((a) => a.kind === "pest");
  const diseases = count((a) => a.kind === "disease");
  const unknown = count((a) => (a.flags || []).includes("unidentified"));
  const lowSoil = count((a) => (a.flags || []).some((f) => f.startsWith("low_")));
  const parts = [];
  if (pests) parts.push(`${pests} pest report${pests > 1 ? "s" : ""}${top("pest").length ? ` (${top("pest").join(", ")})` : ""}`);
  if (diseases) parts.push(`${diseases} disease report${diseases > 1 ? "s" : ""}${top("disease").length ? ` (${top("disease").join(", ")})` : ""}`);
  if (unknown) parts.push(`${unknown} unidentified problem${unknown > 1 ? "s" : ""}`);
  if (lowSoil) parts.push(`${lowSoil} plot${lowSoil > 1 ? "s" : ""} low in nutrients`);
  return {
    title: `Today on farms: ${activities.length} entr${activities.length > 1 ? "ies" : "y"} from ${farmers.size} farmer${farmers.size > 1 ? "s" : ""}`,
    body: parts.length ? parts.join(" · ") : "Field records and actions — nothing flagged.",
    channel: CHANNEL.farmerActivity,
    route: ROUTE.agronomistPanel,
    type: "farmer_digest",
    data: { tab: "activity" },
  };
}

/**
 * Does this farmer_advice write warrant a push? null | "new" | "updated".
 * Mirrors advisoryPushKind(): updates only notify when "Notify the farmer"
 * was ticked (notifyVersion == version).
 */
function adviceSendKind(before, after) {
  if (!after || after.status !== "sent") return null;
  if (!before || before.status !== "sent") return "new";
  if (before.version === after.version) return null;
  if (Number.isInteger(after.notifyVersion) &&
      after.notifyVersion === after.version &&
      after.notifyVersion !== before.notifyVersion) {
    return "updated";
  }
  return null;
}

/** The farmer's push for custom advice — opens the same action screen. */
function farmerAdviceNotification(a, kind) {
  const from = clean(a.sentByName) || "your Field Agronomist";
  const prefix = a.testOnly ? "TEST · " : "";
  const data = { advisoryId: a.__id || "", direct: "true", testOnly: a.testOnly ? "true" : "false" };
  const sections = advisorySections(a);
  if (sections.length) data.sections = sections.join(",");
  if ((a.crops || []).length) data.crops = a.crops.join(",");
  const checks = advisoryChecksLine(a);
  return {
    title: `${prefix}${kind === "updated" ? "Updated advice" : "Advice"} for you from ${from}`,
    body: `${clean(a.title) ? `${clean(a.title)}: ` : ""}${clean(a.main)}` + (checks ? `\n${checks}` : ""),
    channel: CHANNEL.advisories,
    route: ROUTE.advisory,
    type: "advisory",
    data,
  };
}

// ═════════════════════════════════════════════════════════════════════════════
//  Data access
// ═════════════════════════════════════════════════════════════════════════════

const db = () => getFirestore();

/** "agronomist" | "admin" | null — admins get the panel in test mode. */
async function callerRole(auth, isPlatformAdmin) {
  if (!auth) return null;
  if ((await db().doc(`Agronomists/${auth.uid}`).get()).exists) return "agronomist";
  if (await isPlatformAdmin(auth)) return "admin";
  return null;
}

/** Does this farmer share their records with agronomists? (missing = yes) */
async function isSharing(uid) {
  const s = await db().doc(`privacySettings/${uid}`).get();
  return !s.exists || s.data().shareWithAgronomists !== false;
}

async function optedOutUids() {
  const snap = await db().collection("privacySettings").where("shareWithAgronomists", "==", false).get();
  return new Set(snap.docs.map((d) => d.id));
}

async function agronomistUids() {
  return (await db().collection("Agronomists").get()).docs.map((d) => d.id);
}

/** Parent collection of a collection-group "records" document. */
const rootOf = (ref) => ref.parent?.parent?.parent?.id || "";

const insightsCache = new Map();

/**
 * Every farmer's records for the insights screen: pest / disease rows for
 * the last 2 × `days` (this period and the one before, for trends), the
 * latest soil test of each plot, and the farmers who share their records.
 */
async function loadInsights(days, nowMs = Date.now()) {
  const cached = insightsCache.get(days);
  if (cached && nowMs - cached.at < CACHE_MS) return cached.value;

  const since = Timestamp.fromMillis(nowMs - 2 * days * DAY_MS);
  const [users, optedOut, records, pests, diseases, fields] = await Promise.all([
    db().collection("Users").select("fullName", "county", "ward", "constituency", "isDisabled").get(),
    optedOutUids(),
    db().collectionGroup("records").where("timestamp", ">=", since).limit(MAX_ROWS).get(),
    db().collection("pestinterventiondata").where("timestamp", ">=", since).limit(MAX_ROWS).get(),
    db().collection("diseaseinterventiondata").where("timestamp", ">=", since).limit(MAX_ROWS).get(),
    db().collection("fielddata")
      .where("timestamp", ">=", Timestamp.fromMillis(nowMs - PLOT_WINDOW_MS))
      .orderBy("timestamp", "desc").limit(MAX_ROWS).get(),
  ]);

  const place = new Map();
  for (const u of users.docs) {
    const d = u.data();
    place.set(u.id, { county: clean(d.county), ward: clean(d.ward) });
  }
  // Farmers who don't share are counted, never named or identified.
  const who = (uid) => (optedOut.has(uid) ? null : uid);
  const located = (uid, row) => ({ ...row, f: uid, ...(place.get(uid) || { county: "", ward: "" }) });

  const raw = [];
  for (const d of records.docs) {
    const root = rootOf(d.ref);
    const source = root === "farmer_issues" ? "issues" : root === "farmer_diagnoses" ? "diagnoses" : null;
    if (!source) continue;
    const uid = d.ref.parent.parent.id;
    const r = issueRow(source, d.data());
    if (r) raw.push(located(uid, r));
  }
  for (const [snap, source] of [[pests, "pests"], [diseases, "diseases"]]) {
    for (const d of snap.docs) {
      const data = d.data();
      const r = issueRow(source, data);
      if (r && data.userId) raw.push(located(data.userId, r));
    }
  }
  const issues = dedupeIssues(raw).map((r) => {
    const rest = withoutLegacy(r);
    if (!who(r.f)) return { ...rest, f: null, ward: "", intervention: null };
    return rest;
  });

  // Latest record per farmer + plot.
  const latest = new Map();
  for (const d of fields.docs) {
    const data = d.data();
    if (!data.userId) continue;
    const k = `${data.userId}|${clean(data.plotId)}`;
    if (!latest.has(k)) latest.set(k, { uid: data.userId, data });
  }
  const plots = [...latest.values()].map(({ uid, data }) => {
    const r = plotRow(data);
    const p = place.get(uid) || { county: "", ward: "" };
    return who(uid)
      ? { ...r, f: uid, county: p.county, ward: p.ward }
      : { ...r, f: null, county: p.county, ward: "", plot: "" };
  });

  const farmers = users.docs
    .filter((u) => !optedOut.has(u.id) && u.data().isDisabled !== true)
    .map((u) => {
      const d = u.data();
      return {
        uid: u.id,
        name: clean(d.fullName) || "Farmer",
        county: clean(d.county),
        ward: clean(d.ward),
        constituency: clean(d.constituency),
      };
    });

  const value = {
    generatedAt: nowMs,
    days,
    issues,
    plots,
    farmers,
    totals: { farmers: users.size, sharing: users.size - optedOut.size, optedOut: optedOut.size },
    truncated: [records, pests, diseases, fields].some((s) => s.size >= MAX_ROWS),
  };
  insightsCache.set(days, { at: nowMs, value });
  return value;
}

/** One farmer's full record for the agronomist (sharing farmers only). */
async function loadFarmer(uid) {
  const user = await db().doc(`Users/${uid}`).get();
  if (!user.exists) throw new HttpsError("not-found", "This farmer's account no longer exists.");
  if (!(await isSharing(uid))) {
    throw new HttpsError("failed-precondition", "This farmer has chosen not to share their farm records.");
  }
  const safe = (p) => p.catch((e) => {
    console.warn(`[agronomistData] farmer ${uid}: ${e.message}`);
    return { docs: [] };
  });
  const [fields, issues, diagnoses, pests, diseases, advice, responses, stations, costs] = await Promise.all([
    safe(db().collection("fielddata").where("userId", "==", uid).orderBy("timestamp", "desc").limit(200).get()),
    safe(db().collection(`farmer_issues/${uid}/records`).limit(400).get()),
    safe(db().collection(`farmer_diagnoses/${uid}/records`).limit(400).get()),
    safe(db().collection("pestinterventiondata").where("userId", "==", uid).limit(400).get()),
    safe(db().collection("diseaseinterventiondata").where("userId", "==", uid).limit(400).get()),
    safe(db().collection("farmer_advice").where("farmerUid", "==", uid).limit(200).get()),
    safe(db().collection("advisoryResponses").where("userId", "==", uid).limit(300).get()),
    safe(db().collection("stationAssignments").where("uid", "==", uid).get()),
    safe(db().collection("field_costs").where("userId", "==", uid).limit(1000).get()),
  ]);

  const rows = [];
  const add = (snap, source) => {
    for (const d of snap.docs) {
      const data = d.data();
      const r = issueRow(source, data);
      if (!r) continue;
      rows.push({
        ...r,
        f: uid,
        id: d.id,
        photoUrl: data.photoUrl || null,
        description: clean(data.aiDescription || data.description).slice(0, 600) || null,
        recommendation: clean(data.aiRecommendation || data.recommendation).slice(0, 600) || null,
        dosage: data.dosage ?? null,
        dosageUnit: data.dosageUnit || data.unit || null,
        area: data.area ?? null,
        areaUnit: data.areaUnit || null,
        cycle: data.cycle || null,
      });
    }
  };
  add(issues, "issues");
  add(diagnoses, "diagnoses");
  add(pests, "pests");
  add(diseases, "diseases");

  const costByCategory = {};
  let costTotal = 0;
  for (const d of costs.docs) {
    const c = d.data();
    const amount = Number(c.amount) || 0;
    costTotal += amount;
    const cat = clean(c.category) || "Other";
    costByCategory[cat] = (costByCategory[cat] || 0) + amount;
  }

  const u = user.data();
  const gateways = stations.docs.map((d) => d.data().gatewayId).filter(Boolean);
  const labels = gateways.length
    ? await db().getAll(...gateways.map((g) => db().doc(`weatherStations/${g}`)))
    : [];

  return {
    profile: {
      uid,
      name: clean(u.fullName) || "Farmer",
      county: clean(u.county),
      constituency: clean(u.constituency),
      ward: clean(u.ward),
      phone: clean(u.phoneNumber),
      email: clean(u.email),
      joinedAt: toMs(u.createdAt) || null,
    },
    fieldRecords: fields.docs.map((d) => ({ id: d.id, ...plain(d.data()) })),
    issues: dedupeIssues(rows).sort((a, b) => b.at - a.at).map(withoutLegacy),
    advice: advice.docs.map((d) => ({ id: d.id, ...plain(d.data()) })),
    responses: responses.docs.map((d) => ({ id: d.id, ...plain(d.data()) })),
    stations: labels.map((s, i) => ({ id: gateways[i], name: (s.exists && clean(s.data().label || s.data().name)) || gateways[i] })),
    costs: { total: costTotal, byCategory: costByCategory, entries: costs.docs.length },
  };
}

// ═════════════════════════════════════════════════════════════════════════════
//  Activity feed + notifications
// ═════════════════════════════════════════════════════════════════════════════

/** Reserves this hour's push for a farmer; false when one already went out. */
async function claimPushSlot(farmerUid, nowMs) {
  const ref = db().collection("agronomistPushState").doc(farmerUid);
  return db().runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if (!shouldPushFarmer(s.exists ? s.data() : null, nowMs)) return false;
    tx.set(ref, { lastPushAt: Timestamp.fromMillis(nowMs) });
    return true;
  });
}

/**
 * Saves an activity to the feed (once — the same record written to two
 * collections has one id) and tells the agronomists: inbox always, phone
 * push when notable and the farmer hasn't triggered one this hour.
 * `to` limits it to some agronomists (e.g. the one who sent the advice).
 */
async function recordActivity(act, { to = null, nowMs = Date.now() } = {}) {
  if (!act || !act.farmerUid) return null;
  if (!(await isSharing(act.farmerUid))) return null;
  const user = await db().doc(`Users/${act.farmerUid}`).get();
  const u = user.exists ? user.data() : {};
  const entry = {
    ...act,
    farmerName: clean(u.fullName) || "A farmer",
    county: clean(u.county),
    ward: clean(u.ward),
    at: Timestamp.fromMillis(act.at || nowMs),
    createdAt: FieldValue.serverTimestamp(),
  };
  try {
    await db().collection("farmerActivity").doc(act.id).create(entry);
  } catch (e) {
    if (e.code === 6 || /already exists/i.test(e.message || "")) return null; // duplicate write
    throw e;
  }
  const recipients = (to || (await agronomistUids())).filter((x) => x && x !== act.farmerUid);
  if (!recipients.length) return entry;
  const push = act.notable === true && (await claimPushSlot(act.farmerUid, nowMs));
  await deliverToUsers(recipients, activityNotification(entry), { push });
  return entry;
}

// ═════════════════════════════════════════════════════════════════════════════
//  Cloud Functions
// ═════════════════════════════════════════════════════════════════════════════

function createAgronomistFunctions({ isPlatformAdmin }) {
  const agronomistData = onCall(
    { timeoutSeconds: 120, memory: "1GiB", maxInstances: 10 },
    async (request) => {
      const role = await callerRole(request.auth, isPlatformAdmin);
      if (!role) throw new HttpsError("permission-denied", "Only Field Agronomists can see farmers' records.");
      const { action, days, farmerUid } = request.data || {};
      if (action === "insights") {
        const d = INSIGHT_DAYS.includes(Number(days)) ? Number(days) : 30;
        return loadInsights(d);
      }
      if (action === "farmer") {
        if (typeof farmerUid !== "string" || !farmerUid || farmerUid.includes("/")) {
          throw new HttpsError("invalid-argument", "farmerUid is required.");
        }
        const out = await loadFarmer(farmerUid);
        await db().collection("agronomistAccessLog").add({
          by: request.auth.uid,
          role,
          farmerUid,
          action: "view_records",
          at: FieldValue.serverTimestamp(),
        });
        return out;
      }
      throw new HttpsError("invalid-argument", `Unknown action '${action}'`);
    }
  );

  const fromIssue = (source) => async (event) => {
    const d = event.data?.data();
    const uid = event.params.uid || d?.userId;
    await recordActivity(activityFromIssue(uid, issueRow(source, d)));
  };
  const onFarmerIssueRecord = onDocumentCreated({ document: "farmer_issues/{uid}/records/{id}", ...TRIGGER_OPTS }, fromIssue("issues"));
  const onFarmerDiagnosis = onDocumentCreated({ document: "farmer_diagnoses/{uid}/records/{id}", ...TRIGGER_OPTS }, fromIssue("diagnoses"));
  const onPestRecord = onDocumentCreated({ document: "pestinterventiondata/{id}", ...TRIGGER_OPTS }, fromIssue("pests"));
  const onDiseaseRecord = onDocumentCreated({ document: "diseaseinterventiondata/{id}", ...TRIGGER_OPTS }, fromIssue("diseases"));

  const onFieldRecord = onDocumentWritten({ document: "fielddata/{id}", ...TRIGGER_OPTS }, async (event) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    await recordActivity(activityFromFieldData(event.params.id, before, after));
  });

  // A farmer finds a pest / disease or logs an action from advice. Custom
  // advice → the agronomist who sent it; verified advice → every agronomist.
  const onAdviceResponse = onDocumentWritten({ document: "advisoryResponses/{id}", ...TRIGGER_OPTS }, async (event) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    const actions = newResponseActions(before, after);
    if (!after || !actions.length || !after.advisoryId) return;
    const direct = await db().doc(`farmer_advice/${after.advisoryId}`).get();
    let advice = null;
    let to = null;
    if (direct.exists) {
      advice = { ...direct.data(), direct: true };
      if (advice.testOnly) return;
      to = [advice.sentBy || advice.createdBy].filter(Boolean);
    } else {
      const general = await db().doc(`agronomic_advisories/${after.advisoryId}`).get();
      if (general.exists) advice = general.data();
      if (advice?.testOnly) return;
    }
    await recordActivity(activityFromResponse(event.params.id, after, actions, advice), { to });
  });

  const onFarmerAdviceSent = onDocumentWritten({ document: "farmer_advice/{id}", ...TRIGGER_OPTS }, async (event) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    const kind = adviceSendKind(before, after);
    if (!kind) return;
    const advice = { ...after, __id: event.params.id };
    // Admin TEST advice goes to the admin only, never to the farmer.
    const to = advice.testOnly ? advice.sentBy : advice.farmerUid;
    if (!to) return;
    if (!advice.testOnly && !(await isSharing(advice.farmerUid))) return;
    await deliverToUsers([to], farmerAdviceNotification(advice, kind));
    console.log(`[onFarmerAdviceSent] ${advice.__id} ${kind} → ${advice.testOnly ? "admin (test)" : "farmer"}`);
  });

  // Sharing turned off → the farmer disappears from the live feed too.
  const onPrivacyChanged = onDocumentWritten({ document: "privacySettings/{uid}", ...TRIGGER_OPTS }, async (event) => {
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after || after.shareWithAgronomists !== false) return;
    const snap = await db().collection("farmerActivity").where("farmerUid", "==", event.params.uid).get();
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db().batch();
      snap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
    insightsCache.clear();
  });

  const agronomistDailyDigest = onSchedule(
    { schedule: "0 18 * * *", timeZone: "Africa/Nairobi", timeoutSeconds: 300, memory: "256MiB", maxInstances: 1 },
    async () => {
      const since = Timestamp.fromMillis(Date.now() - DAY_MS);
      const snap = await db().collection("farmerActivity").where("createdAt", ">=", since).get();
      const n = digestSummary(snap.docs.map((d) => d.data()));
      if (!n) return;
      const to = await agronomistUids();
      if (to.length) await deliverToUsers(to, n);
      console.log(`[agronomistDailyDigest] ${snap.size} entries → ${to.length} agronomist(s)`);
    }
  );

  return {
    agronomistData,
    onFarmerIssueRecord,
    onFarmerDiagnosis,
    onPestRecord,
    onDiseaseRecord,
    onFieldRecord,
    onAdviceResponse,
    onFarmerAdviceSent,
    onPrivacyChanged,
    agronomistDailyDigest,
  };
}

module.exports = {
  createAgronomistFunctions,
  // exported for tests
  toMs,
  plain,
  confidenceLevel,
  isUnidentified,
  issueRow,
  dedupeIssues,
  plotRow,
  lowNutrients,
  activityFromIssue,
  activityFromFieldData,
  newResponseActions,
  activityFromResponse,
  activityNotification,
  shouldPushFarmer,
  digestSummary,
  adviceSendKind,
  farmerAdviceNotification,
  recordActivity,
  loadInsights,
  loadFarmer,
};
