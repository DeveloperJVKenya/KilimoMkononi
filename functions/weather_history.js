// functions/weather_history.js
//
// Past weather: each station's RECORDED hours next to NASA POWER satellite
// values for the same place — the Weather comparison screen's "Past dates"
// view and its Excel / CSV downloads.
//
// Accuracy rules
//   • In-service date: weatherStations/{gatewayId}.inServiceFrom
//     (YYYY-MM-DD, set in Admin → Weather Stations). Readings before it were
//     recorded before the station was on the farm (bench tests, a previous
//     site) and are excluded everywhere — date ranges, comparisons, downloads.
//   • Nothing is estimated: station values are exactly what the station
//     recorded (hourly), satellite values exactly what NASA POWER publishes;
//     hours a source doesn't have stay empty.
//   • Permanent archive: weatherArchive/{gatewayId}/days/{YYYY-MM-DD} (UTC
//     day) { station: {HH: {...}}, satellite: {HH: {...}} } — every hour
//     as received. weatherArchiveSweep (hourly) saves the last 48 h for every
//     station, satellite days as NASA publishes them (~2–3 days late), and
//     backfills each station's history once. Comparisons read the archive
//     and fetch (and save) only missing days and today, so the latest
//     recorded hour is always included. Server-only (no client rules).
//
//   weatherHistory (callable)
//     action "range"    dates with data: in-service date (or the provider's
//                       first day) → today, at most 365 days back
//     action "compare"  { gatewayId, start, end } (YYYY-MM-DD, inclusive) →
//                       station and satellite hours (UTC) as
//                       { t (ms), temp °C, humidity %, wind m/s, rain mm };
//                       the app pairs them by hour or per Kenyan day
//                       (lib/services/weather_history_comparison.dart)
//   manageWeatherStations action "suggestInService" (functions/stations.js)
//                       uses suggestInServiceFrom() below.
//
// Access: farmers compare their own stations; Field Agronomists and admins
// (scope "all") any Kilimo Mkononi station. Satellite data is fetched here
// (NASA POWER sends no CORS headers) at the station's own coordinates, which
// never leave the server.

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_LOOKBACK_DAYS = 365;
const MAX_SPAN_DAYS = 366;
const POWER_URL = "https://power.larc.nasa.gov/api/temporal/hourly/point";
const POWER_FILL = -900; // POWER marks missing values as -999
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
// Satellite days are re-fetched until complete, but only once NASA POWER
// can have published them.
const SATELLITE_LAG_MS = 2 * DAY_MS;
// A gap this long in the readings means the station was off / being moved.
const SERVICE_GAP_DAYS = 3;
const METRICS = "air_temperature,humidity,rainfall,wind_speed";

// ── Pure helpers (functions/test/weather_history.test.js) ────────────────────

const ymd = (ms) => new Date(ms).toISOString().slice(0, 10);

/**
 * Checks a requested date range; returns { startMs, endMs } (end = the
 * instant after the last day) or throws an HttpsError a person can read.
 */
function validateRange(start, end, nowMs = Date.now()) {
  if (!DATE_RE.test(String(start)) || !DATE_RE.test(String(end))) {
    throw new HttpsError("invalid-argument", "Pick a start and end date.");
  }
  const startMs = Date.parse(`${start}T00:00:00Z`);
  const endMs = Date.parse(`${end}T00:00:00Z`) + DAY_MS;
  if (!Number.isFinite(startMs) || !Number.isFinite(endMs)) {
    throw new HttpsError("invalid-argument", "Those dates aren't valid.");
  }
  if (startMs >= endMs) throw new HttpsError("invalid-argument", "The start date must be on or before the end date.");
  const today = Date.parse(`${ymd(nowMs)}T00:00:00Z`);
  if (startMs > today) throw new HttpsError("invalid-argument", "Pick dates up to today.");
  if (startMs < today - MAX_LOOKBACK_DAYS * DAY_MS) {
    throw new HttpsError("invalid-argument", `Stations keep the last ${MAX_LOOKBACK_DAYS} days — pick a later start date.`);
  }
  if ((endMs - startMs) / DAY_MS > MAX_SPAN_DAYS) {
    throw new HttpsError("invalid-argument", `Pick at most ${MAX_SPAN_DAYS} days at a time.`);
  }
  return { startMs, endMs: Math.min(endMs, today + DAY_MS) };
}

