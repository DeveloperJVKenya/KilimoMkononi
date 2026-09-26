// functions/index.js
// Deploy: firebase deploy --only functions
//
// KEY RULES:
// 1. Return the FULL Gemini response — not just { text }.
//    gemini_quiz_service, gemini_vision_helper, and education_plot_analysis_screen
//    all read candidates[0].content.parts[0].text. If you return { text } only,
//    those three fail silently while the tutor (which checks both formats) still works.
// 2. No node-fetch — Node 22 has fetch built in globally.
// 3. CORS: allow all localhost ports for Flutter web dev + production domains.
//    Unknown origins get no CORS header, so browsers block them. Native apps
//    send no Origin, so CORS doesn't affect them.
// 4. Every AI / third-party proxy requires a signed-in Firebase user. The HTTP
//    Gemini endpoints expect `Authorization: Bearer <Firebase ID token>` (see
//    lib/services/function_auth.dart); the onCall functions get auth for free.
//    Third-party keys live ONLY in Secret Manager, never in the app:
//      firebase functions:secrets:set GEMINI_KEY
//      firebase functions:secrets:set NUASENSE_KEY
//      firebase functions:secrets:set OPENWEATHER_KEY
//      firebase functions:secrets:set KINDWISE_CROP_HEALTH_KEY
//      firebase functions:secrets:set KINDWISE_PLANT_ID_KEY
//      firebase functions:secrets:set KINDWISE_INSECT_ID_KEY
//      firebase functions:secrets:set GOOGLE_WEATHER_KEY   (Weather + Geocoding APIs only)

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret }      = require("firebase-functions/params");
const { getFirestore }      = require("firebase-admin/firestore");
const { getAuth }           = require("firebase-admin/auth");
const { initializeApp, getApps } = require("firebase-admin/app");

if (!getApps().length) initializeApp();

const GEMINI_KEY    = defineSecret("GEMINI_KEY");
const NUASENSE_KEY  = defineSecret("NUASENSE_KEY");
const OPENWEATHER_KEY          = defineSecret("OPENWEATHER_KEY");
const KINDWISE_CROP_HEALTH_KEY = defineSecret("KINDWISE_CROP_HEALTH_KEY");
const KINDWISE_PLANT_ID_KEY    = defineSecret("KINDWISE_PLANT_ID_KEY");
const KINDWISE_INSECT_ID_KEY   = defineSecret("KINDWISE_INSECT_ID_KEY");
const GOOGLE_WEATHER_KEY       = defineSecret("GOOGLE_WEATHER_KEY");

// Per-request abuse limits for the Gemini proxy.
const MAX_PROMPT_CHARS = 60000;
const MAX_IMAGE_B64    = 10 * 1024 * 1024; // ~7.5MB decoded

const TEXT_MODEL   = "gemini-2.5-flash";
const VISION_MODEL = "gemini-2.5-flash";
const BASE_URL     = "https://generativelanguage.googleapis.com/v1beta/models";
const NUASENSE_BASE = "https://api.nuasense.com/api/partner/v1";

