# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Kilimo Mkononi ("Smart farming at your fingertips") is a Flutter app for smart farming, with a Firebase backend
(Firestore, Auth, Storage, Cloud Functions, Hosting). Targets Android, iOS, macOS, Windows, Linux and
Web from a single `lib/` codebase. Firebase project id: `kilimomkononi-e1031`.

The app has two entirely separate modes selected at `mode_selection.dart`:
- **Farmer mode** — `lib/screens/`, `lib/authentication/`, `lib/home.dart`. Real farm data entry,
  pest/disease diagnosis, weather, market prices.
- **Education mode** — `lib/education/`. A parallel app for schools with its own login/registration/home
  (`education_login.dart`, `education_registration.dart`, `education_home.dart`), further split by tier
  (`primary`, `junior`, `senior`, `eightfourfour` school systems) and role (`student/`, `teacher/`).

## Commands

Flutter app:
```
flutter pub get                     # install dependencies
flutter run -d <chrome|windows|...> # run app
flutter analyze                     # static analysis (flutter_lints)
flutter test                        # run all tests
flutter test test/advisory_test.dart # run a single test file
flutter build apk|appbundle|ios|web|windows|macos|linux
```

Cloud Functions (`functions/`, Node 22):
```
cd functions
npm install
npm run serve   # firebase emulators:start --only functions
npm run shell    # firebase functions:shell
npm run deploy   # firebase deploy --only functions
npm run logs     # firebase functions:log
```
`npm run lint` runs ESLint 10 (flat config in `functions/eslint.config.js`) and is a `predeploy` step in
`firebase.json` — a lint error blocks `firebase deploy`. Functions need Node 22 (`firebase-admin` 14).

## Architecture

### Services layer wraps all external integrations
- `lib/services/` (farmer) and `lib/education/services/` (education) wrap Firestore/Auth/Storage plus
  third-party APIs. Screens should go through these rather than calling APIs directly.
- **No third-party API keys in the client.** Every keyed API goes through a Cloud Function with the
  key in Secret Manager (`firebase functions:secrets:set <NAME>`; names listed at the top of
  `functions/index.js`). Never add a key to Dart code.
- **AI diagnosis (photo → pest/disease)**: `kindwise_service.dart` calls Kindwise's crop.health /
  plant.id / insect.id via the `kindwiseProxy` callable function.
- **AI tutor/quiz/vision (Gemini)**: `gemini_tutor_service.dart`, `gemini_quiz_service.dart`,
  `gemini_vision_helper.dart`, `education_plot_analysis_screen.dart` all call the `askGemini` /
  `askGeminiVision` Cloud Functions (`functions/index.js`) rather than hitting the Gemini API directly,
  so the key stays server-side. These are HTTP functions that **require a Firebase ID token** — send
  `headers: await authJsonHeaders()` (`lib/services/function_auth.dart`) or the call gets a 401. **The functions must return the full Gemini response body** (not just
  `{ text }`) — callers read `candidates[0].content.parts[0].text`, and trimming the response breaks
  three of the four callers silently.
- **IoT weather stations (NuaSense)**: `nuasense_service.dart` calls the `getNuaSenseData` callable
  function, which whitelists endpoints and requires an authenticated Firebase user.
- **Weather (farmer)**: Google Weather API (current, 24 h, 7 days) + Geocoding go through the
  `getGoogleWeather` callable (`functions/google_weather.js`, secret `GOOGLE_WEATHER_KEY`, a key
  restricted to those two APIs) via `lib/services/google_weather_service.dart`; UI pieces in
  `lib/widgets/google_weather_widgets.dart`. The Weather screen uses device location / the farm /
  a typed place; the Weather Station screen shows it next to the station's own readings. Always
  label the two sources (`WeatherSourceBadge`): advisories and alerts come ONLY from station data.
  Education mode still uses OpenWeatherMap via `getOpenWeather` / `open_weather_proxy.dart`.
- **Climate data**: `nasa_power_service.dart` hits NASA POWER directly (no key).

### Offline-first writes
- `offline_queue_service.dart` is the shared offline queue for farmer data writes (field data, pest/
  disease interventions, reminders, costs): try Firestore first, fall back to a SharedPreferences-backed
  queue, auto-sync on reconnect (`connectivity_plus`) or app resume.
- The Farm Management screens (`farm_management_screen.dart` and friends) have their **own**, separate
  offline-first design (SharedPreferences is the primary store, Firestore is just a backup) — do not
  route their writes through `offline_queue_service`.
- `connectivity_service.dart` is provided app-wide via `MultiProvider` in `main.dart`; read it with
  `context.read<ConnectivityService>()` rather than importing `connectivity_plus` directly in screens.

