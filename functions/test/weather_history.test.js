// Tests for functions/weather_history.js (pure helpers).
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const w = require("../weather_history");

const NOW = Date.parse("2026-10-13T11:00:00Z");

describe("validateRange", () => {
  test("a past day → its whole UTC day", () => {
    const r = w.validateRange("2026-10-03", "2026-10-03", NOW);
    assert.equal(new Date(r.startMs).toISOString(), "2026-10-03T00:00:00.000Z");
    assert.equal(new Date(r.endMs).toISOString(), "2026-10-04T00:00:00.000Z");
  });
  test("a range ending today stops at the end of today", () => {
    const r = w.validateRange("2026-10-01", "2026-10-13", NOW);
    assert.equal(new Date(r.endMs).toISOString(), "2026-10-14T00:00:00.000Z");
  });
  test("bad input is refused with a readable message", () => {
    assert.throws(() => w.validateRange("3/10/2026", "2026-10-04", NOW), /Pick a start and end date/);
    assert.throws(() => w.validateRange("2026-10-05", "2026-10-04", NOW), /on or before/);
    assert.throws(() => w.validateRange("2026-10-20", "2026-10-21", NOW), /up to today/);
    assert.throws(() => w.validateRange("2025-01-01", "2025-01-02", NOW), /last 365 days/);
  });
});

describe("stationHours", () => {
  test("merges the metric series by hour and drops junk", () => {
    const rows = w.stationHours({
      series: [
        { id: "air_temperature", data: [{ x: "2026-10-03T00:00:00.000Z", y: 14.2 }, { x: "2026-10-03T01:00:00.000Z", y: 13.9 }] },
        { id: "humidity", data: [{ x: "2026-10-03T00:00:00.000Z", y: 88 }] },
        { id: "wind_speed", data: [{ x: "2026-10-03T01:00:00.000Z", y: 1.5 }, { x: "bad", y: 3 }] },
        { id: "rainfall", data: [{ x: "2026-10-03T00:20:00.000Z", y: 0.4 }] },
      ],
    });
    assert.equal(rows.length, 2);
    assert.deepEqual(rows[0], { t: Date.parse("2026-10-03T00:00:00Z"), temp: 14.2, humidity: 88, wind: null, rain: 0.4 });
    assert.equal(rows[1].wind, 1.5);
    assert.deepEqual(w.stationHours(null), []);
  });
});

describe("powerHours", () => {
  test("YYYYMMDDHH (UTC) → hours; -999 = missing; empty hours dropped", () => {
    const rows = w.powerHours({
      properties: {
        parameter: {
          T2M: { 2026100300: 15.1, 2026100301: -999, 2026100302: -999 },
          RH2M: { 2026100300: 80, 2026100301: 82, 2026100302: -999 },
          WS2M: { 2026100300: 2.1, 2026100301: 2.0, 2026100302: -999 },
          PRECTOTCORR: { 2026100300: 0, 2026100301: 0.2, 2026100302: -999 },
        },
      },
    });
    assert.equal(rows.length, 2);
    assert.equal(rows[0].t, Date.parse("2026-10-03T00:00:00Z"));
    assert.equal(rows[1].temp, null);
    assert.equal(rows[1].humidity, 82);
  });
});

test("station coordinates: nested location, flat lat/lon, or none", () => {
  assert.deepEqual(w.stationCoords({ location: { lat: -0.3, lon: 36.07, elevation_m: 1800 } }), { lat: -0.3, lon: 36.07 });
  assert.deepEqual(w.stationCoords({ lat: 1, lon: 2 }), { lat: 1, lon: 2 });
  assert.equal(w.stationCoords({ location: { lat: 0, lon: 0 } }), null);
  assert.equal(w.stationCoords({}), null);
});

describe("archive helpers", () => {
  test("hours ↔ UTC day docs keep every recorded value as is", () => {
    const rows = [
      { t: Date.parse("2026-10-03T00:00:00Z"), temp: 14.51, humidity: 80.275, wind: 0.479, rain: 0 },
      { t: Date.parse("2026-10-03T23:00:00Z"), temp: 15, humidity: 70, wind: null, rain: 0.2 },
      { t: Date.parse("2026-10-04T05:00:00Z"), temp: 16, humidity: 60, wind: 1, rain: 0 },
    ];
    const byDay = w.hoursByDay(rows);
    assert.deepEqual(Object.keys(byDay), ["2026-10-03", "2026-10-04"]);
    assert.deepEqual(byDay["2026-10-03"]["00"], { temp: 14.51, humidity: 80.275, wind: 0.479, rain: 0 });
    const back = w.dayToHours("2026-10-03", byDay["2026-10-03"]);
    assert.deepEqual(back, rows.slice(0, 2));
  });

  test("days between two instants (UTC days)", () => {
    assert.deepEqual(
      w.daysBetween(Date.parse("2026-10-01T00:00:00Z"), Date.parse("2026-10-04T00:00:00Z")),
      ["2026-10-01", "2026-10-02", "2026-10-03"],
    );
  });

  test("in-service suggestion = first day after the last gap of 3+ days", () => {
    // This station's real pattern: one reading 19 Aug, 3–25 Sep, off 26 Sep–1 Oct, 2 Oct on.
    const days = [{ day: "2026-08-19", hours: 1 }];
    for (let d = 3; d <= 25; d++) days.push({ day: `2026-09-${String(d).padStart(2, "0")}`, hours: 24 });
    for (let d = 2; d <= 13; d++) days.push({ day: `2026-10-${String(d).padStart(2, "0")}`, hours: 24 });
    const s = w.suggestInServiceFrom(days);
    assert.equal(s.date, "2026-10-02");
    assert.equal(s.lastBefore, "2026-09-25");
    assert.equal(s.gapDays, 6);
    // No gap → no suggestion; a 2-day outage isn't a move.
    assert.equal(w.suggestInServiceFrom([{ day: "2026-10-01", hours: 24 }, { day: "2026-10-04", hours: 24 }]), null);
  });
});