// ── CORS ──────────────────────────────────────────────────────────────────────
function setCors(req, res) {
  const origin = req.headers.origin ?? "";
  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  const isProduction = [
    "https://kilimomkononi-e1031.web.app",
    "https://kilimomkononi-e1031.firebaseapp.com",
  ].includes(origin);

  // No wildcard fallback — the old "*" made the allowlist meaningless.
  if (isLocalhost || isProduction) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

// ── Auth for the HTTP (onRequest) endpoints ──────────────────────────────────
/** Returns the decoded Firebase ID token, or null if missing/invalid. */
async function verifyBearer(req) {
  const match = (req.headers.authorization ?? "").match(/^Bearer (.+)$/);
  if (!match) return null;
  try {
    return await getAuth().verifyIdToken(match[1]);
  } catch (_) {
    return null;
  }
}

// ── Gemini handler ────────────────────────────────────────────────────────────
async function handler(req, res) {
  setCors(req, res);
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });

  // Previously anyone with the URL could spend the Gemini quota.
  const caller = await verifyBearer(req);
  if (!caller) return res.status(401).json({ error: "Unauthenticated" });

  try {
    const apiKey = GEMINI_KEY.value();
    if (!apiKey) return res.status(500).json({ error: "Missing GEMINI_KEY" });

    const { prompt, imageBase64 } = req.body ?? {};
    if (!prompt || typeof prompt !== "string") {
      return res.status(400).json({ error: "Missing prompt" });
    }
    if (prompt.length > MAX_PROMPT_CHARS) {
      return res.status(413).json({ error: "Prompt too long" });
    }
    if (typeof imageBase64 === "string" && imageBase64.length > MAX_IMAGE_B64) {
      return res.status(413).json({ error: "Image too large" });
    }

    const isVision = typeof imageBase64 === "string" && imageBase64.length > 100;
    const model    = isVision ? VISION_MODEL : TEXT_MODEL;

    let parts;
    if (isVision) {
      let mimeType = "image/jpeg";
      if      (imageBase64.startsWith("iVBORw")) mimeType = "image/png";
      else if (imageBase64.startsWith("R0lGOD")) mimeType = "image/gif";
      else if (imageBase64.startsWith("UklGR"))  mimeType = "image/webp";
      const cleanB64 = imageBase64.replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, "");
      parts = [
        { inline_data: { mime_type: mimeType, data: cleanB64 } },
        { text: prompt },
      ];
      console.log(`[Vision] ${model} uid=${caller.uid} ~${Math.round(cleanB64.length * 0.75 / 1024)}KB`);
    } else {
      parts = [{ text: prompt }];
      console.log(`[Text] ${model} uid=${caller.uid} ${prompt.length}ch`);
    }

    const doFetch = () => fetch(
      `${BASE_URL}/${model}:generateContent?key=${apiKey}`,
      {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts }],
          generationConfig: {
            temperature:     isVision ? 0.05 : 0.7,
            maxOutputTokens: isVision ? 2048  : 4096,
          },
        }),
      }
    );

    let r = await doFetch();
    if (r.status === 429 || r.status === 503) {
      console.warn(`${model} ${r.status} — retry in 10s`);
      await new Promise(x => setTimeout(x, 10000));
      r = await doFetch();
    }
    if (r.status === 429 || r.status === 503) {
      console.warn(`${model} ${r.status} — retry in 15s`);
      await new Promise(x => setTimeout(x, 15000));
      r = await doFetch();
    }

    const data = await r.json();

    if (!r.ok) {
      console.error(`${model} error ${r.status}:`, JSON.stringify(data).slice(0, 400));
      return res.status(r.status).json({
        error:   "Gemini API error",
        status:  r.status,
        message: data?.error?.message ?? "Unknown error",
      });
    }

    if (!data?.candidates?.length) {
      console.error(`${model} empty candidates:`, JSON.stringify(data).slice(0, 200));
      return res.status(500).json({ error: "Empty response from Gemini" });
    }

    return res.json(data);

  } catch (err) {
    console.error("handler error:", err.message);
    return res.status(500).json({ error: "Internal error", message: err.message });
  }
}

const fnConfig = {
  secrets:        [GEMINI_KEY],
  timeoutSeconds: 120,
  memory:         "256MiB",
  maxInstances:   10,
};

exports.askGemini       = onRequest(fnConfig, handler);
exports.askGeminiVision = onRequest(fnConfig, handler);

