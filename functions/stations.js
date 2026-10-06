// functions/stations.js
//
// Weather-station registry + station providers, managed from the Admin panel
// (lib/screens/admin/weather_stations_admin_screen.dart) instead of code.
//
// Firestore (server + admins only — clients never read these directly):
//   weatherStations/{gatewayId}
//     label        — the name shown everywhere in the app (admin-entered)
//     providerId   — "nuasense" (built-in) or a stationProviders id
//     notes, createdAt/By, updatedAt/By
//     lat / lon / deviceName — what the provider reports; kept for backend
//                    identification only, never shown to farmers
//   stationProviders/{providerId}   name, baseUrl, authStyle, notes, active
//   stationProviderSecrets/{providerId}  apiKey (written here, never returned)
//   stationAssignments/{gatewayId}_{uid}  (see index.js getNuaSenseData)
//
// A "provider" is any station account with the same partner API as
// NuaSense (GET /stations, /weather, /derived …): a base URL + an API key.
// The built-in NuaSense account keeps its key in Secret Manager
// (NUASENSE_KEY); keys for providers added from the UI are stored in
// stationProviderSecrets, which only the functions (and admins, via the
// rules' admin catch-all) can read. The app never receives a key.
//
// Admin actions — callable `manageWeatherStations({ action, ... })`:
//   overview         providers + every station (provider listings ∪ registry
//                    ∪ assignments) with label, status and connected farmers
//   saveStation      register / relabel a station (gatewayId, label, providerId, notes)
//   removeStation    delete its registration and all its assignments
//   assign           connect an account (farmer, agronomist or admin) to a
//                    station. An account can hold several stations; its others
//                    are kept unless replaceOtherStations is set. Which farm
//                    uses which station is the FARMER's choice, saved in
//                    stationPreferences/{uid} { plots: { plotId: gatewayId } }
//                    — the overview shows it, the admin doesn't set it.
//   unassign         disconnect a farmer from a station
//   saveProvider     add / edit a provider (key optional when editing)
//   testProvider     call GET /stations with the given details
//   removeProvider   only when no station uses it
//   searchUsers      farmers by name / email / phone
// Every change is logged to admin_logs.

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const BUILTIN_PROVIDER = "nuasense";
const PROVIDER_ID_RE = /^[a-z0-9][a-z0-9_-]{1,39}$/;
const GATEWAY_RE = /^[A-Za-z0-9:_.-]{2,64}$/;
const AUTH_STYLES = ["bearer", "x-api-key", "query"];

// ── Pure helpers (unit-tested) ───────────────────────────────────────────────

/** "-0.3912, 36.9601" and similar — coordinates, not a name. */
function looksLikeCoords(s) {
  return /^\s*\(?\s*-?\d{1,3}(\.\d+)?\s*°?\s*[NSns]?\s*[,;/ ]\s*-?\d{1,3}(\.\d+)?\s*°?\s*[EWew]?\s*\)?\s*$/
    .test(String(s ?? ""));
}

/**
 * What farmers see for a station: the admin's label; else the provider's
 * name if it is a real name; else "Weather station ABCD" (never coordinates).
 */
function stationDisplayName(raw, label, gatewayId) {
  if (label && String(label).trim()) return String(label).trim();
  const n = String(raw?.name ?? raw?.location ?? "").trim();
  if (n && !looksLikeCoords(n) && n.toLowerCase() !== "station") return n;
  return `Weather station ${String(gatewayId ?? "").slice(-4).toUpperCase()}`;
}

/** The id NuaSense-style listings use for a station. */
const gatewayOf = (s) => String(s?.gateway_id ?? s?.id ?? "");

/** Request URL + headers for a provider call (key never logged). */
function providerRequest(p, endpoint, params = {}) {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) qs.set(k, String(v));
  const headers = { Accept: "application/json" };
  if (p.authStyle === "x-api-key") headers["X-API-Key"] = p.key;
  else if (p.authStyle === "query") qs.set("api_key", p.key);
  else headers.Authorization = `Bearer ${p.key}`;
  const q = qs.toString();
  return { url: `${String(p.baseUrl).replace(/\/+$/, "")}/${endpoint}${q ? `?${q}` : ""}`, headers };
}

