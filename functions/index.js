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

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret }      = require("firebase-functions/params");
const { getFirestore }      = require("firebase-admin/firestore");
const { initializeApp, getApps } = require("firebase-admin/app");

if (!getApps().length) initializeApp();

const GEMINI_KEY    = defineSecret("GEMINI_KEY");
const NUASENSE_KEY  = defineSecret("NUASENSE_KEY");

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

  if (isLocalhost || isProduction) {
    res.set("Access-Control-Allow-Origin", origin);
  } else {
    res.set("Access-Control-Allow-Origin", "*");
  }
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
}

// ── Gemini handler ────────────────────────────────────────────────────────────
async function handler(req, res) {
  setCors(req, res);
  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const apiKey = GEMINI_KEY.value();
    if (!apiKey) return res.status(500).json({ error: "Missing GEMINI_KEY" });

    const { prompt, imageBase64 } = req.body ?? {};
    if (!prompt) return res.status(400).json({ error: "Missing prompt" });

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
      console.log(`[Vision] ${model} ~${Math.round(cleanB64.length * 0.75 / 1024)}KB`);
    } else {
      parts = [{ text: prompt }];
      console.log(`[Text] ${model} ${prompt.length}ch`);
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
//   stationAssignments/{gatewayId}
//     uid: string           — the farmer this station belongs to
//     platform: "km" | "cc" — which app this assignment belongs to
//     plotId: string?       — optional, if tied to a specific plot
//     assignedAt: Timestamp
//     assignedBy: string    — admin uid who ran the assignment
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

/** Every gateway_id currently assigned to this uid in KM's Firestore. */
async function getOwnedStationIds(uid) {
  const db = getFirestore();
  const snap = await db
    .collection("stationAssignments")
    .where("uid", "==", uid)
    .get();
  return snap.docs.map((d) => d.id);
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

    const ownedStationIds = await getOwnedStationIds(uid);

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
      `[NuaSense] ${endpoint} → HTTP ${res.status} | ` +
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

// ── Admin-only: assign a physical station to a farmer's account ──────────────
// Call this once per install, instead of editing Firestore by hand — it's
// auditable (assignedBy/assignedAt). Restricted to callers with a custom
// claim `admin: true`:
//   admin.auth().setCustomUserClaims(installerUid, { admin: true });

exports.assignStationToUser = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.token?.admin) {
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

    // A farmer normally has exactly one active station on this platform.
    // On a hardware swap, NuaSense issues a new gateway_id for the same
    // physical install — this clears the farmer's old assignment(s) here
    // before writing the new one, so a stale gateway_id never lingers as
    // still "owned" by them.
    const staleAssignments = await db
      .collection("stationAssignments")
      .where("uid", "==", uid)
      .where("platform", "==", PLATFORM)
      .get();
    const batch = db.batch();
    staleAssignments.docs.forEach((doc) => {
      if (doc.id !== gatewayId) batch.delete(doc.ref);
    });
    batch.set(db.collection("stationAssignments").doc(gatewayId), {
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