// ── NuaSense weather station proxy — WITH per-farmer station scoping ─────────
//
// Called by NuaSenseService (lib/services/nuasense_service.dart).
// Uses onCall so the Firebase SDK handles auth automatically.
// The NUASENSE_KEY secret is stored with:
//   firebase functions:secrets:set NUASENSE_KEY
// Then enter the key when prompted. Deploy with:
//   firebase deploy --only functions
//
// The problem this solves: this NuaSense API key is shared with Coffeecore
// and covers every station on BOTH platforms — it is NOT per-farmer.
// Isolating farmers from each other is entirely our job: NuaSense's own
// checks only stop a request for a gateway the KEY doesn't own at all; two
// Kilimo Mkononi farmers (or a KM farmer and a Coffeecore farmer sharing
// this key) are not isolated from each other by anything on NuaSense's
// side. This function is what makes "which station(s) can this uid see" a
// server-side fact, resolved from our own Firestore, never a client claim.
//
// Firestore schema this depends on:
//   stationAssignments/{gatewayId}_{uid}
//     gatewayId: string      — the physical station (repeated in the doc,
//                              not just the ID prefix, so queries don't
//                              have to parse it back out)
//     uid: string            — the farmer this assignment is for
//     platform: "km" | "cc"  — which app this assignment belongs to
//     plotId: string?        — optional, if tied to a specific plot
//     assignedAt: Timestamp
//     assignedBy: string     — admin uid who ran the assignment
//
// Composite doc ID on purpose: this is a MANY-TO-ONE relationship — more
// than one farmer can legitimately share a single physical station (e.g.
// several accounts near the same office install). A doc ID of just
// {gatewayId} would mean the second farmer assigned to a station silently
// overwrites the first farmer's access; keying by {gatewayId}_{uid} gives
// each farmer their own doc, so assigning farmer B never touches farmer
// A's assignment to the same station.
//
// Confirmed with NuaSense (Manuel, production access thread):
//   • No practical cap on stations per account.
//   • GET /stations returns the FULL account list in one response — no
//     per-station endpoint, no pagination/filtering yet.
//   • gateway_id = hardware EUI. Stable across servicing; changes only on
//     a physical hardware swap — call assignStationToUser again with the
//     new gateway_id when that happens; it replaces the farmer's prior
//     assignment on this platform automatically.
//   • Daily call allowance is per key, not tied to station count.

const NUASENSE_ALLOWED_ENDPOINTS = [
  "weather",
  "weather/range",
  "weather/sunlight-hours",
  "derived",
  "derived/fields",
  "derived/forecast",
  "stations",
];

// This deployment is Kilimo Mkononi's — hardcoded so a mistaken call to
// assignStationToUser can never register a station under the wrong
// platform from this project.
const PLATFORM = "km";

/** Field Agronomists (Agronomists/{uid}, granted by an admin). */
async function isAgronomist(uid) {
  return (await getFirestore().doc(`Agronomists/${uid}`).get()).exists;
}

/**
 * Every station assigned to any Kilimo Mkononi farmer. Field Agronomists
 * need live conditions for all KM stations to write advice; they only get
 * weather readings, never farmer data (assignments stay server-side).
 */
async function getAllPlatformStationIds() {
  const snap = await getFirestore()
    .collection("stationAssignments")
    .where("platform", "==", PLATFORM)
    .get();
  return [...new Set(snap.docs.map((d) => d.data().gatewayId))];
}

/** Every gateway_id currently assigned to this uid in KM's Firestore. */
async function getOwnedStationIds(uid) {
  const db = getFirestore();
  const snap = await db
    .collection("stationAssignments")
    .where("uid", "==", uid)
    .get();
  return snap.docs.map((d) => d.data().gatewayId);
}

