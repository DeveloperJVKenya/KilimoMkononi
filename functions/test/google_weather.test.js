// Unit tests for functions/google_weather.js (no network).
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const g = require("../google_weather");

describe("validateWeatherRequest", () => {
  test("accepts weather / reverse coordinates and place searches", () => {
    assert.deepEqual(g.validateWeatherRequest({ action: "weather", lat: "-1.28", lon: 36.82 }),
      { action: "weather", lat: -1.28, lon: 36.82 });
    assert.deepEqual(g.validateWeatherRequest({ action: "geocode", query: "  Nakuru " }),
      { action: "geocode", query: "Nakuru" });
  });
  test("rejects bad input", () => {
    assert.throws(() => g.validateWeatherRequest({ action: "weather", lat: 95, lon: 0 }));
    assert.throws(() => g.validateWeatherRequest({ action: "weather", lat: "x", lon: 0 }));
    assert.throws(() => g.validateWeatherRequest({ action: "geocode", query: "" }));
    assert.throws(() => g.validateWeatherRequest({ action: "geocode", query: "x".repeat(121) }));
    assert.throws(() => g.validateWeatherRequest({ action: "delete" }));
  });
});

describe("cacheKey / weatherUrls / placeLabel", () => {
  test("nearby points share a ~1 km cache cell; searches ignore case", () => {
    assert.equal(g.cacheKey({ action: "weather", lat: -1.2834, lon: 36.8171 }),
      g.cacheKey({ action: "weather", lat: -1.2789, lon: 36.8201 }));
    assert.equal(g.cacheKey({ action: "geocode", query: "Nakuru" }), g.cacheKey({ action: "geocode", query: "nakuru" }));
  });
  test("metric current / 7-day / 24-hour lookups", () => {
    const u = g.weatherUrls(-1.28, 36.82, "K");
    assert.match(u.current, /currentConditions:lookup\?key=K&location\.latitude=-1\.28&location\.longitude=36\.82&unitsSystem=METRIC/);
    assert.match(u.days, /forecast\/days:lookup.*days=7&pageSize=7/);
    assert.match(u.hours, /forecast\/hours:lookup.*hours=24&pageSize=24/);
    assert.match(u.history, /history\/hours:lookup.*unitsSystem=METRIC.*hours=24&pageSize=24/);
  });
  test("short place names: town, county", () => {
    const results = [{
      formatted_address: "Kenyatta Ave, Nakuru, Kenya",
      address_components: [
        { long_name: "Nakuru", types: ["locality", "political"] },
        { long_name: "Nakuru County", types: ["administrative_area_level_1", "political"] },
      ],
    }];
    assert.equal(g.placeLabel(results), "Nakuru, Nakuru County");
    assert.equal(g.placeLabel([{ formatted_address: "Somewhere", address_components: [] }]), "Somewhere");
    assert.equal(g.placeLabel([]), null);
  });
});
