# SongBrief

SongBrief is a Flutter/Riverpod prototype for a SongsInfo-style iOS music
library statistics app.

The current MVP reads iOS Music library metadata through a Swift
`MPMediaLibrary`/`MPMediaQuery` bridge and renders rankings in Flutter.
Non-iOS platforms use sample data so the dashboard can be developed without an
iPhone attached.

## Current Scope

- Track ranking by play count
- Artist and album aggregations
- Recent plays from `lastPlayedDate`
- Total tracks, plays, skips, and estimated listening hours
- Music library authorization flow on iOS
- Lightweight glass UI using `liquid_glass_renderer` `FakeGlass`

## Architecture

- `lib/src/data`: platform channel and repository
- `lib/src/domain`: track, authorization, and aggregate models
- `lib/src/features/home`: Riverpod controllers and dashboard UI
- `ios/Runner/MusicLibraryBridge.swift`: native iOS Music library bridge

The Flutter channel is named `app.songbrief/music_library`.

## iOS Notes

The app needs `NSAppleMusicUsageDescription` because it reads the user's Music
library play counts, skip counts, and last played dates. The native bridge uses
`MPMediaQuery.songs()` and returns one map per `MPMediaItem`.

This does not reconstruct every historical play event. It reads the counters
that iOS exposes and can later store snapshots to calculate day-by-day deltas.

## Daily Snapshot Notes

SongBrief saves a local daily snapshot whenever the iOS Music library is
scanned in the app. Each snapshot stores the cumulative counters exposed by iOS
so the app can compare the latest scan with the previous scan and show observed
play-count deltas.

Local snapshot history is stored as one JSON file per day under the app's
Application Support directory (`SongBrief/Snapshots`). Settings remain in
SharedPreferences/UserDefaults, but the listening-record payload no longer uses
a single UserDefaults JSON string. This keeps large libraries from forcing
multi-megabyte preference rewrites and allows cleanup to delete only the
affected day files.

The iOS app also registers a `BGAppRefreshTask` to attempt a daily background
snapshot. iOS decides whether and when that task actually runs, so foreground
launch, resume, and manual refresh scans remain the reliable source of truth.
When scans are several days apart, the app treats the result as an observed
multi-day window rather than exact per-day listening history.

## iCloud Sync Notes

Daily records can sync through the user's private CloudKit database
(`iCloud.app.songbrief.songbrief`, record type `DailySnapshot`, one record per
day keyed by the local dateKey). Counters are monotonic, so devices converge by
max-merging totals and per-track counters regardless of sync order. Sync runs
after each library scan, and the background refresh task uploads its own day
best effort. Deleting history inside the app also deletes the matching cloud
records so cleared data does not resurface on the next sync. Users can opt out
with the "Sync records with iCloud" toggle in settings (stored under
`songbrief_snapshot_cloud_sync_enabled_v1`, default on).

Cloud sync fetches deterministic daily record IDs rather than using CloudKit
queries. It checks all locally known days plus a trailing 1,095-day window, so
normal multi-device use and reinstall recovery cover roughly three years
without requiring query indexes.

Release checklist for this feature:

- In Apple Developer > Identifiers, enable iCloud / CloudKit for
  `app.songbrief.songbrief` and assign the `iCloud.app.songbrief.songbrief`
  Cloud Container. Changing this capability invalidates existing provisioning
  profiles, so regenerate profiles or let Xcode/GitHub Actions automatic
  signing recreate them before the next upload.
- In CloudKit Database, the Development and Production schemas must include
  record type `DailySnapshot` with fields: `payload` (String),
  `capturedAtMillis` (Int64), `trackCount` (Int64), `totalPlayCount` (Int64),
  `totalSkipCount` (Int64), and `totalListeningSeconds` (Int64).
- After modifying the Development schema, deploy it to Production in CloudKit
  Dashboard before the App Store build (Console > CloudKit > Deploy Schema
  Changes).
- No query indexes are required: sync fetches records by deterministic
  record IDs (dateKeys) instead of running CloudKit queries.

## Liquid Glass Notes

