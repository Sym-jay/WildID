# WildID

**Is it protected?** WildID is an Android-first Flutter app for the Zoological Survey of India.
Take a photo of a fish, shark or ray and it tells you within seconds whether the species is
protected under India's Wildlife (Protection) Act, 1972 (Schedule I or II), how sure it is,
and what to do. Every check is saved as a report with time and GPS for expert review.

It covers **65 protected species** of India's seas and rivers (sharks, rays, guitarfish,
sawfish, seahorses, groupers and snakeheads), identified by a PyTorch EfficientNet-B0 model
served from a Flask API on Google Cloud Run.

Users: field officers and researchers checking a catch or seizure, and fishers and coastal
communities reporting a catch. See [PRODUCT.md](PRODUCT.md) for the product brief.

## What the app does

- **Identify**: camera or gallery photo → full-width verdict band (red Schedule I, orange
  Schedule II, amber "can't tell, retake", green not listed), the matched species with
  confidence, and other likely matches.
- **Reports**: every identification is saved on the phone (SQLite) with the photo and GPS
  location; add where it was found, whether it was alive, depth and notes; export as CSV.
- **Species**: search and filter the 65 species by name or schedule, with protection advice
  and IUCN Red List links.
- **Expert review**: confirm or correct uncertain reports.
- **Accounts**: email and password (PBKDF2-hashed, on the device), SMS one-time code via the
  backend, or guest mode.
- Light and dark themes, large touch targets, screen-reader labels; works at sea without
  signal except for identification itself (see Limitations).

## Repository layout

```
Frontend/ZSI_Frontend/   Flutter app (lib/, test/, e2e/ Playwright, integration_test/ Patrol)
Backend/ZSI_Backend/     Flask API (api.py, api_extended.py), OTP, SMS, tests, Dockerfile
Backend/*.py             Model training scripts
docs/project/            College project report, presentation outline, abstract
docs/archive/            Earlier status reports and guides (historical, not current)
.github/workflows/       CI: Flutter, Playwright, Android build, backend tests
```

## Quick start

Requires Flutter 3.50 (stable). The demo build needs no server or key: identification
returns a clearly labelled sample result.

```bash
cd Frontend/ZSI_Frontend
flutter pub get
flutter run --dart-define=ZSI_DEMO=true
```

Against a real API:

```bash
flutter run --dart-define=ZSI_API_KEY=<key> [--dart-define=ZSI_API_BASE_URL=http://10.0.2.2:5000]
```

| Build setting | Purpose |
|---|---|
| `ZSI_API_KEY` | Key the app sends as `X-API-Key` (no default) |
| `ZSI_API_BASE_URL` | API address; defaults to the Cloud Run service |
| `ZSI_DEMO=true` | Sample results without a server (presentations, tests) |

## Backend

```bash
cd Backend/ZSI_Backend
python -m venv venv && venv/Scripts/activate     # source venv/bin/activate on Linux/macOS
pip install -r requirements-server.txt
```

The trained weights are not in git; copy them into `Backend/ZSI_Backend/models/`
(see [models/README.md](Backend/ZSI_Backend/models/README.md)). Then set `ZSI_API_KEY`,
`ZSI_OTP_SECRET` (and `ZSI_OTP_DEV_ECHO=1` for local testing only) and run
`python api_extended.py`.

Deploying to Cloud Run, secrets and SMS setup: [DEPLOY.md](Backend/ZSI_Backend/DEPLOY.md).
Training: [README_TRAINING.md](Backend/ZSI_Backend/README_TRAINING.md) and
[ENSEMBLE_TRAINING_GUIDE.md](Backend/ZSI_Backend/ENSEMBLE_TRAINING_GUIDE.md).

## 🧪 Testing

```bash
cd Frontend/ZSI_Frontend
flutter test                                      # unit and widget tests
```

**Browser end-to-end tests (Playwright).** These run against the web build in demo mode
(`ZSI_DEMO=true` returns a labelled sample result, so no API key is needed), on Pixel 7
(light and dark) and iPhone 14 screen sizes, including screenshot comparisons:

```bash
cd Frontend/ZSI_Frontend
flutter build web --dart-define=ZSI_DEMO=true
cd e2e
npm install
npx playwright install chromium
npm run test:e2e              # npm run test:e2e:update  to refresh screenshots
```

Playwright drives browsers only. GPS, permission dialogs and on-device storage are covered by
the native Android test below.

**Native Android end-to-end test (Patrol).** Runs on an emulator or phone and checks the real
location permission dialog, the GPS fix, the SQLite database and saved photo files (reloaded as
on a cold start), and expert verification. The photo is supplied through the image picker's
test interface; the camera app's own shutter UI is not driven.

```bash
dart pub global activate patrol_cli 4.8.0
cd Frontend/ZSI_Frontend
adb uninstall com.example.zsi_app   # remove any manually installed build first
adb emu geo fix 76.27 9.96          # optional: put the emulator at Kochi
patrol test -t integration_test/app_flow_test.dart --dart-define=ZSI_DEMO=true
```

Requirements: Android SDK (API 34+ image), JDK 17. The Android project uses Gradle 9.5,
Android Gradle Plugin 9.3.1 and Kotlin 2.4 as required by current Flutter. On Windows, if
Gradle fails with "Unable to establish loopback connection", set
`JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:/tmp` (a short path without spaces).

**Backend:** `python -m unittest discover -s tests` in `Backend/ZSI_Backend` (the server
smoke test runs when the server requirements are installed).

**CI** runs the Flutter tests, Playwright (without pixel comparisons), an Android debug
build and the backend tests on every pull request.

## Building a release

```bash
cd Frontend/ZSI_Frontend
flutter build apk --release --dart-define=ZSI_API_KEY=<key>
```

Without `android/key.properties` the release build is signed with the debug key; it is not
ready for the Play Store yet (see Limitations).

## Limitations

- Identification needs a network connection; there is no on-device model yet.
- Accounts exist only on the phone they were created on; there is no user server.
- The API key is built into the app, so it limits casual misuse, not a determined attacker.
- Not ready for the Play Store: the app ID is still `com.example.zsi_app` and there is no
  release signing key.
- Species data has been corrected against FishBase and IUCN but should be checked by a ZSI
  expert; "Bull Ray" (*Aetomyleus milvus*) in particular could not be matched to a valid name.
- Model accuracy figures in the archived reports have not been re-measured.

## License

No license has been chosen yet, so all rights are reserved by the authors.