### classId format duality (education mode)
Education Firestore documents key off a school "classId" that appears in two incompatible formats:
- Format A (canonical, stored): `schoolName_system_grade`, e.g. `st_marys_senior_10`.
- Format B (UI/selection): `grade|systemKey`, e.g. `10|cbcSenior`.

`lib/utils/firestore_helper.dart` (`parseClassIdForFirestore`) is the single place that resolves both
formats into `(schoolName, system, grade)`; `class_id_parser.dart` / `class_id_notifier.dart` build on
top of it. Don't hand-roll classId parsing elsewhere.

### Notifications (local + push)
- `lib/services/notification_service.dart` is the only notification setup, initialised once in
  `main.dart`. Every notification uses a `KmChannel` (`NotificationService.details(...)` /
  `.show(...)`) so local reminders and pushes share the icon (`@drawable/ic_stat_km`), colour and
  channels. Don't create `AndroidNotificationDetails` or new channels in screens.
- Push = FCM. `functions/notifications.js`: hourly `weatherAlertSweep` (per assigned station:
  HIGH/CRITICAL alerts, each farmer's copy carrying the verified advisory for *their* crops; plus
  condition-targeted advice when that condition is occurring — once per farmer per advisory,
  repeated at most daily, state in `advisoryDelivery/{uid}_{advisoryId}`), `onAdvisoryPublished`
  (only "Any conditions" advice is pushed at publish time — station farmers growing the crop, or
  crop topics; admin TEST advisories → the admin only), education approval pushes. Every
  per-user push is also written to `userNotifications/{uid}/items` (Notifications → Inbox tab).
  Push `data` (e.g. `gatewayId`) reaches the opened screen via `routeHandler(route, args)`.
- Delivery rules live in `buildMessage`: per-type expiry (weather alerts 6 h, advice 2 days,
  approvals 7 days) so offline phones don't get stale alerts, and collapse keys so a newer alert
  for the same station + hazard replaces the older one.
- Web: the SDK shows background pushes itself; `webpush.fcmOptions.link` opens
  `/?km_route=…` which `NotificationService` reads on start-up (`web/firebase-messaging-sw.js`
  only shows data-only messages). VAPID key: `lib/config/push_config.dart` (public, set once;
  empty = Firebase SDK default key). Browsers get crop topics through the `syncWebTopics` callable.
- Devices: `deviceTokens/{fcmToken} {uid}`; farmers subscribe to `km_farmers` + `km_crop_<slug>`.
  Token registration retries with backoff and on reconnect if it fails (e.g. signed in offline).
  Channel ids, routes and topic slugs must match between Dart and JS —
  `test/notification_contract_test.dart` checks this.
- Local reminders use `AndroidScheduleMode.inexactAllowWhileIdle` (no exact-alarm permission).
  Schedule them ONLY through `ReminderService.schedule` (`lib/services/reminder_service.dart`):
  it stores `field_reminders/{id}` with its `section` and `createdAt`, and honours settings.
  Farm Management tasks get due-date reminders via `ReminderService.syncFarmTaskReminders`.
- Notification Settings are real: `notificationPrefs/{uid}` (`lib/services/notification_prefs.dart`,
  validated in the rules). The server's `deliverToUsers` skips the phone push for users who turned
  a type off (the inbox still records it); the app unsubscribes advice topics and
  `ReminderService.applyPrefs` cancels/restores a section's scheduled reminders.
- Notifications screen + settings use Riverpod (`lib/settings/notifications/notification_providers.dart`);
  colours / date-time helpers in `notification_style.dart` — every item shows its full date and time.
- Tests: `cd functions && npm test` (emulator; FCM is faked) or `npm run test:unit`.
- Deploy functions with `FUNCTIONS_DISCOVERY_TIMEOUT=120 firebase deploy --only functions` — the
  default 10 s code-analysis timeout often fails on a cold start ("An unexpected error").
- IoT soil data is intentionally simulated (`IotDataSource.simulated` in iot_sensor_service.dart).

### State / DI
`provider` is used app-wide via `MultiProvider` in `lib/main.dart`, wiring `AuthStateService`,
`UserProfile` (`lib/settings/providers/user_profile_provider.dart`) and `ConnectivityService`.
Routes are named and centralized in `main.dart`'s `MaterialApp.routes`.

### Firebase config
- `firebase.json` wires Firestore rules/indexes, Storage rules, Hosting (`build/web`), and the
  `functions` codebase (`functions/`, predeploy lint).
- `lib/firebase_options.dart` is FlutterFire-generated per-platform config for `kilimomkononi-e1031`
  — regenerate with `flutterfire configure`, don't hand-edit.
