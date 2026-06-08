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

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const GEMINI_KEY = defineSecret("GEMINI_KEY");

const TEXT_MODEL   = "gemini-2.5-flash";
const VISION_MODEL = "gemini-2.5-flash";
const BASE_URL     = "https://generativelanguage.googleapis.com/v1beta/models";

// ── CORS ──────────────────────────────────────────────────────────────────────
// Flutter web dev server uses a random port — allow all localhost ports.
// Production: add your custom domain here if you have one.
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
    // For non-browser clients (APK, Postman) — no Origin header, no CORS needed
    res.set("Access-Control-Allow-Origin", "*");
  }
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
}

// ── Handler ───────────────────────────────────────────────────────────────────
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

    // ── Build parts ───────────────────────────────────────────────────────────
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

    // ── Call Gemini with retry ────────────────────────────────────────────────
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

    // ── Return the FULL Gemini response ───────────────────────────────────────
    // DO NOT return just { text } — quiz service, vision helper, and plot analysis
    // all read candidates[0].content.parts[0].text and will get null if you strip it.
    // The tutor service reads both formats so it works either way, but the others don't.
    return res.json(data);

  } catch (err) {
    console.error("handler error:", err.message);
    return res.status(500).json({ error: "Internal error", message: err.message });
  }
}

// cors: false — setCors() above is the only source of CORS headers
const fnConfig = {
  secrets:        [GEMINI_KEY],
  timeoutSeconds: 120,
  memory:         "256MiB",
  maxInstances:   10,
};

exports.askGemini       = onRequest(fnConfig, handler);
exports.askGeminiVision = onRequest(fnConfig, handler);