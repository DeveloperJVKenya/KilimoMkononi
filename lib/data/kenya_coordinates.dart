// lib/data/kenya_coordinates.dart
//
// GPS coordinates for every Kenya county.
// County names match EXACTLY the keys used in kenya_locations.dart.
//
// Used by FarmLocationService to resolve a farmer's registered county
// into a lat/lng for NASA POWER API calls and IoT node matching.
//
// Coordinates are county centroids (~55 km accuracy is sufficient —
// NASA POWER grid resolution is 0.5° × 0.5°, roughly 55 km).

const Map<String, ({double lat, double lng})> countyCoordinates = {
  'Mombasa':         (lat: -4.0435, lng: 39.6682),
  'Kwale':           (lat: -4.1833, lng: 39.4500),
  'Kilifi':          (lat: -3.6305, lng: 39.8499),
  'Tana River':      (lat: -1.0000, lng: 39.9500),
  'Lamu':            (lat: -2.2694, lng: 40.9020),
  'Taita Taveta':    (lat: -3.3167, lng: 38.4833),
  'Garissa':         (lat: -0.4532, lng: 39.6460),
  'Wajir':           (lat:  1.7471, lng: 40.0573),
  'Mandera':         (lat:  3.9366, lng: 41.8670),
  'Marsabit':        (lat:  2.3284, lng: 37.9899),
  'Isiolo':          (lat:  0.3542, lng: 38.0106),
  'Meru':            (lat:  0.0466, lng: 37.6493),
  'Tharaka Nithi':   (lat: -0.2958, lng: 37.8664),
  'Embu':            (lat: -0.5309, lng: 37.4500),
  'Kitui':           (lat: -1.3667, lng: 38.0100),
  'Machakos':        (lat: -1.5177, lng: 37.2634),
  'Makueni':         (lat: -2.2558, lng: 37.8938),
  'Nyandarua':       (lat: -0.1833, lng: 36.5167),
  'Nyeri':           (lat: -0.4167, lng: 36.9500),
  'Kirinyaga':       (lat: -0.5598, lng: 37.2828),
  "Murang'a":        (lat: -0.7167, lng: 37.1500),
  'Kiambu':          (lat: -1.0314, lng: 36.8312),
  'Turkana':         (lat:  3.1167, lng: 35.5967),
  'West Pokot':      (lat:  1.2500, lng: 35.1167),
  'Samburu':         (lat:  1.0667, lng: 37.0833),
  'Trans Nzoia':     (lat:  1.0561, lng: 34.9506),
  'Uasin Gishu':     (lat:  0.5203, lng: 35.2699),
  'Elgeyo Marakwet': (lat:  0.7167, lng: 35.5167),
  'Nandi':           (lat:  0.1833, lng: 35.1000),
  'Baringo':         (lat:  0.6333, lng: 35.9500),
  'Laikipia':        (lat:  0.2000, lng: 36.7000),
  'Nakuru':          (lat: -0.3031, lng: 36.0800),
  'Narok':           (lat: -1.0833, lng: 35.8667),
  'Kajiado':         (lat: -2.0982, lng: 36.7819),
  'Kericho':         (lat: -0.3667, lng: 35.2833),
  'Bomet':           (lat: -0.7833, lng: 35.3333),
  'Kakamega':        (lat:  0.2827, lng: 34.7519),
  'Vihiga':          (lat:  0.0833, lng: 34.7167),
  'Bungoma':         (lat:  0.5635, lng: 34.5606),
  'Busia':           (lat:  0.4578, lng: 34.1116),
  'Siaya':           (lat:  0.0612, lng: 34.2882),
  'Kisumu':          (lat: -0.0917, lng: 34.7680),
  'Homa Bay':        (lat: -0.5167, lng: 34.4500),
  'Migori':          (lat: -1.0634, lng: 34.4731),
  'Kisii':           (lat: -0.6817, lng: 34.7667),
  'Nyamira':         (lat: -0.5667, lng: 34.9333),
  'Nairobi City':    (lat: -1.2921, lng: 36.8219),
};

/// Returns coordinates for a county name exactly as stored in Firestore.
/// Returns null only if the county name is unrecognised.
({double lat, double lng})? coordinatesForCounty(String county) =>
    countyCoordinates[county];