/** NuaSense /weather (hourly) → [{ t, temp, humidity, wind, rain }], oldest first. */
function stationHours(weather) {
  const byId = new Map((weather?.series || []).map((s) => [s.id, s.data || []]));
  const hours = new Map();
  const put = (id, field) => {
    for (const p of byId.get(id) || []) {
      const t = Date.parse(p.x);
      const v = Number(p.y);
      if (!Number.isFinite(t) || !Number.isFinite(v)) continue;
      const h = Math.floor(t / 3600000) * 3600000;
      if (!hours.has(h)) hours.set(h, { t: h, temp: null, humidity: null, wind: null, rain: null });
      hours.get(h)[field] = v;
    }
  };
  put("air_temperature", "temp");
  put("humidity", "humidity");
  put("wind_speed", "wind");
  put("rainfall", "rain");
  return [...hours.values()].sort((a, b) => a.t - b.t);
}

/** NASA POWER hourly JSON → [{ t, temp, humidity, wind, rain }] (missing → null). */
function powerHours(json) {
  const p = json?.properties?.parameter || {};
  const val = (k, key) => {
    const v = Number(p[k]?.[key]);
    return Number.isFinite(v) && v > POWER_FILL ? v : null;
  };
  const out = [];
  for (const key of Object.keys(p.T2M || {})) {
    // "YYYYMMDDHH" in UTC
    const t = Date.UTC(+key.slice(0, 4), +key.slice(4, 6) - 1, +key.slice(6, 8), +key.slice(8, 10));
    const row = { t, temp: val("T2M", key), humidity: val("RH2M", key), wind: val("WS2M", key), rain: val("PRECTOTCORR", key) };
    if (row.temp !== null || row.humidity !== null || row.wind !== null || row.rain !== null) out.push(row);
  }
  return out.sort((a, b) => a.t - b.t);
}

/** Coordinates of a station listing row ({location: {lat, lon}} or lat/lon). */
function stationCoords(raw) {
  const lat = Number(raw?.location?.lat ?? raw?.lat ?? raw?.latitude);
  const lon = Number(raw?.location?.lon ?? raw?.lon ?? raw?.longitude);
  return Number.isFinite(lat) && Number.isFinite(lon) && (lat !== 0 || lon !== 0) ? { lat, lon } : null;
}

const validCoord = (lat, lon) =>
  Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180;

/** "HH" key of an hour inside its UTC day doc. */
const hourKey = (t) => String(new Date(t).getUTCHours()).padStart(2, "0");

/** Hours → { "YYYY-MM-DD": { "HH": {temp, humidity, wind, rain} } } (UTC days). */
function hoursByDay(rows) {
  const out = {};
  for (const r of rows || []) {
    const day = ymd(r.t);
    (out[day] ??= {})[hourKey(r.t)] = { temp: r.temp, humidity: r.humidity, wind: r.wind, rain: r.rain };
  }
  return out;
}

/** An archived day map back to hours. */
function dayToHours(day, map) {
  const base = Date.parse(`${day}T00:00:00Z`);
  return Object.entries(map || {})
    .map(([hh, v]) => ({ t: base + Number(hh) * 3600000, temp: v?.temp ?? null, humidity: v?.humidity ?? null, wind: v?.wind ?? null, rain: v?.rain ?? null }))
    .filter((h) => Number.isFinite(h.t))
    .sort((a, b) => a.t - b.t);
}

/** Every UTC day from startMs (inclusive) to endMs (exclusive). */
function daysBetween(startMs, endMs) {
  const out = [];
  for (let t = Date.parse(`${ymd(startMs)}T00:00:00Z`); t < endMs; t += DAY_MS) out.push(ymd(t));
  return out;
}

/** The later of two YYYY-MM-DD dates (either may be missing). */
const laterDate = (a, b) => (!a ? b : !b ? a : a > b ? a : b);

/**
 * The likely in-service date from the station's daily reading counts
 * ([{day, hours}], oldest first): the first day after the LAST gap of at
 * least SERVICE_GAP_DAYS without readings — before such a gap the station
 * was off or somewhere else. Null when there is no such gap.
 */
function suggestInServiceFrom(days) {
  const withData = days.filter((d) => d.hours > 0).map((d) => d.day).sort();
  let suggestion = null;
  for (let i = 1; i < withData.length; i++) {
    const gap = (Date.parse(withData[i]) - Date.parse(withData[i - 1])) / DAY_MS - 1;
    if (gap >= SERVICE_GAP_DAYS) suggestion = { date: withData[i], gapDays: gap, lastBefore: withData[i - 1] };
  }
  return suggestion;
}

