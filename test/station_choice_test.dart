// Which station a screen shows: NuaSense station listings (coordinates nested
// under `location`), and the farm / "any farm" choices of StationPreferences
// — what Field Agronomists and admins pick from the station dropdown.

import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/station_preferences.dart';

void main() {
  test('station coordinates: NuaSense nests them under location', () {
    final s = NuaStation.fromJson({
      'gateway_id': 'gw1',
      'name': 'Njoro',
      'location': {'lat': -0.33, 'lon': 35.94, 'elevation_m': 2200},
      'online': true,
    });
    expect(s.id, 'gw1');
    expect(s.name, 'Njoro');
    expect(s.lat, -0.33);
    expect(s.lon, 35.94);

    final flat = NuaStation.fromJson({'gateway_id': 'gw2', 'lat': 1, 'lon': 2, 'online': false});
    expect(flat.lat, 1.0);
    expect(flat.name, 'Station');
  });

  final stations = [
    NuaStation.fromJson({'gateway_id': 'a', 'name': 'A', 'online': true}),
    NuaStation.fromJson({'gateway_id': 'b', 'name': 'B', 'online': true}),
    NuaStation.fromJson({'gateway_id': 'c', 'name': 'C', 'online': true}),
  ];

  test('a farm\'s own choice wins, then the "any farm" choice, then the first station', () {
    const any = StationPreferences.kAnyFarm;
    expect(NuaSenseService.stationForPlot(stations, 'plot1', choices: {'plot1': 'c', any: 'b'})!.id, 'c');
    expect(NuaSenseService.stationForPlot(stations, 'plot2', choices: {'plot1': 'c', any: 'b'})!.id, 'b');
    expect(NuaSenseService.stationForPlot(stations, null, choices: {any: 'b'})!.id, 'b');
    expect(NuaSenseService.stationForPlot(stations, null)!.id, 'a');
  });

  test('a choice of a station the account can no longer see is ignored', () {
    const any = StationPreferences.kAnyFarm;
    expect(NuaSenseService.stationForPlot(stations, 'plot1', choices: {'plot1': 'gone', any: 'c'})!.id, 'c');
    expect(NuaSenseService.stationForPlot(stations, 'plot1', choices: {'plot1': 'gone'})!.id, 'a');
    expect(NuaSenseService.stationForPlot(const [], 'plot1'), isNull);
  });
}
