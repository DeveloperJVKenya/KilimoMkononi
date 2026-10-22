// Unit tests for functions/stations.js (no network).
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const st = require("../stations");

describe("station names shown to farmers", () => {
  test("coordinates are recognised", () => {
    assert.equal(st.looksLikeCoords("-0.3912, 36.9601"), true);
    assert.equal(st.looksLikeCoords("(-1.28; 36.82)"), true);
    assert.equal(st.looksLikeCoords("0.39°S, 36.96°E"), true);
    assert.equal(st.looksLikeCoords("Nyeri farm 2"), false);
  });
  test("the admin's label wins; coordinates are never shown", () => {
    assert.equal(st.stationDisplayName({ name: "-0.39, 36.96" }, "  Kamau's farm ", "A1B2C3D4"), "Kamau's farm");
    assert.equal(st.stationDisplayName({ name: "-0.39, 36.96" }, null, "a1b2c3d4"), "Weather station C3D4");
    assert.equal(st.stationDisplayName({ location: "0.1, 36.2" }, "", "xyz9"), "Weather station XYZ9");
    assert.equal(st.stationDisplayName({ name: "Station" }, null, "ab12"), "Weather station AB12");
    assert.equal(st.stationDisplayName({ name: "Office roof" }, null, "ab12"), "Office roof");
  });
});

describe("providers", () => {
  const p = { baseUrl: "https://api.example.com/v1/", key: "secret-key" };
  test("bearer, header or query key — never anything else in the URL", () => {
    const b = st.providerRequest({ ...p, authStyle: "bearer" }, "weather", { gateway_id: "gw1" });
    assert.equal(b.url, "https://api.example.com/v1/weather?gateway_id=gw1");
    assert.equal(b.headers.Authorization, "Bearer secret-key");
    const h = st.providerRequest({ ...p, authStyle: "x-api-key" }, "stations");
    assert.equal(h.url, "https://api.example.com/v1/stations");
    assert.equal(h.headers["X-API-Key"], "secret-key");
    assert.equal(h.headers.Authorization, undefined);
    const q = st.providerRequest({ ...p, authStyle: "query" }, "stations");
    assert.equal(q.url, "https://api.example.com/v1/stations?api_key=secret-key");
  });
  test("provider input is validated; the key is required only when adding", () => {
    const ok = { name: "Coast stations", baseUrl: "https://api.example.com/v1", apiKey: "abcdefgh12", authStyle: "bearer" };
    assert.equal(st.validateProviderInput(ok, { isNew: true }).name, "Coast stations");
    assert.throws(() => st.validateProviderInput({ ...ok, baseUrl: "http://insecure.example" }, { isNew: true }), /https/);
    assert.throws(() => st.validateProviderInput({ ...ok, apiKey: "" }, { isNew: true }), /API key/);
    assert.equal(st.validateProviderInput({ ...ok, apiKey: "" }, { isNew: false }).apiKey, "");
    assert.throws(() => st.validateProviderInput({ ...ok, authStyle: "magic" }, { isNew: true }), /authentication/);
    assert.equal(st.slug("Coast Stations (2026)!"), "coast-stations-2026");
  });
});

// Shapes as NuaSense's GET /soil/range and GET /soil return them (Oct 2026).
const soilSeries = (type, level, pts) => ({
  id: `0000100006080002 ${type} L${level} (level ${level})`,
  devEui: "0000100006080002", nodeId: "new_cw_2", sensorType: type,
  level: String(level), field: "x", depth: `Level ${level}`,
  data: pts.map(([x, y]) => ({ x, y })),
});

describe("soil sensor", () => {
  test("the admin's answer is attached / none / not confirmed", () => {
    assert.equal(st.soilSensorState("attached"), "attached");
    assert.equal(st.soilSensorState("none"), "none");
    assert.equal(st.soilSensorState(true), null);
    assert.equal(st.soilSensorState(undefined), null);
    assert.equal(st.SOIL_METRICS, "soil_moisture,soil_temperature,soil_ec");
  });

  test("a reporting probe is found, with its types, probes and dates", () => {
    const range = {
      meta: { devEuis: ["0000100006080002"], sensorTypes: ["soil_moisture", "soil_temperature"] },
      range: { minTime: "2026-10-14T13:10:41.956Z", maxTime: "2026-10-15T06:53:58.846Z" },
    };
    const soil = { series: [
      soilSeries("soil_ec", 1, [["2026-10-15T05:00:00Z", 177.5]]),
      soilSeries("soil_moisture", 1, [["2026-10-15T05:00:00Z", 25.975]]),
      soilSeries("soil_temperature", 1, [["2026-10-15T05:00:00Z", 20.6]]),
    ] };
    const s = st.summarizeSoil(range, soil);
    assert.equal(s.found, true);
    assert.deepEqual(s.devEuis, ["0000100006080002"]);
    assert.equal(s.probes, 1);
    assert.deepEqual(s.sensorTypes, ["soil_ec", "soil_moisture", "soil_temperature"]);
    assert.equal(s.firstReading, "2026-10-14T13:10:41.956Z");
    assert.equal(s.lastReading, "2026-10-15T06:53:58.846Z");
  });

  test("two probe channels count as two probes", () => {
    const soil = { series: [
      soilSeries("soil_moisture", 1, [["2026-10-15T05:00:00Z", 25]]),
      soilSeries("soil_moisture", 2, [["2026-10-15T05:00:00Z", 31]]),
    ] };
    const s = st.summarizeSoil({}, soil);
    assert.equal(s.probes, 2);
    assert.equal(s.lastReading, "2026-10-15T05:00:00.000Z");
  });

  test("a station without a soil sensor finds nothing", () => {
    const s = st.summarizeSoil({ meta: { devEuis: [], sensorTypes: [] }, range: {} }, { series: [] });
    assert.equal(s.found, false);
    assert.equal(s.probes, 0);
    assert.equal(st.summarizeSoil(undefined, undefined).found, false);
  });
});