// ── Function ─────────────────────────────────────────────────────────────────

function createWeatherHistoryFunction({
  registry, NUASENSE_KEY, getOwnedStationIds, getAllPlatformStationIds, isAgronomist, isPlatformAdmin,
  fetchImpl = (...a) => fetch(...a),
  db = () => getFirestore(),
}) {
  async function allowedStations(request, scope) {
    const uid = request.auth.uid;
    const all = scope === "all" && ((await isAgronomist(uid)) || (await isPlatformAdmin(request.auth)));
    return all ? getAllPlatformStationIds() : getOwnedStationIds(uid);
  }

  async function satellite(lat, lon, startMs, endMs) {
    const qs = new URLSearchParams({
      parameters: "T2M,RH2M,WS2M,PRECTOTCORR",
      community: "AG",
      latitude: lat.toFixed(4),
      longitude: lon.toFixed(4),
      start: ymd(startMs).replaceAll("-", ""),
      end: ymd(endMs - 1).replaceAll("-", ""),
      format: "JSON",
      "time-standard": "UTC",
    });
    const res = await fetchImpl(`${POWER_URL}?${qs}`, { headers: { Accept: "application/json" } });
    if (!res.ok) throw new Error(`NASA POWER HTTP ${res.status}`);
    return powerHours(await res.json());
  }

  /** The station's recorded hours from its provider, exactly as recorded. */
  async function providerHours(gatewayId, startMs, endMs) {
    const weather = await registry.callForStation(gatewayId, "weather", {
      metrics: METRICS,
      start: new Date(startMs).toISOString(),
      end: new Date(endMs).toISOString(),
      resolution: "hourly",
    });
    return stationHours(weather).filter((h) => h.t >= startMs && h.t < endMs);
  }

  const daysRef = (gatewayId) => db().collection("weatherArchive").doc(gatewayId).collection("days");

  /** Saves hours into the archive (merged hour by hour). */
  async function save(gatewayId, kind, rows) {
    const byDay = hoursByDay(rows);
    const entries = Object.entries(byDay);
    for (let i = 0; i < entries.length; i += 400) {
      const batch = db().batch();
      for (const [day, hours] of entries.slice(i, i + 400)) {
        batch.set(daysRef(gatewayId).doc(day), {
          day,
          gatewayId,
          [kind]: hours,
          [`${kind}UpdatedAt`]: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      await batch.commit();
    }
    return entries.length;
  }

  /** Archived days for [days] → Map(day → {station, satellite}). */
  async function readArchive(gatewayId, days) {
    const out = new Map();
    for (let i = 0; i < days.length; i += 100) {
      const snaps = await db().getAll(...days.slice(i, i + 100).map((d) => daysRef(gatewayId).doc(d)));
      snaps.forEach((snap, k) => { if (snap.exists) out.set(days[i + k], snap.data()); });
    }
    return out;
  }

  async function stationMeta(gatewayId) {
    const snap = await db().doc(`weatherStations/${gatewayId}`).get();
    const v = snap.exists ? snap.data().inServiceFrom : null;
    return { inServiceFrom: typeof v === "string" && DATE_RE.test(v) ? v : null };
  }

  async function coordsOf(gatewayId) {
    const [described] = await registry.describe([gatewayId]).catch(() => [null]);
    return { name: described?.name || gatewayId, coords: stationCoords(described) };
  }

  /**
   * Station + satellite hours for [startMs, endMs): from the archive; days
   * missing from it — and today / yesterday, which are still being recorded
   * — are fetched from the station's provider and saved. Satellite days not
   * yet complete are fetched from NASA POWER (once it can have them) and saved.
   */
  async function hoursFor(gatewayId, startMs, endMs, coords, nowMs = Date.now()) {
    const days = daysBetween(startMs, endMs);
    const archive = await readArchive(gatewayId, days);
    const recent = ymd(nowMs - DAY_MS);
    const needStation = days.filter((d) => !archive.get(d)?.station || d >= recent);
    const stationRows = [];
    for (const d of days) {
      if (!needStation.includes(d)) stationRows.push(...dayToHours(d, archive.get(d).station));
    }
    if (needStation.length) {
      const from = Date.parse(`${needStation[0]}T00:00:00Z`);
      const fresh = await providerHours(gatewayId, from, endMs);
      await save(gatewayId, "station", fresh);
      const freshDays = new Set(needStation);
      // Archived days inside the fetched span were already taken from the
      // archive; only the days that needed fetching come from `fresh`.
      stationRows.push(...fresh.filter((h) => freshDays.has(ymd(h.t))));
    }

    let satelliteAvailable = !!coords;
    const satRows = [];
    if (coords) {
      const published = nowMs - SATELLITE_LAG_MS;
      const needSat = days.filter((d) => {
        const n = Object.keys(archive.get(d)?.satellite || {}).length;
        return n < 24 && Date.parse(`${d}T00:00:00Z`) < published;
      });
      for (const d of days) {
        if (!needSat.includes(d)) satRows.push(...dayToHours(d, archive.get(d)?.satellite));
      }
      if (needSat.length) {
        try {
          const from = Date.parse(`${needSat[0]}T00:00:00Z`);
          const to = Math.min(endMs, Date.parse(`${needSat[needSat.length - 1]}T00:00:00Z`) + DAY_MS);
          const fresh = (await satellite(coords.lat, coords.lon, from, to)).filter((h) => h.t >= from && h.t < to);
          await save(gatewayId, "satellite", fresh);
          const want = new Set(needSat);
          satRows.push(...fresh.filter((h) => want.has(ymd(h.t))));
        } catch (e) {
          console.warn(`[weatherHistory] satellite ${gatewayId}: ${e.message}`);
          satelliteAvailable = satRows.length > 0;
          for (const d of needSat) satRows.push(...dayToHours(d, archive.get(d)?.satellite));
        }
      }
    }
    const inRange = (h) => h.t >= startMs && h.t < endMs;
    return {
      station: stationRows.filter(inRange).sort((a, b) => a.t - b.t),
      satellite: satRows.filter(inRange).sort((a, b) => a.t - b.t),
      satelliteAvailable,
    };
  }

  /** First and last day with data, clamped to the in-service date and 365 days. */
  async function dateRange(gatewayId, nowMs = Date.now()) {
    const [r, meta] = await Promise.all([
      registry.callForStation(gatewayId, "weather/range", {}).catch(() => null),
      stationMeta(gatewayId),
    ]);
    const today = ymd(nowMs);
    const oldest = ymd(nowMs - MAX_LOOKBACK_DAYS * DAY_MS);
    const min = laterDate(laterDate(r?.range?.minDate, meta.inServiceFrom), oldest);
    return {
      minDate: min > today ? today : min,
      maxDate: r?.range?.maxDate && r.range.maxDate < today ? r.range.maxDate : today,
      latestReading: r?.range?.maxTime || null,
      inServiceFrom: meta.inServiceFrom,
      maxSpanDays: MAX_SPAN_DAYS,
    };
  }

  const weatherHistory = onCall(
    { secrets: [NUASENSE_KEY], timeoutSeconds: 180, memory: "512MiB", maxInstances: 5 },
    async (request) => {
      if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
      const { action, gatewayId, start, end, scope, farmLat, farmLon } = request.data || {};
      if (typeof gatewayId !== "string" || !gatewayId) {
        throw new HttpsError("invalid-argument", "Pick a weather station.");
      }
      const allowed = await allowedStations(request, scope);
      if (!allowed.includes(gatewayId)) {
        throw new HttpsError("permission-denied", "That station is not connected to your account.");
      }

      if (action === "range") return dateRange(gatewayId);
      if (action !== "compare") throw new HttpsError("invalid-argument", `Unknown action '${action}'`);

      const req = validateRange(start, end);
      const meta = await stationMeta(gatewayId);
      // Never before the station was on the farm.
      const serviceStart = meta.inServiceFrom ? Date.parse(`${meta.inServiceFrom}T00:00:00Z`) : 0;
      const startMs = Math.max(req.startMs, serviceStart);
      const endMs = req.endMs;
      if (startMs >= endMs) {
        throw new HttpsError("failed-precondition",
          `This station has been recording on the farm since ${meta.inServiceFrom} — pick dates from then on.`);
      }

      const { name, coords: stationCoordsFound } = await coordsOf(gatewayId);
      let coords = stationCoordsFound;
      let usedFarmLocation = false;
      if (!coords && validCoord(Number(farmLat), Number(farmLon))) {
        coords = { lat: Number(farmLat), lon: Number(farmLon) };
        usedFarmLocation = true;
      }

      const h = await hoursFor(gatewayId, startMs, endMs, coords);
      return {
        stationName: name,
        start: ymd(startMs),
        end: ymd(endMs - 1),
        station: h.station,
        satellite: h.satellite,
        satelliteAvailable: h.satelliteAvailable,
        satelliteLatest: h.satellite.length ? h.satellite[h.satellite.length - 1].t : null,
        stationLatest: h.station.length ? h.station[h.station.length - 1].t : null,
        inServiceFrom: meta.inServiceFrom,
        clippedToService: serviceStart > req.startMs,
        usedFarmLocation,
        noLocation: !coords,
      };
    }
  );

  /**
   * Hourly: saves the last 48 h of every station, satellite days as NASA
   * publishes them, and — once per station — its history since it went into
   * service (or as far back as the provider keeps, ≤ 365 days).
   */
  async function runArchiveSweep(nowMs = Date.now()) {
    const ids = await getAllPlatformStationIds();
    for (const gatewayId of ids) {
      try {
        const metaRef = db().collection("weatherArchive").doc(gatewayId);
        const [state, meta, range] = await Promise.all([
          metaRef.get(),
          stationMeta(gatewayId),
          dateRange(gatewayId, nowMs),
        ]);
        const { coords } = await coordsOf(gatewayId);
        const from = Date.parse(`${range.minDate}T00:00:00Z`);
        const backfilledFrom = state.exists ? state.data().backfilledFrom : null;
        const needsBackfill = !backfilledFrom || backfilledFrom > range.minDate;
        const stationFrom = needsBackfill ? from : nowMs - 2 * DAY_MS;
        // Provider calls in ≤ 92-day pieces.
        let saved = 0;
        for (let t = stationFrom; t < nowMs; t += 92 * DAY_MS) {
          saved += await save(gatewayId, "station", await providerHours(gatewayId, t, Math.min(nowMs, t + 92 * DAY_MS)));
        }
        if (coords) {
          const satFrom = needsBackfill ? from : nowMs - 10 * DAY_MS;
          await save(gatewayId, "satellite", await satellite(coords.lat, coords.lon, satFrom, nowMs));
        }
        await metaRef.set({
          gatewayId,
          inServiceFrom: meta.inServiceFrom,
          ...(needsBackfill ? { backfilledFrom: range.minDate } : {}),
          lastSweepAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log(`[weatherArchiveSweep] ${gatewayId}: ${saved} day(s) of station data saved${needsBackfill ? " (backfill)" : ""}`);
      } catch (e) {
        console.warn(`[weatherArchiveSweep] ${gatewayId}: ${e.message}`);
      }
    }
  }

  const weatherArchiveSweep = onSchedule(
    {
      schedule: "every 60 minutes", timeZone: "Africa/Nairobi", secrets: [NUASENSE_KEY],
      timeoutSeconds: 540, memory: "512MiB", maxInstances: 1,
    },
    () => runArchiveSweep()
  );

  /** Daily reading counts for a station (for the in-service suggestion). */
  async function suggestFor(gatewayId, nowMs = Date.now()) {
    const r = await registry.callForStation(gatewayId, "weather/range", {}).catch(() => null);
    const startDay = laterDate(r?.range?.minDate, ymd(nowMs - MAX_LOOKBACK_DAYS * DAY_MS));
    const hours = [];
    for (let t = Date.parse(`${startDay}T00:00:00Z`); t < nowMs; t += 92 * DAY_MS) {
      hours.push(...await providerHours(gatewayId, t, Math.min(nowMs, t + 92 * DAY_MS)));
    }
    const counts = new Map();
    for (const h of hours) counts.set(ymd(h.t), (counts.get(ymd(h.t)) || 0) + 1);
    const days = [...counts].map(([day, n]) => ({ day, hours: n })).sort((a, b) => (a.day < b.day ? -1 : 1));
    return {
      firstReading: days[0]?.day || null,
      suggestion: suggestInServiceFrom(days),
      days: days.length,
    };
  }

  return { weatherHistory, weatherArchiveSweep, runArchiveSweep, suggestFor, hoursFor };
}

module.exports = {
  createWeatherHistoryFunction,
  // exported for tests
  hoursByDay,
  dayToHours,
  daysBetween,
  suggestInServiceFrom,
  validateRange,
  stationHours,
  powerHours,
  stationCoords,
  MAX_LOOKBACK_DAYS,
  MAX_SPAN_DAYS,
};
