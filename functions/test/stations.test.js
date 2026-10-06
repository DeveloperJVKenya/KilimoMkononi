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
