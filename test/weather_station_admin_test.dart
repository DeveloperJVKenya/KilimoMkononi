// Weather stations in the admin panel: what the manageWeatherStations
// function returns, and that the app shows names, never coordinates.

import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/weather_station_admin_service.dart';

void main() {
  test('overview stations parse with their farmers and backend-only details', () {
    final s = AdminStation.fromMap({
      'gatewayId': '24E124126C123456',
      'label': null,
      'displayName': 'Weather station 3456',
      'providerId': 'nuasense',
      'providerName': 'NuaSense',
      'registered': false,
      'listedByProvider': true,
      'online': true,
      'lastSeen': '2026-10-06T07:00:00Z',
      'deviceName': '-0.3912, 36.9601',
      'lat': -0.3912,
      'lon': 36.9601,
      'farmers': [
        {'uid': 'u1', 'name': 'Jane Wanjiku', 'email': 'jane@example.com', 'phone': '+254700000000', 'county': 'Nyeri'},
      ],
    });
    expect(s.needsLabel, isTrue);
    expect(s.displayName, 'Weather station 3456');
    expect(s.lat, -0.3912);
    expect(s.farmers.single.displayName, 'Jane Wanjiku');
    expect(s.farmers.single.contact, 'jane@example.com · +254700000000 · Nyeri');
    expect(AdminStation.fromMap({'gatewayId': 'g', 'label': 'Kamau farm', 'displayName': 'Kamau farm'}).needsLabel, isFalse);
  });

  test('providers: key status and auth style, never the key', () {
    final p = StationProvider.fromMap({
      'id': 'coast', 'name': 'Coast', 'baseUrl': 'https://x.example/v1', 'authStyle': 'x-api-key', 'hasKey': true,
    });
    expect(p.authStyle, ProviderAuthStyle.header);
    expect(p.hasKey, isTrue);
    expect(ProviderAuthStyle.from('unknown'), ProviderAuthStyle.bearer);
  });

  test('the farmer app shows the station name the server sends (the admin label)', () {
    final st = NuaStation.fromJson({'gateway_id': 'gw1', 'name': 'Kamau farm', 'lat': -0.39, 'lon': 36.96});
    expect(st.name, 'Kamau farm');
    expect(st.lat, -0.39, reason: 'kept for backend use');
  });

  test('plot locations show the county and pin status, not coordinates', () {
    const pinned = PlotSummary(id: 'p', name: 'Plot 1', latitude: -0.3912, longitude: 36.9601, county: 'Nyeri');
    expect(pinned.locationLabel, 'Nyeri · GPS pin set');
    expect(pinned.locationLabel, isNot(contains('36.96')));
    expect(const PlotSummary(id: 'p', name: 'Plot 2', county: 'Meru').locationLabel, 'Meru');
  });

  test('accounts with several stations: each farm opens the station the farmer chose', () {
    final stations = [
      NuaStation.fromJson({'gateway_id': 'gwA', 'name': 'Upper farm station', 'online': true}),
      NuaStation.fromJson({'gateway_id': 'gwB', 'name': 'Lower farm station'}),
    ];
    const choices = {'Plot 2': 'gwB', 'Plot 3': 'gone'};
    expect(NuaSenseService.stationForPlot(stations, 'Plot 2', choices: choices)?.id, 'gwB');
    // No choice for this farm, or a station the account no longer has → its first station.
    expect(NuaSenseService.stationForPlot(stations, 'Plot 1', choices: choices)?.id, 'gwA');
    expect(NuaSenseService.stationForPlot(stations, 'Plot 3', choices: choices)?.id, 'gwA');
    expect(NuaSenseService.stationForPlot(stations, null, choices: choices)?.id, 'gwA');
    expect(NuaSenseService.stationForPlot(const [], 'Plot 2', choices: choices), isNull);
  });

  test('the admin sees the farms the farmer chose (read-only)', () {
    final f = StationFarmer.fromMap({
      'uid': 'u', 'name': 'Agro', 'farms': ['SingleCrop', 'Plot 2'], 'roles': ['Field Agronomist'],
    });
    expect(f.farms.map(plotLabel), ['Single-crop plot', 'Plot 2']);
    expect(plotLabel(null), 'All farms');
    expect(f.roles, ['Field Agronomist']);
    expect(StationFarmer.fromMap({'uid': 'x'}).farms, isEmpty);
  });
}