exports.getNuaSenseData = onCall(
  {
    secrets:         [NUASENSE_KEY],
    timeoutSeconds:  30,
    memory:          "256MiB",
    maxInstances:    10,
    enforceAppCheck: false,   // set true when you add App Check
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;

    const { endpoint = "weather", params = {} } = request.data ?? {};
    if (!NUASENSE_ALLOWED_ENDPOINTS.includes(endpoint)) {
      throw new HttpsError("invalid-argument", `Unknown endpoint '${endpoint}'`);
    }

    // Agronomists (and admins testing the agronomist panel) see every KM
    // station's conditions; farmers see only their own.
    const allStations = (await isAgronomist(uid)) ||
      (await isPlatformAdmin(request.auth));
    const ownedStationIds = allStations
      ? await getAllPlatformStationIds()
      : await getOwnedStationIds(uid);

    // ── /stations: NuaSense returns the FULL account list (both platforms,
    // every farmer) in one response. Filter to only what THIS uid owns
    // before anything reaches the client.
    if (endpoint === "stations") {
      if (ownedStationIds.length === 0) {
        return { stations: [], provisioned: false };
      }
      const res = await fetch(`${NUASENSE_BASE}/stations`, {
        headers: {
          "Authorization": `Bearer ${NUASENSE_KEY.value()}`,
          "Accept": "application/json",
        },
      });
      if (!res.ok) {
        const body = await res.text();
        throw new HttpsError(
          "internal",
          `NuaSense returned HTTP ${res.status}: ${body.slice(0, 200)}`
        );
      }
      const data = await res.json();
      const allStations = data.stations || data.data || [];
      const owned = allStations.filter((s) =>
        ownedStationIds.includes(s.gateway_id || s.id)
      );
      return { stations: owned, provisioned: true };
    }

    // ── Every other endpoint requires a gateway_id we can verify ──────────
    let gatewayId = params.gateway_id;

    if (gatewayId) {
      if (!ownedStationIds.includes(gatewayId)) {
        throw new HttpsError(
          "permission-denied",
          "That station is not assigned to your account."
        );
      }
    } else {
      if (ownedStationIds.length === 0) {
        // Distinguishable "nothing installed yet" — not an error, not a
        // silent fallback to the shared account's demo/default gateway.
        return { provisioned: false };
      }
      // No station specified — default to the caller's assigned one.
      // (Most farmers will only ever have exactly one.)
      gatewayId = ownedStationIds[0];
    }

    const qs = Object.entries({ ...params, gateway_id: gatewayId })
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join("&");
    const url = `${NUASENSE_BASE}/${endpoint}?${qs}`;

    const res = await fetch(url, {
      method:  "GET",
      headers: {
        "Authorization": `Bearer ${NUASENSE_KEY.value()}`,
        "Accept":        "application/json",
      },
    });

    console.log(
  `[NuaSense] ${endpoint} gateway=${gatewayId} → HTTP ${res.status} | ` +
  `daily remaining: ${res.headers.get("X-Daily-Remaining") ?? "?"} / ` +
  `${res.headers.get("X-Daily-Limit") ?? "?"}`
);

    if (res.status === 429) {
      const retryAfter = res.headers.get("Retry-After") ?? "60";
      throw new HttpsError(
        "resource-exhausted",
        `NuaSense rate limit hit. Retry after ${retryAfter}s`
      );
    }
    if (res.status === 401) {
      throw new HttpsError("unauthenticated", "NuaSense API key is invalid or expired.");
    }
    if (!res.ok) {
      const body = await res.text();
      throw new HttpsError(
        "internal",
        `NuaSense returned HTTP ${res.status}: ${body.slice(0, 200)}`
      );
    }

    const data = await res.json();
    return { ...data, provisioned: true };
  }
);

/**
 * The app's admin role: an Admins/{uid} document (what the admin panel
 * grants and firestore.rules' isAdmin() checks). The legacy custom claim
 * `admin: true` is still honoured so existing installer accounts keep working.
 */
async function isPlatformAdmin(auth) {
  if (!auth) return false;
  if (auth.token?.admin === true) return true;
  return (await getFirestore().doc(`Admins/${auth.uid}`).get()).exists;
}

// ── Admin-only: assign a physical station to a farmer's account ──────────────
// Call this once per install, instead of editing Firestore by hand — it's
// auditable (assignedBy/assignedAt). Restricted to admins (see isPlatformAdmin).

exports.assignStationToUser = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!(await isPlatformAdmin(request.auth))) {
      throw new HttpsError(
        "permission-denied",
        "Only admin accounts can assign stations."
      );
    }
    const { gatewayId, uid, plotId } = request.data || {};
    if (!gatewayId || !uid) {
      throw new HttpsError("invalid-argument", "gatewayId and uid are required.");
    }

    const db = getFirestore();

    // A farmer normally has exactly one active station on this platform
    // (this clears THIS farmer's other assignments here — it does not
    // touch any other farmer's assignment to the same or any other
    // station, since each farmer now has their own doc). On a hardware
    // swap, NuaSense issues a new gateway_id for the same physical
    // install — this same clearing logic handles that case too, since the
    // "stale" assignment is just this farmer's previous gateway_id.
    const staleAssignments = await db
      .collection("stationAssignments")
      .where("uid", "==", uid)
      .where("platform", "==", PLATFORM)
      .get();
    const docId = `${gatewayId}_${uid}`;
    const batch = db.batch();
    staleAssignments.docs.forEach((doc) => {
      if (doc.id !== docId) batch.delete(doc.ref);
    });
    batch.set(db.collection("stationAssignments").doc(docId), {
      gatewayId,
      uid,
      platform: PLATFORM,
      plotId: plotId ?? null,
      assignedAt: new Date(),
      assignedBy: request.auth.uid,
    });
    await batch.commit();

    return { success: true };
  }
);