// ── Archive against the Firestore emulator ──────────────────────────────────
const emu = !!process.env.FIRESTORE_EMULATOR_HOST;

describe("weather archive (Firestore emulator)", { skip: !emu && "FIRESTORE_EMULATOR_HOST not set" }, () => {
  const { initializeApp, getApps } = require("firebase-admin/app");
  if (emu && !getApps().length) initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  const { getFirestore } = require("firebase-admin/firestore");
  const NOW = Date.parse("2026-10-14T08:00:00Z");
  let providerCalls;
  let powerCalls;

  // A fake provider: hourly readings 25 Sep (pre-install) and 2–14 Oct.
  const registry = {
    async callForStation(_g, endpoint, p) {
      if (endpoint === "weather/range") return { range: { minDate: "2026-09-25", maxDate: "2026-10-14" } };
      providerCalls.push(p);
      const from = Date.parse(p.start);
      const to = Date.parse(p.end);
      const pts = [];
      for (let t = from; t < Math.min(to, NOW); t += 3600000) {
        const day = new Date(t).toISOString().slice(0, 10);
        if (day === "2026-09-25" || day >= "2026-10-02") pts.push({ x: new Date(t).toISOString(), y: 20 + (t / 3600000) % 7 });
      }
      return { series: ["air_temperature", "humidity", "rainfall", "wind_speed"].map((id) => ({ id, data: pts })) };
    },
    async describe() { return [{ name: "Test station", location: { lat: -0.3, lon: 36 } }]; },
  };
  const fetchImpl = async (url) => {
    powerCalls++;
    const u = new URL(url);
    const p = { T2M: {}, RH2M: {}, WS2M: {}, PRECTOTCORR: {} };
    const start = Date.parse(`${u.searchParams.get("start").replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3")}T00:00:00Z`);
    const end = Date.parse(`${u.searchParams.get("end").replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3")}T00:00:00Z`) + 864e5;
    for (let t = start; t < end; t += 3600000) {
      const k = new Date(t).toISOString().replace(/[-:T]/g, "").slice(0, 10);
      const published = t < NOW - 2.5 * 864e5;
      for (const name of Object.keys(p)) p[name][k] = published ? 10 : -999;
    }
    return { ok: true, json: async () => ({ properties: { parameter: p } }) };
  };

  test("first request fetches and saves; the next one is served from the archive (today refreshed)", async () => {
    const db = getFirestore();
    await db.recursiveDelete(db.collection("weatherArchive"));
    await db.doc("weatherStations/gw1").set({ label: "Test", inServiceFrom: "2026-10-02" });
    providerCalls = [];
    powerCalls = 0;
    const fns = w.createWeatherHistoryFunction({
      registry, NUASENSE_KEY: { value: () => "k" }, getOwnedStationIds: async () => ["gw1"],
      getAllPlatformStationIds: async () => ["gw1"], isAgronomist: async () => false, isPlatformAdmin: async () => false,
      fetchImpl,
    });
    const start = Date.parse("2026-10-02T00:00:00Z");
    const end = Date.parse("2026-10-15T00:00:00Z");
    const first = await fns.hoursFor("gw1", start, end, { lat: -0.3, lon: 36 }, NOW);
    assert.equal(providerCalls.length, 1);
    assert.equal(first.station.length, 12 * 24 + 8); // 2–13 Oct + 8 h today
    assert.ok(first.satellite.length > 0);
    const archived = await db.collection("weatherArchive/gw1/days").get();
    assert.equal(archived.size, 13);
    assert.equal(powerCalls, 1);

    providerCalls = [];
    powerCalls = 0;
    const again = await fns.hoursFor("gw1", start, end, { lat: -0.3, lon: 36 }, NOW);
    // Only yesterday + today come from the provider again (still being recorded).
    assert.equal(providerCalls.length, 1);
    assert.equal(providerCalls[0].start, "2026-10-13T00:00:00.000Z");
    assert.equal(again.station.length, first.station.length);
    assert.deepEqual(again.station.map((h) => h.t), first.station.map((h) => h.t));
    // Complete satellite days come from the archive; at most the one day
    // NASA was still publishing is asked for again.
    assert.ok(powerCalls <= 1);
    assert.ok(again.satellite.length >= first.satellite.length);
  });
});