Native iOS Liquid Glass APIs such as SwiftUI `.glassEffect` are not directly
available inside Flutter widgets. The MVP uses `FakeGlass` for a similar, lower
cost visual layer. If exact iOS 26 Liquid Glass behavior becomes a priority, add
a small SwiftUI platform view for specific surfaces instead of rewriting the app.

## Validation

```sh
flutter analyze
flutter test
```

## Crash Reporting Notes

Crash reporting uses Firebase Crashlytics and is controlled by both a build
flag and an in-app setting. Local debug builds disable the Crashlytics path by
default. TestFlight and release builds can make the setting available with:

```sh
flutter run --release \
  --dart-define=SONGBRIEF_FIREBASE_CRASHLYTICS_ENABLED=true
```

The in-app setting defaults to off. When enabled, Crashlytics may receive crash
stack traces, app state, device/OS information, and the SongBrief app version.
Do not add track titles, artist names, album names, playlist names, lyrics, or
music library identifiers to Crashlytics logs, custom keys, or recorded errors.

The iOS `Info.plist` keeps native Crashlytics collection disabled at launch so
collection follows the user's SongBrief setting. Release symbolication may still
require Firebase dSYM upload configuration in CI before App Store release.

## Monetization Notes

Ads are opt-in by launch mode. The default mode is ad-free:

```sh
flutter run --dart-define=SONGBRIEF_AD_MODE=off
flutter run --dart-define=SONGBRIEF_AD_MODE=admobTest
flutter run --dart-define=SONGBRIEF_AD_MODE=admobLive
```

Android `admobLive` builds additionally need
`SONGBRIEF_ADMOB_ANDROID_BANNER_AD_UNIT_ID` after an Android AdMob app and
banner ad unit are created.

`admobTest` uses Google's sample banner ad units. Web and desktop builds show
a quiet ad preview instead of loading the mobile AdMob SDK. Premium purchases
are hidden by default while store monetization is deferred. Ad removal behavior
can still be previewed locally with:

```sh
flutter run --dart-define=SONGBRIEF_AD_MODE=admobTest \
  --dart-define=SONGBRIEF_PREMIUM_UNLOCKED=true
```

The iOS native AdMob App ID is configured in `ios/Flutter/AdMob.xcconfig`.
The production iOS banner ad unit ID is embedded as the app fallback and can be
overridden with `SONGBRIEF_ADMOB_IOS_BANNER_AD_UNIT_ID` when needed.
The TestFlight workflow builds in `admobLive` mode and fails before signing if
the iOS banner ad unit ID is empty, malformed, or still uses Google's sample
publisher ID. Keep production uploads on that workflow so the CI validation
still runs before App Store uploads.
Android still uses Google's sample App ID until an Android AdMob app is created:

- Android: pass `-PSONGBRIEF_ADMOB_ANDROID_APP_ID=ca-app-pub-...~...` to Gradle
  or update the default manifest placeholder in `android/app/build.gradle.kts`

The premium purchase UI remains disabled unless
`SONGBRIEF_PREMIUM_PURCHASES_ENABLED=true` is passed at launch. The future
premium product ID defaults to `songbrief_premium_lifetime` and can be changed
with `--dart-define=SONGBRIEF_PREMIUM_PRODUCT_ID=...`.

## Public Site and Legal Pages

Cloudflare Pages publishes the public SongBrief landing page and App Store legal
pages from `docs/`:

- Landing page: https://songbrief.ruhenheim.org/
- Privacy Policy: https://songbrief.ruhenheim.org/privacy/
- Terms of Use: https://songbrief.ruhenheim.org/terms/
- AdMob app-ads.txt: https://songbrief.ruhenheim.org/app-ads.txt

The GitHub Actions workflow in `.github/workflows/cloudflare-pages.yml`
deploys `docs/` to the Cloudflare Pages project named `songbrief`.

Required GitHub repository secrets:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`

The Cloudflare API token should be scoped to the account and allow Cloudflare
Pages edits. After the first successful deployment, add the custom domain
`songbrief.ruhenheim.org` to the `songbrief` Pages project.
