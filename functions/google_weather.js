// functions/google_weather.js
//
// Google Weather API + Geocoding API proxy (`getGoogleWeather` callable),
// the same data source Coffeecore uses — but with the key in Secret Manager
// (GOOGLE_WEATHER_KEY, restricted to weather + geocoding) instead of the app.
//
// Actions (request.data.action):
//   weather  {lat, lon}  → { current, days, hours }  — raw Google objects:
//                          currentConditions, forecastDays (7), forecastHours (24)
//   geocode  {query}     → { lat, lon, label } | { notFound: true }   (Kenya-biased)
//   reverse  {lat, lon}  → { label }  (short place name, may be null)
//   history  {lat, lon}  → { hours } — Google's recorded hourly conditions for
//                          the last 24 h (historyHours), used to compare with
//                          a weather station's own readings (Weather screen)
//
// This is a FORECAST / area model. Advisories and alerts stay driven by the
// farm's own NuaSense station readings — never by this data.
//
// Results are cached in memory per instance (weather ~10 min per ~1 km cell,
// place names 7 days) to keep API usage and cost down.

const { onCall, HttpsError } = require("firebase-functions/v2/https");

const WEATHER_BASE = "https://weather.googleapis.com/v1";
const GEOCODE_BASE = "https://maps.googleapis.com/maps/api/geocode/json";
const WEATHER_TTL_MS = 10 * 60 * 1000;
const PLACE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const CACHE_MAX = 500;

// ── Pure helpers (unit-tested) ───────────────────────────────────────────────

/** Validates and normalises a request; throws HttpsError on bad input. */
function validateWeatherRequest(data) {
  const action = data?.action;
  if (action === "geocode") {
    const query = String(data.query ?? "").trim();
    if (!query || query.length > 120) {
      throw new HttpsError("invalid-argument", "Enter a place name (up to 120 characters).");
    }
    return { action, query };
  }
  if (action === "weather" || action === "reverse" || action === "history") {
    const lat = Number(data.lat);
    const lon = Number(data.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
      throw new HttpsError("invalid-argument", "Invalid coordinates.");
    }
    return { action, lat, lon };
  }
  throw new HttpsError("invalid-argument", `Unknown action '${action}'`);
}

/** Cache key: ~1 km cells for coordinates, case-insensitive for place names. */
function cacheKey(req) {
  if (req.action === "geocode") return `geo:${req.query.toLowerCase()}`;
  return `${req.action}:${req.lat.toFixed(2)},${req.lon.toFixed(2)}`;
}

/** Google Weather API URLs for one location (metric, English). */
function weatherUrls(lat, lon, key) {
  const loc = `key=${encodeURIComponent(key)}&location.latitude=${lat}&location.longitude=${lon}` +
    "&unitsSystem=METRIC&languageCode=en";
  return {
    current: `${WEATHER_BASE}/currentConditions:lookup?${loc}`,
    days: `${WEATHER_BASE}/forecast/days:lookup?${loc}&days=7&pageSize=7`,
    hours: `${WEATHER_BASE}/forecast/hours:lookup?${loc}&hours=24&pageSize=24`,
    history: `${WEATHER_BASE}/history/hours:lookup?${loc}&hours=24&pageSize=24`,
  };
}

/** Short, farmer-friendly place name from a Geocoding result list. */
function placeLabel(results) {
  if (!Array.isArray(results) || !results.length) return null;
  const pick = (types) => {
    for (const r of results) {
      for (const c of r.address_components || []) {
        if ((c.types || []).some((t) => types.includes(t))) return c.long_name;
      }
    }
    return null;
  };
  const town = pick(["locality", "sublocality", "postal_town"]);
  const county = pick(["administrative_area_level_1"]);
  if (town && county && town !== county) return `${town}, ${county}`;
  return town || county || results[0].formatted_address || null;
}

// ── Cache ────────────────────────────────────────────────────────────────────
const cache = new Map();
function cacheGet(key) {
  const hit = cache.get(key);
  if (!hit) return null;
  if (Date.now() > hit.expires) {
    cache.delete(key);
    return null;
  }
  return hit.value;
}
function cacheSet(key, value, ttl) {
  if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value);
  cache.set(key, { value, expires: Date.now() + ttl });
}

// ── Google calls ─────────────────────────────────────────────────────────────
async function getJson(url) {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch (_) {
    body = { raw: text.slice(0, 300) };
  }
  if (!res.ok) {
    const msg = body?.error?.message || `HTTP ${res.status}`;
    console.warn(`[getGoogleWeather] ${url.split("?")[0]} → ${res.status}: ${msg}`);
    throw new HttpsError("unavailable", "The weather service is not responding right now. Try again shortly.");
  }
  return body;
}

async function geocodeQuery(url) {
  const data = await getJson(url);
  if (data.status === "ZERO_RESULTS") return null;
  if (data.status !== "OK") {
    console.warn(`[getGoogleWeather] geocode status ${data.status}: ${data.error_message || ""}`);
    throw new HttpsError("unavailable", "Place search is not available right now.");
  }
  return data.results;
}

function createGoogleWeatherFunction({ GOOGLE_WEATHER_KEY }) {
  return onCall(
    { secrets: [GOOGLE_WEATHER_KEY], timeoutSeconds: 30, memory: "256MiB", maxInstances: 10 },
    async (request) => {
      if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
      const req = validateWeatherRequest(request.data);
      const key = cacheKey(req);
      const cached = cacheGet(key);
      if (cached) return cached;

      const apiKey = GOOGLE_WEATHER_KEY.value();
      let result;
      if (req.action === "weather") {
        const urls = weatherUrls(req.lat, req.lon, apiKey);
        const [current, days, hours] = await Promise.all([
          getJson(urls.current),
          getJson(urls.days),
          getJson(urls.hours),
        ]);
        result = {
          current,
          days: days.forecastDays || [],
          hours: hours.forecastHours || [],
          fetchedAt: new Date().toISOString(),
        };
        cacheSet(key, result, WEATHER_TTL_MS);
      } else if (req.action === "history") {
        const h = await getJson(weatherUrls(req.lat, req.lon, apiKey).history);
        result = { hours: h.historyHours || [], fetchedAt: new Date().toISOString() };
        cacheSet(key, result, WEATHER_TTL_MS);
      } else if (req.action === "geocode") {
        const results = await geocodeQuery(
          `${GEOCODE_BASE}?address=${encodeURIComponent(req.query)}&region=ke&key=${encodeURIComponent(apiKey)}`);
        if (!results || !results.length) {
          result = { notFound: true };
        } else {
          const loc = results[0].geometry.location;
          result = { lat: loc.lat, lon: loc.lng, label: placeLabel(results) || req.query };
        }
        cacheSet(key, result, PLACE_TTL_MS);
      } else {
        const results = await geocodeQuery(
          `${GEOCODE_BASE}?latlng=${req.lat},${req.lon}&key=${encodeURIComponent(apiKey)}`);
        result = { label: placeLabel(results) };
        cacheSet(key, result, PLACE_TTL_MS);
      }
      return result;
    }
  );
}

module.exports = {
  createGoogleWeatherFunction,
  // exported for tests
  validateWeatherRequest,
  cacheKey,
  weatherUrls,
  placeLabel,
};
