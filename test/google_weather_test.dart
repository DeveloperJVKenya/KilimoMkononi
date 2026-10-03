import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/config/push_config.dart';
import 'package:kilimomkononi/services/google_weather_service.dart';
import 'package:kilimomkononi/widgets/google_weather_widgets.dart';

// Shape of the getGoogleWeather "weather" response (raw Google Weather API
// objects, trimmed to the fields the app reads).
Map<String, dynamic> sampleResponse() => {
      'fetchedAt': '2026-09-26T07:00:00Z',
      'current': {
        'isDaytime': true,
        'weatherCondition': {
          'iconBaseUri': 'https://maps.gstatic.com/weather/v1/drizzle',
          'description': {'text': 'Light rain'},
          'type': 'LIGHT_RAIN',
        },
        'temperature': {'degrees': 19.6, 'unit': 'CELSIUS'},
        'feelsLikeTemperature': {'degrees': 19.1},
        'dewPoint': {'degrees': 15.2},
        'relativeHumidity': 82,
        'uvIndex': 3,
        'precipitation': {
          'probability': {'percent': 70, 'type': 'RAIN'},
          'qpf': {'quantity': 1.4, 'unit': 'MILLIMETERS'},
        },
        'wind': {
          'direction': {'degrees': 45, 'cardinal': 'NORTH_EAST'},
          'speed': {'value': 11, 'unit': 'KILOMETERS_PER_HOUR'},
          'gust': {'value': 24},
        },
        'cloudCover': 88,
      },
      'hours': [
        for (var i = 0; i < 24; i++)
          {
            'interval': {'startTime': DateTime.utc(2026, 9, 26, 7).add(Duration(hours: i)).toIso8601String()},
            'temperature': {'degrees': 18.0 + i % 6},
            'precipitation': {'probability': {'percent': i * 4 % 100}, 'qpf': {'quantity': 0.2}},
            'weatherCondition': {'type': 'CLOUDY', 'description': {'text': 'Cloudy'}, 'iconBaseUri': ''},
          },
      ],
      'days': [
        for (var i = 0; i < 7; i++)
          {
            'displayDate': {'year': 2026, 'month': 9, 'day': 26 + i > 30 ? 26 + i - 30 : 26 + i},
            'maxTemperature': {'degrees': 25.0 + i},
            'minTemperature': {'degrees': 12.0},
            'daytimeForecast': {
              'relativeHumidity': 60,
              'precipitation': {'probability': {'percent': 30}, 'qpf': {'quantity': 2.0}},
              'wind': {'speed': {'value': 9}},
              'weatherCondition': {'type': 'THUNDERSTORM', 'description': {'text': 'Thunderstorms'}},
            },
            'nighttimeForecast': {
              'precipitation': {'probability': {'percent': 55}, 'qpf': {'quantity': 3.0}},
            },
          },
      ],
    };

void main() {
  group('GoogleWeather parsing', () {
    final w = GoogleWeather.fromResponse(sampleResponse());

    test('current conditions (metric, km/h wind)', () {
      expect(w.current.temp, 19.6);
      expect(w.current.humidity, 82);
      expect(w.current.rainChance, 70);
      expect(w.current.rainMm, 1.4);
      expect(w.current.windKmh, 11);
      expect(w.current.windDirection, 'NORTH EAST');
      expect(w.current.condition.description, 'Light rain');
      expect(w.current.condition.bucket, 'rain');
      expect(w.current.condition.iconUrl(), 'https://maps.gstatic.com/weather/v1/drizzle.png');
      expect(w.fromCache, isFalse);
    });

    test('24 hours and 7 days; daily rain = worse of day / night, total mm', () {
      expect(w.hours, hasLength(24));
      expect(w.days, hasLength(7));
      expect(w.days.first.date, DateTime(2026, 9, 26));
      expect(w.days.first.rainChance, 55);
      expect(w.days.first.rainMm, 5.0);
      expect(w.days.first.condition.bucket, 'storm');
    });

    test('missing fields never throw', () {
      final empty = GoogleWeather.fromResponse({'current': {}, 'hours': [{}], 'days': [{}]});
      expect(empty.current.temp, 0);
      expect(empty.hours, isEmpty);
      expect(empty.days, isEmpty);
      expect(empty.current.condition.iconUrl(), isNull);
    });

    test('cache cells are ~1 km', () {
      expect(GoogleWeatherService.cellKey(-1.28341, 36.81712),
          GoogleWeatherService.cellKey(-1.28049, 36.81901));
    });
  });

  test('VAPID key: set once in code; empty means the Firebase SDK default', () {
    // No --dart-define in tests, and the project key placeholder is empty.
    final key = fcmWebVapidKey;
    expect(key == null || key.length > 60, isTrue);
  });

  group('layout at 360px', () {
    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('Weather screen pieces render without overflow', (tester) async {
      await phone(tester);
      final w = GoogleWeather.fromResponse(sampleResponse());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          // Non-lazy, so every card is built and laid out.
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
            GoogleCurrentCard(weather: w, place: 'Nakuru, Nakuru County — a long place name to test ellipsis'),
            GoogleHourlyStrip(hours: w.hours),
            GoogleDailyList(days: w.days),
            ]),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Google Weather · area forecast'), findsWidgets);
      expect(find.text('20°C'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('source badges keep station and Google apart', (tester) async {
      await phone(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            WeatherSourceBadge(WeatherSource.station),
            WeatherSourceBadge(WeatherSource.google),
          ]),
        ),
      ));
      expect(find.text('Weather station · measured on your farm'), findsOneWidget);
      expect(find.text('Google Weather · area forecast'), findsOneWidget);
    });
  });
}