function slug(s) {
  return String(s ?? "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40);
}

function validateProviderInput(d, { isNew }) {
  const name = String(d?.name ?? "").trim();
  const baseUrl = String(d?.baseUrl ?? "").trim();
  const authStyle = String(d?.authStyle ?? "bearer");
  const apiKey = String(d?.apiKey ?? "").trim();
  if (name.length < 2 || name.length > 80) throw new HttpsError("invalid-argument", "Give the provider a name (2–80 characters).");
  if (!/^https:\/\/[^\s/$.?#].[^\s]*$/i.test(baseUrl) || baseUrl.length > 300) {
    throw new HttpsError("invalid-argument", "The base URL must start with https://");
  }
  if (!AUTH_STYLES.includes(authStyle)) throw new HttpsError("invalid-argument", "Unknown authentication style.");
  if (isNew && apiKey.length < 8) throw new HttpsError("invalid-argument", "Enter the provider's API key.");
  if (apiKey.length > 500) throw new HttpsError("invalid-argument", "That API key is too long.");
  return { name, baseUrl, authStyle, apiKey, notes: String(d?.notes ?? "").trim().slice(0, 500) };
}

// ── Registry ─────────────────────────────────────────────────────────────────

function createStationRegistry({ NUASENSE_KEY, NUASENSE_BASE }) {
  const db = () => getFirestore();

  /** Provider details incl. its key (server-side only). */
  async function provider(id) {
    if (!id || id === BUILTIN_PROVIDER) {
      return {
        id: BUILTIN_PROVIDER, name: "NuaSense", baseUrl: NUASENSE_BASE,
        authStyle: "bearer", key: NUASENSE_KEY.value(), builtIn: true,
      };
    }
    const [meta, secret] = await Promise.all([
      db().doc(`stationProviders/${id}`).get(),
      db().doc(`stationProviderSecrets/${id}`).get(),
    ]);
    if (!meta.exists || meta.data().active === false) {
      throw new HttpsError("failed-precondition", "This station's provider is not set up.");
    }
    return { id, ...meta.data(), key: secret.exists ? String(secret.data().apiKey ?? "") : "" };
  }

  /** weatherStations docs for [gatewayIds] → Map(gatewayId → data). */
  async function stationMeta(gatewayIds) {
    const ids = [...new Set(gatewayIds)].filter((g) => GATEWAY_RE.test(g));
    const out = new Map();
    for (let i = 0; i < ids.length; i += 100) {
      const snaps = await db().getAll(...ids.slice(i, i + 100).map((g) => db().doc(`weatherStations/${g}`)));
      snaps.forEach((s) => { if (s.exists) out.set(s.id, s.data()); });
    }
    return out;
  }

  /** GET a provider endpoint; throws HttpsError on failure. */
  async function call(p, endpoint, params) {
    const { url, headers } = providerRequest(p, endpoint, params);
    const res = await fetch(url, { headers });
    console.log(`[stations] ${p.id} ${endpoint} → HTTP ${res.status} | daily remaining: ` +
      `${res.headers.get("X-Daily-Remaining") ?? "?"} / ${res.headers.get("X-Daily-Limit") ?? "?"}`);
    if (res.status === 429) {
      throw new HttpsError("resource-exhausted",
        `Station provider rate limit hit. Retry after ${res.headers.get("Retry-After") ?? "60"}s`);
    }
    if (res.status === 401 || res.status === 403) {
      throw new HttpsError("unauthenticated", "The station provider rejected the API key.");
    }
    if (!res.ok) {
      const body = await res.text();
      throw new HttpsError("internal", `Station provider returned HTTP ${res.status}: ${body.slice(0, 200)}`);
    }
    return res.json();
  }

  /** Call [endpoint] for one station through whichever provider it uses. */
  async function callForStation(gatewayId, endpoint, params = {}) {
    const meta = (await stationMeta([gatewayId])).get(gatewayId);
    const p = await provider(meta?.providerId);
    return call(p, endpoint, { ...params, gateway_id: gatewayId });
  }

  /** Full /stations listing of a provider ([] when it can't be reached). */
  async function listing(p) {
    try {
      const data = await call(p, "stations", {});
      return data.stations || data.data || [];
    } catch (e) {
      console.warn(`[stations] listing ${p.id}: ${e.message}`);
      return null;
    }
  }

  /**
   * The given stations as the app sees them: label as `name`, provider
   * status; coordinates kept (backend use) but the name never is one.
   */
  async function describe(gatewayIds) {
    const meta = await stationMeta(gatewayIds);
    const byProvider = new Map();
    for (const g of gatewayIds) {
      const pid = meta.get(g)?.providerId || BUILTIN_PROVIDER;
      if (!byProvider.has(pid)) byProvider.set(pid, []);
      byProvider.get(pid).push(g);
    }
    const out = [];
    for (const [pid, ids] of byProvider) {
      let rows = [];
      try {
        rows = (await listing(await provider(pid))) || [];
      } catch (_) { /* provider removed — still list the stations */ }
      for (const g of ids) {
        const raw = rows.find((s) => gatewayOf(s) === g) || {};
        const m = meta.get(g) || {};
        out.push({
          ...raw,
          gateway_id: g,
          name: stationDisplayName(raw, m.label, g),
          label: m.label || null,
          provider_id: pid,
          lat: raw.lat ?? raw.latitude ?? m.lat ?? null,
          lon: raw.lon ?? raw.longitude ?? m.lon ?? null,
        });
      }
    }
    return out;
  }

  return { provider, stationMeta, call, callForStation, listing, describe };
}

// ── Admin callable ───────────────────────────────────────────────────────────

function createStationAdminFunction({ registry, isPlatformAdmin, PLATFORM, NUASENSE_KEY, notifyUser }) {
  const db = () => getFirestore();

  async function log(adminUid, action) {
    await db().collection("admin_logs").add({ action, adminUid, timestamp: new Date() }).catch(() => {});
  }

  async function userLite(uids) {
    const out = new Map();
    const ids = [...new Set(uids)].filter(Boolean);
    for (let i = 0; i < ids.length; i += 100) {
      const snaps = await db().getAll(...ids.slice(i, i + 100).map((u) => db().doc(`Users/${u}`)));
      snaps.forEach((s) => {
        const d = s.exists ? s.data() : {};
        out.set(s.id, {
          uid: s.id,
          name: d.fullName || d.name || "",
          email: d.email || "",
          phone: d.phoneNumber || d.phone || "",
          county: d.county || "",
          exists: s.exists,
        });
      });
    }
    return out;
  }

  async function providersList() {
    const snap = await db().collection("stationProviders").get();
    const secrets = await db().collection("stationProviderSecrets").get();
    const hasKey = new Set(secrets.docs.filter((d) => String(d.data().apiKey || "").length > 0).map((d) => d.id));
    return [
      { id: BUILTIN_PROVIDER, name: "NuaSense", baseUrl: null, authStyle: "bearer", builtIn: true, hasKey: true, active: true, notes: "Built in · key kept in Secret Manager" },
      ...snap.docs.map((d) => ({
        id: d.id, name: d.data().name, baseUrl: d.data().baseUrl, authStyle: d.data().authStyle || "bearer",
        notes: d.data().notes || "", active: d.data().active !== false, builtIn: false, hasKey: hasKey.has(d.id),
      })),
    ];
  }

  /** KM assignments (docs missing `platform` count as KM, like getNuaSenseData). */
  async function kmAssignments(query = db().collection("stationAssignments")) {
    const snap = await query.get();
    return snap.docs.filter((d) => (d.data().platform ?? PLATFORM) === PLATFORM);
  }

  /** Admins and Field Agronomists — every station, but in the Agronomist panel only. */
  async function panelAccess() {
    const [admins, agronomists] = await Promise.all([
      db().collection("Admins").get(),
      db().collection("Agronomists").get(),
    ]);
    const roles = new Map();
    admins.docs.forEach((d) => roles.set(d.id, ["Admin"]));
    agronomists.docs.forEach((d) => roles.set(d.id, [...(roles.get(d.id) || []), "Field Agronomist"]));
    const users = await userLite([...roles.keys()]);
    return [...roles].map(([uid, r]) => ({ ...(users.get(uid) || { uid }), roles: r }));
  }

  async function overview() {
    const providers = await providersList();
    const [registered, assignmentDocs, panel] = await Promise.all([
      db().collection("weatherStations").get(),
      kmAssignments(),
      panelAccess(),
    ]);
    const meta = new Map(registered.docs.map((d) => [d.id, d.data()]));
    const assigned = new Map();
    const assignments = { docs: assignmentDocs };
    for (const a of assignments.docs.map((d) => d.data())) {
      if (!assigned.has(a.gatewayId)) assigned.set(a.gatewayId, []);
      assigned.get(a.gatewayId).push(a);
    }
    const users = await userLite(assignments.docs.map((d) => d.data().uid));
    // The farms each account chose for its stations (farmer-owned choices).
    const prefs = new Map();
    const prefUids = [...new Set(assignments.docs.map((d) => d.data().uid))].filter(Boolean);
    for (let i = 0; i < prefUids.length; i += 100) {
      const snaps = await db().getAll(...prefUids.slice(i, i + 100).map((u) => db().doc(`stationPreferences/${u}`)));
      snaps.forEach((s) => prefs.set(s.id, s.exists ? (s.data().plots || {}) : {}));
    }

    // What each provider account reports.
    const listed = new Map(); // gatewayId → { raw, providerId }
    const providerStatus = {};
    for (const p of providers.filter((x) => x.active)) {
      let full;
      try {
        full = await registry.provider(p.id);
      } catch (_) {
        providerStatus[p.id] = "not set up";
        continue;
      }
      const rows = await registry.listing(full);
      providerStatus[p.id] = rows === null ? "unreachable" : `${rows.length} station(s)`;
      for (const r of rows || []) listed.set(gatewayOf(r), { raw: r, providerId: p.id });
    }

    const ids = new Set([...listed.keys(), ...meta.keys(), ...assigned.keys()]);
    const stations = [...ids].filter(Boolean).map((g) => {
      const m = meta.get(g) || {};
      const l = listed.get(g);
      const raw = l?.raw || {};
      const providerId = m.providerId || l?.providerId || BUILTIN_PROVIDER;
      return {
        gatewayId: g,
        label: m.label || null,
        displayName: stationDisplayName(raw, m.label, g),
        providerId,
        providerName: providers.find((p) => p.id === providerId)?.name || providerId,
        registered: meta.has(g),
        listedByProvider: !!l,
        online: raw.online === true || raw.status === "online",
        lastSeen: raw.last_seen || null,
        notes: m.notes || "",
        // Backend identification only (shown under "Technical details").
        deviceName: raw.name || raw.location || null,
        lat: raw.lat ?? raw.latitude ?? null,
        lon: raw.lon ?? raw.longitude ?? null,
        farmers: (assigned.get(g) || []).map((a) => ({
          ...(users.get(a.uid) || { uid: a.uid, name: "", email: "", phone: "" }),
          farms: Object.entries(prefs.get(a.uid) || {}).filter(([, gw]) => gw === g).map(([plot]) => plot),
          assignedAt: a.assignedAt?.toDate ? a.assignedAt.toDate().toISOString() : null,
        })),
      };
    }).sort((a, b) => a.displayName.localeCompare(b.displayName));
    return {
      providers: providers.map((p) => ({ ...p, status: providerStatus[p.id] || "inactive" })),
      stations,
      panelAccess: panel,
    };
  }

  async function saveStation(admin, d) {
    const gatewayId = String(d?.gatewayId ?? "").trim();
    const label = String(d?.label ?? "").trim();
    const providerId = String(d?.providerId || BUILTIN_PROVIDER);
    if (!GATEWAY_RE.test(gatewayId)) throw new HttpsError("invalid-argument", "Enter the station's gateway ID (letters, numbers, : _ . -).");
    if (label.length < 2 || label.length > 60) throw new HttpsError("invalid-argument", "Give the station a name (2–60 characters).");
    if (providerId !== BUILTIN_PROVIDER && !(await db().doc(`stationProviders/${providerId}`).get()).exists) {
      throw new HttpsError("invalid-argument", "Unknown station provider.");
    }
    const ref = db().doc(`weatherStations/${gatewayId}`);
    const existing = await ref.get();
    await ref.set({
      gatewayId, label, providerId,
      notes: String(d?.notes ?? "").trim().slice(0, 500),
      updatedAt: FieldValue.serverTimestamp(), updatedBy: admin,
      ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp(), createdBy: admin }),
    }, { merge: true });
    await log(admin, `${existing.exists ? "Renamed" : "Registered"} weather station "${label}" (${gatewayId})`);
    return { ok: true };
  }

  async function removeStation(admin, d) {
    const gatewayId = String(d?.gatewayId ?? "");
    if (!GATEWAY_RE.test(gatewayId)) throw new HttpsError("invalid-argument", "Unknown station.");
    const docs = await kmAssignments(db().collection("stationAssignments").where("gatewayId", "==", gatewayId));
    const batch = db().batch();
    docs.forEach((doc) => batch.delete(doc.ref));
    batch.delete(db().doc(`weatherStations/${gatewayId}`));
    await batch.commit();
    await log(admin, `Removed weather station ${gatewayId} and ${docs.length} farmer connection(s)`);
    return { ok: true, disconnected: docs.length };
  }

  async function assign(admin, d) {
    const gatewayId = String(d?.gatewayId ?? "").trim();
    const uid = String(d?.uid ?? "").trim();
    if (!GATEWAY_RE.test(gatewayId) || !uid) throw new HttpsError("invalid-argument", "Pick a station and an account.");
    const user = (await userLite([uid])).get(uid);
    if (!user?.exists) throw new HttpsError("not-found", "That account doesn't exist.");
    const replaceOthers = d?.replaceOtherStations === true || d?.keepOtherStations === false;
    const stationRef = db().doc(`weatherStations/${gatewayId}`);
    const station = await stationRef.get();
    const batch = db().batch();
    if (!station.exists) {
      // Connecting an unregistered (provider-listed) station registers it.
      batch.set(stationRef, {
        gatewayId, label: String(d?.label ?? "").trim() || null, providerId: String(d?.providerId || BUILTIN_PROVIDER),
        notes: "", createdAt: FieldValue.serverTimestamp(), createdBy: admin,
        updatedAt: FieldValue.serverTimestamp(), updatedBy: admin,
      });
    }
    // Exactly one record per account + station (old-style doc ids go). The
    // account's OTHER stations stay — accounts can have several farms —
    // unless the admin chose to replace them.
    const theirs = await kmAssignments(db().collection("stationAssignments").where("uid", "==", uid));
    const already = theirs.some((doc) => doc.data().gatewayId === gatewayId);
    theirs.forEach((doc) => {
      if (doc.id === `${gatewayId}_${uid}`) return;
      if (doc.data().gatewayId === gatewayId || replaceOthers) batch.delete(doc.ref);
    });
    batch.set(db().doc(`stationAssignments/${gatewayId}_${uid}`), {
      gatewayId, uid, platform: PLATFORM,
      assignedAt: new Date(), assignedBy: admin,
    });
    await batch.commit();
    const label = stationDisplayName({}, station.data()?.label || d?.label, gatewayId);
    if (!already) await log(admin, `Connected ${user.name || user.email || uid} to weather station "${label}"`);
    if (notifyUser && !already) {
      await notifyUser(uid, {
        title: "Your farm is connected to a weather station",
        body: `${label} now sends live conditions, alerts and advice for your farm.`,
        gatewayId,
      }).catch((e) => console.warn(`[stations] notify ${uid}: ${e.message}`));
    }
    return { ok: true };
  }

  async function unassign(admin, d) {
    const gatewayId = String(d?.gatewayId ?? "");
    const uid = String(d?.uid ?? "");
    if (!GATEWAY_RE.test(gatewayId) || !uid) throw new HttpsError("invalid-argument", "Pick a station and an account.");
    // Every record linking this farmer to this station, whatever its doc id,
    // so access really ends (getNuaSenseData looks them up by uid).
    const linking = () => kmAssignments(db().collection("stationAssignments")
      .where("uid", "==", uid).where("gatewayId", "==", gatewayId));
    const batch = db().batch();
    (await linking()).forEach((doc) => batch.delete(doc.ref));
    batch.delete(db().doc(`stationAssignments/${gatewayId}_${uid}`));
    await batch.commit();
    if ((await linking()).length) {
      throw new HttpsError("internal", "The farmer is still connected — please try again.");
    }
    await log(admin, `Disconnected ${uid} from weather station ${gatewayId}`);
    return { ok: true };
  }

  async function saveProvider(admin, d) {
    const isNew = !d?.id;
    const v = validateProviderInput(d, { isNew });
    const id = isNew ? slug(v.name) : String(d.id);
    if (!PROVIDER_ID_RE.test(id) || id === BUILTIN_PROVIDER) throw new HttpsError("invalid-argument", "Choose a different provider name.");
    const ref = db().doc(`stationProviders/${id}`);
    const existing = await ref.get();
    if (isNew && existing.exists) throw new HttpsError("already-exists", "A provider with that name already exists.");
    if (!isNew && !existing.exists) throw new HttpsError("not-found", "Unknown provider.");
    await ref.set({
      name: v.name, baseUrl: v.baseUrl, authStyle: v.authStyle, notes: v.notes, active: d?.active !== false,
      updatedAt: FieldValue.serverTimestamp(), updatedBy: admin,
      ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp(), createdBy: admin }),
    }, { merge: true });
    if (v.apiKey) {
      await db().doc(`stationProviderSecrets/${id}`).set({ apiKey: v.apiKey, updatedAt: FieldValue.serverTimestamp(), updatedBy: admin });
    }
    await log(admin, `${isNew ? "Added" : "Updated"} weather station provider "${v.name}"${v.apiKey ? " (key set)" : ""}`);
    return { ok: true, id };
  }

  async function testProvider(d) {
    let p;
    if (d?.id && !d?.apiKey && !d?.baseUrl) {
      p = await registry.provider(String(d.id));
    } else {
      const isBuiltIn = d?.id === BUILTIN_PROVIDER;
      if (isBuiltIn) {
        p = await registry.provider(BUILTIN_PROVIDER);
      } else {
        const v = validateProviderInput(d, { isNew: !d?.id });
        let key = v.apiKey;
        if (!key && d?.id) key = (await registry.provider(String(d.id))).key;
        p = { id: d?.id || "test", baseUrl: v.baseUrl, authStyle: v.authStyle, key };
      }
    }
    try {
      const data = await registry.call(p, "stations", {});
      const rows = data.stations || data.data || [];
      return {
        ok: true,
        count: rows.length,
        sample: rows.slice(0, 5).map((r) => ({ gatewayId: gatewayOf(r), name: stationDisplayName(r, null, gatewayOf(r)) })),
      };
    } catch (e) {
      return { ok: false, message: e.message };
    }
  }

  async function removeProvider(admin, d) {
    const id = String(d?.id ?? "");
    if (!id || id === BUILTIN_PROVIDER) throw new HttpsError("invalid-argument", "The built-in provider can't be removed.");
    const used = await db().collection("weatherStations").where("providerId", "==", id).limit(1).get();
    if (!used.empty) throw new HttpsError("failed-precondition", "Stations still use this provider — move or remove them first.");
    await db().doc(`stationProviders/${id}`).delete();
    await db().doc(`stationProviderSecrets/${id}`).delete();
    await log(admin, `Removed weather station provider ${id}`);
    return { ok: true };
  }

  async function searchUsers(d) {
    const q = String(d?.q ?? "").trim().toLowerCase();
    const snap = await db().collection("Users").limit(3000).get();
    const roles = new Map((await panelAccess()).map((p) => [p.uid, p.roles]));
    const assignments = { docs: await kmAssignments() };
    const stationOf = new Map();
    assignments.docs.forEach((a) => {
      const x = a.data();
      if (!stationOf.has(x.uid)) stationOf.set(x.uid, []);
      stationOf.get(x.uid).push(x.gatewayId);
    });
    const rows = snap.docs.map((s) => {
      const u = s.data();
      return {
        uid: s.id, name: u.fullName || u.name || "", email: u.email || "",
        phone: u.phoneNumber || u.phone || "", county: u.county || "",
        stations: stationOf.get(s.id) || [],
        roles: roles.get(s.id) || [],
      };
    }).filter((u) => !q || [u.name, u.email, u.phone, u.county].some((f) => String(f).toLowerCase().includes(q)));
    rows.sort((a, b) => (a.name || a.email).localeCompare(b.name || b.email));
    return { users: rows.slice(0, 50), total: rows.length };
  }


  return onCall({ secrets: [NUASENSE_KEY], timeoutSeconds: 60, memory: "256MiB", maxInstances: 5 }, async (request) => {
    if (!(await isPlatformAdmin(request.auth))) {
      throw new HttpsError("permission-denied", "Only admin accounts can manage weather stations.");
    }
    const admin = request.auth.uid;
    const d = request.data || {};
    switch (d.action) {
      case "overview": return overview();
      case "saveStation": return saveStation(admin, d);
      case "removeStation": return removeStation(admin, d);
      case "assign": return assign(admin, d);
      case "unassign": return unassign(admin, d);
      case "saveProvider": return saveProvider(admin, d);
      case "testProvider": return testProvider(d);
      case "removeProvider": return removeProvider(admin, d);
      case "searchUsers": return searchUsers(d);
      default: throw new HttpsError("invalid-argument", `Unknown action '${d.action}'`);
    }
  });
}

module.exports = {
  createStationRegistry,
  createStationAdminFunction,
  // exported for tests
  looksLikeCoords,
  stationDisplayName,
  providerRequest,
  validateProviderInput,
  slug,
  BUILTIN_PROVIDER,
};
