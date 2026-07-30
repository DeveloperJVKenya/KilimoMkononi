# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Kilimo Mkononi ("Farming in your hands") is a Flutter app for smart farming, with a Firebase backend
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
flutter test test/widget_test.dart  # run a single test file
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
Note: `functions/package.json`'s `lint` script is currently stubbed to `echo 'Skipping lint'` — it does
not actually run ESLint despite `.eslintrc.js` existing and being wired as a `predeploy` step in
`firebase.json`.

## Architecture

### Services layer wraps all external integrations
- `lib/services/` (farmer) and `lib/education/services/` (education) wrap Firestore/Auth/Storage plus
  third-party APIs. Screens should go through these rather than calling APIs directly.
- **AI diagnosis (photo → pest/disease)**: `kindwise_service.dart` calls Kindwise's crop.health /
  plant.id / insect.id endpoints directly from the client (API keys are embedded in that file, not
  proxied — different pattern from the Gemini/NuaSense functions below).
- **AI tutor/quiz/vision (Gemini)**: `gemini_tutor_service.dart`, `gemini_quiz_service.dart`,
  `gemini_vision_helper.dart`, `education_plot_analysis_screen.dart` all call the `askGemini` /
  `askGeminiVision` Cloud Functions (`functions/index.js`) rather than hitting the Gemini API directly,
  so the key stays server-side. **The functions must return the full Gemini response body** (not just
  `{ text }`) — callers read `candidates[0].content.parts[0].text`, and trimming the response breaks
  three of the four callers silently.
- **IoT weather stations (NuaSense)**: `nuasense_service.dart` calls the `getNuaSenseData` callable
  function, which whitelists endpoints and requires an authenticated Firebase user.
- **Climate data**: `nasa_power_service.dart` hits NASA POWER directly.

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

### State / DI
`provider` is used app-wide via `MultiProvider` in `lib/main.dart`, wiring `AuthStateService`,
`UserProfile` (`lib/settings/providers/user_profile_provider.dart`) and `ConnectivityService`.
Routes are named and centralized in `main.dart`'s `MaterialApp.routes`.

### Firebase config
- `firebase.json` wires Firestore rules/indexes, Storage rules, Hosting (`build/web`), and the
  `functions` codebase (`functions/`, predeploy lint).
- `lib/firebase_options.dart` is FlutterFire-generated per-platform config for `kilimomkononi-e1031`
  — regenerate with `flutterfire configure`, don't hand-edit.
- `lib/config.dart` holds the (non-Firebase) OpenWeatherMap key used directly by the client.

## Notes for future changes
- `test/widget_test.dart` is still the unmodified Flutter counter-app template — it does not test this
  app and will fail if run as-is (`MyApp` has no counter). Don't assume it reflects test coverage.
- `lib/enterprise/` currently contains no Dart files — it's a placeholder namespace, not active code.