- `firestore.rules` / `storage.rules` deny by default. A new collection or Storage path needs a rule,
  or the app gets permission-denied. Locked fields: `Users.isDisabled` and
  `EducationUsers.{role, approvalStatus, approvedBy, approvedAt, isDisabled, requestedRole,
  schoolName}` — roles only change through the approval chain (mainadmin → headteacher → teacher →
  student). List queries must filter by what the rules check (`userId`, `schoolName`, `gradeId`, …).
- Rules tests: `cd rules-tests && npm install && npm test` (local emulators, demo project; needs Java).
  Update them whenever you change the rules.

## Notes for future changes
- Admin record screens: every dashboard card / tool opens `AdminCollectionScreen`
  (`lib/screens/admin/data/`), configured per collection in `admin_collection_spec.dart` (fields +
  types, filters, sorts, status, allowed actions) with Riverpod state in `admin_data_providers.dart`.
  Add a collection by adding a spec. Edits are typed (never stringify values); actions log to
  `admin_logs`. Only set `serverOrder` when every document has the time field.
- Settings (`lib/settings/`): pages are built from `widgets/settings_kit.dart` (`SettingsPage`,
  `SettingsSection`, `SettingsTile`, `confirmAndLogOut` — every logout asks first) and read the
  profile via `settings_providers.dart`. Contact details live in `KmContact`; `kAppVersion` /
  `kAppBuild` must match pubspec (`test/settings_test.dart`). Appearance (text size, font via
  google_fonts, bold text, reduced motion, compact) is `appearance/appearance.dart`, applied in
  `MyApp` (`appearanceTheme` + `AppearanceScope`). Contact form → `supportMessages` (rules-
  validated; admins reply/set status in the Admin panel; users see replies in Contact us).
  Legal pages keep their text; `widgets/legal_kit.dart` lays them out (header, contents that jump
  to sections, one card per numbered section). Buttons in Settings are `CompactButton` (sized to
  the label, never full width); important changes ask first via `confirmAction`.
- Home navigation: bottom tabs Home / Manuals / Settings under ONE Home app bar (tab screens take
  `embedded: true` and drop their own app bar). Notifications open from the app-bar bell only —
  not a tab or menu item; Help & support lives in Settings, not the menu.
- Farmer auth screens (login, registration, Google "finish setup") share
  `lib/authentication/widgets/auth_kit.dart`: `AuthLayout` (split / card / phone layouts — forms are
  width-capped), `EnterToSubmit` (Enter submits from anywhere; focus jumps to the first invalid field),
  shared fields, validators and Firebase error messages. Build new auth UI from it.
- `lib/enterprise/features/weather/` — **Field Agronomist** role + verified weather advisories.
  - Role: `Agronomists/{uid}` doc, granted by an admin (Admin panel → "Assign Field Agronomist").
    Checked with `AgronomicAdvisoryService.isFieldAgronomist()`; enforced by `isAgronomist()` in the
    rules. Agronomists can read live conditions for every KM station (`getNuaSenseData`).
  - `agronomic_advisories/{id}`: MAIN/DO/AVOID/WHY targeted by crop(s) + weather-condition key
    (`advisory_conditions.dart` — keys are also listed in firestore.rules and in
    `CONDITION_LABELS` / `activeConditions()` in functions/notifications.js; add, never rename;
    `test/notification_contract_test.dart` checks all three agree).
    Status draft → published (= verified; publisher recorded) → archived.
  - Every write goes through `AgronomicAdvisoryService.save`, which writes the advisory and its
    immutable `history/v{version}` audit entry in one transaction — the rules reject one without
    the other. Pass `expectedVersion` (the editor does) so a stale save throws
    `AdvisoryConflictException` instead of overwriting someone else's edit.
  - Farmers are notified on first publish; edits to published advice only re-notify when the
    agronomist ticks "Notify farmers" (`notifyVersion == version`). Verifier/notify fields are
    locked by the rules except when publishing. Deleting a never-published draft deletes its
    history in the same batch; agronomists never see or edit admin TEST advisories.
  - Farmers see published advisories matching their crops (from `fielddata.crops[].type`) and the
    station's live conditions in the Weather Station screen's "Verified advice" section; the AI
    Farm Advisor card below it is labelled "AI-generated · not verified".
  - An offline station (no points in the last 2h) gives `NuaSenseReading.hasData == false` —
    values are placeholder zeros, so only "general" advice applies and no AI/day plan is shown.
  - Tests: `test/advisory_test.dart`, `test/advisory_widgets_test.dart` (layout at 360px),
    advisory cases in `rules-tests/`.