// ── OpenWeatherMap proxy ─────────────────────────────────────────────────────
// Replaces the key that used to ship inside lib/config.dart. Called by
// lib/services/open_weather_proxy.dart. Returns { status, data }.
const OPENWEATHER_ENDPOINTS = {
  geo:      "https://api.openweathermap.org/geo/1.0/direct",
  weather:  "https://api.openweathermap.org/data/2.5/weather",
  forecast: "https://api.openweathermap.org/data/2.5/forecast",
};
const OPENWEATHER_PARAMS = ["q", "limit", "lat", "lon", "units", "lang", "cnt"];

exports.getOpenWeather = onCall(
  { secrets: [OPENWEATHER_KEY], timeoutSeconds: 30, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
    const { endpoint, params = {} } = request.data ?? {};
    const base = OPENWEATHER_ENDPOINTS[endpoint];
    if (!base) throw new HttpsError("invalid-argument", `Unknown endpoint '${endpoint}'`);

    const qs = new URLSearchParams();
    for (const k of OPENWEATHER_PARAMS) {
      if (params[k] !== undefined && params[k] !== null) qs.set(k, String(params[k]));
    }
    qs.set("appid", OPENWEATHER_KEY.value());

    const res = await fetch(`${base}?${qs}`, { headers: { Accept: "application/json" } });
    return { status: res.status, data: await readJson(res) };
  }
);

// ── Kindwise proxy (crop.health / plant.id / insect.id) ──────────────────────
// Replaces the three keys that used to ship inside
// lib/services/kindwise_service.dart. The client sends the same JSON body it
// used to POST directly; returns { status, data } so its status handling is
// unchanged.
const KINDWISE_SERVICES = {
  crop:   { url: "https://crop.kindwise.com/api/v1/identification",  key: KINDWISE_CROP_HEALTH_KEY, method: "POST" },
  plant:  { url: "https://plant.id/api/v3/health_assessment",         key: KINDWISE_PLANT_ID_KEY,    method: "POST" },
  insect: { url: "https://insect.kindwise.com/api/v1/identification", key: KINDWISE_INSECT_ID_KEY,   method: "POST" },
  usage:  { url: "https://crop.kindwise.com/api/v1/usage_info",       key: KINDWISE_CROP_HEALTH_KEY, method: "GET"  },
};

exports.kindwiseProxy = onCall(
  {
    secrets:        [KINDWISE_CROP_HEALTH_KEY, KINDWISE_PLANT_ID_KEY, KINDWISE_INSECT_ID_KEY],
    timeoutSeconds: 90,
    memory:         "512MiB",
    maxInstances:   10,
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
    const { service, body } = request.data ?? {};
    const svc = KINDWISE_SERVICES[service];
    if (!svc) throw new HttpsError("invalid-argument", `Unknown service '${service}'`);
    if (svc.method === "POST" && (typeof body !== "object" || body === null)) {
      throw new HttpsError("invalid-argument", "Missing request body.");
    }

    const res = await fetch(svc.url, {
      method:  svc.method,
      headers: { "Api-Key": svc.key.value(), "Content-Type": "application/json" },
      body:    svc.method === "POST" ? JSON.stringify(body) : undefined,
    });
    console.log(`[Kindwise] ${service} uid=${request.auth.uid} → HTTP ${res.status}`);
    return { status: res.status, data: await readJson(res) };
  }
);

/** Parse a proxied response body as JSON, tolerating non-JSON error pages. */
async function readJson(res) {
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text.slice(0, 500) };
  }
}

// ── Push notifications (FCM) — see functions/notifications.js ────────────────
const { createNotificationFunctions, createWebTopicsFunction } = require("./notifications");
Object.assign(exports, createNotificationFunctions({ NUASENSE_KEY, NUASENSE_BASE, PLATFORM }));
// Browser push tokens → crop topics (lib/services/notification_service.dart).
exports.syncWebTopics = createWebTopicsFunction();

// ── Google Weather (forecast / area weather) — see functions/google_weather.js ─
// Used by the Weather screen and alongside station data on the Weather
// Station screen (lib/services/google_weather_service.dart).
const { createGoogleWeatherFunction } = require("./google_weather");
exports.getGoogleWeather = createGoogleWeatherFunction({ GOOGLE_WEATHER_KEY });
