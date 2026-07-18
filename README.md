# SongBrief

SongBrief is a Flutter/Riverpod iOS music-library statistics app for exploring
Apple Music / Music app play counts, skips, recent playback, and listening
trends.

The iOS app reads Music library metadata through a Swift
`MPMediaLibrary`/`MPMediaQuery` bridge and renders the experience in Flutter.
Non-iOS platforms use sample data so the dashboard can be developed and reviewed
without an iPhone attached.

## Release Status

- Latest App Store version: `1.0.0` (currently removed from sale in App Store Connect)
- Next release candidate: `1.0.2` (source build `3`)
- Latest accepted TestFlight upload: `1.0.2` (`CFBundleVersion` `2607120810`),
  built by [iOS TestFlight #48](https://github.com/mmiyaji/SongBrief/actions/runs/29185374799)
  on 2026-07-12
- Public site: https://songbrief.ruhenheim.org/
- Privacy Policy: https://songbrief.ruhenheim.org/privacy/
- Terms of Use: https://songbrief.ruhenheim.org/terms/
- Initial release notes: [docs/release-notes/v1.0.0.md](docs/release-notes/v1.0.0.md)
- Next release notes: [docs/release-notes/v1.0.2.md](docs/release-notes/v1.0.2.md)

Release readiness for `1.0.2`:

- [x] Deploy the `DailySnapshot.filterSignature` String field to the Production
  CloudKit schema.
- [x] Pass Dart coverage, native iOS unit tests, IPA verification, Crashlytics
  dSYM upload, and App Store Connect upload in the TestFlight workflow.
- [x] Register the widget App ID and App Group and install the app and widget
  App Store provisioning profiles in GitHub Actions.
- [x] Run the TestFlight workflow for `1.0.2` and verify the app, widget,
  Crashlytics dSYM upload, and App Store Connect processing.
- [ ] Restore App Store availability under Pricing and Availability.
- [ ] Complete App Store Connect metadata and submit `1.0.2` for review.

## Product Scope

- Current playback view with artwork, playback controls, lyrics, recent plays,
  and Apple Music / web search links
- Track, artist, album, and recent-play rankings with drilldown
- Overview statistics, smart lists, listening maps, activity heatmaps, recaps,
  diversity, milestones, burnout, and album-completion views
- Library browsing with search, sort, playlist and genre views, exclusion rules,
  and CSV / JSON export
- Daily listening records stored locally as per-day files with optional private
  iCloud sync
- Listening-record health with last-record age, iCloud sync status, and manual
  retry
- Weekly, monthly, and yearly recaps with previous-period comparisons,
  listening time, skips, and privacy-aware PNG sharing
- Small and medium iOS home-screen widgets for the latest observed listening
  changes
- Music library authorization flow on iOS and temporary demo-data mode for empty
  or inaccessible libraries
- Theme, appearance, language, app lock, privacy screen, crash report, cache,
  history cleanup, ad privacy, and iCloud sync settings

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

The iOS app also registers a `BGAppRefreshTask` and requests its next opportunity
at least six hours after the current request. This is not a six-hour timer: iOS
decides whether and when the task actually runs, so foreground launch, resume,
and manual refresh scans remain the reliable source of truth. Multiple captures
on the same local date update that day's snapshot. When scans are several days
apart, the app treats the result as an observed multi-day window rather than
exact per-day listening history.

Settings exposes the pending-request state, Background App Refresh availability,
last successful capture, and an optional detailed diagnostic log. Detailed logs
contain only scheduling/result events, counts, durations, and error domain/code;
they never contain song, artist, album, playlist, or library identifiers. Logs
are stored as daily JSONL files under `SongBrief/Logs`, capped at 512 KiB per
file and 2 MiB total, automatically removed after 14 days, excluded from device
backups, and exportable from the app's data-management settings.

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

CloudKit release checklist:

- [x] In Apple Developer > Identifiers, enable iCloud / CloudKit for
  `app.songbrief.songbrief` and assign the `iCloud.app.songbrief.songbrief`
  Cloud Container. Changing this capability invalidates existing provisioning
  profiles, so regenerate profiles or let Xcode/GitHub Actions automatic
  signing recreate them before the next upload.
- [x] In CloudKit Database, keep the Development and Production schemas aligned.
  Both currently include record type `DailySnapshot` with fields: `payload`
  (String), `capturedAtMillis` (Int64), `trackCount` (Int64), `totalPlayCount`
  (Int64), `totalSkipCount` (Int64), `totalListeningSeconds` (Int64), and
  `filterSignature` (String).
- [x] After modifying the Development schema, deploy it to Production in
  CloudKit Dashboard before the App Store build (Console > CloudKit > Deploy
  Schema Changes). The `filterSignature` change was deployed and verified in
  Production on 2026-07-10.
- [ ] In App Store Connect, restore availability under Pricing and Availability
  before submitting the next version for release.
- [x] No query indexes are required: sync fetches records by deterministic
  record IDs (dateKeys) instead of running CloudKit queries.

## Liquid Glass Notes

Native iOS Liquid Glass APIs such as SwiftUI `.glassEffect` are not directly
available inside Flutter widgets. The MVP uses `FakeGlass` for a similar, lower
cost visual layer. If exact iOS 26 Liquid Glass behavior becomes a priority, add
a small SwiftUI platform view for specific surfaces instead of rewriting the app.

## Home Widget Notes

The WidgetKit extension uses bundle ID `app.songbrief.songbrief.widget` and the
App Group `group.app.songbrief.songbrief`. The Flutter app writes a compact
summary of the latest local listening-record delta to shared `UserDefaults`;
the widget never reads the Music library or CloudKit directly. Background
snapshot capture also refreshes the widget's last-record timestamp.

Before creating a release build:

1. Register `app.songbrief.songbrief.widget` as an App ID in Apple Developer.
2. Register `group.app.songbrief.songbrief` and enable it for both the main app
   and widget App IDs.
3. Regenerate the main app provisioning profile because its entitlements now
   include the App Group.
4. Create an App Store provisioning profile for the widget extension and save
   its base64 content as the GitHub secret
   `IOS_PROVISIONING_PROFILE_WIDGET_BASE64`.
5. Update `IOS_PROVISIONING_PROFILE_APP_BASE64` with the regenerated main app
   profile, then run the iOS TestFlight workflow.

## Validation

```sh
flutter analyze
flutter test --coverage
dart run tool/coverage_report.dart coverage/lcov.info test/coverage_report.md
```

The manually dispatched `.github/workflows/ios-testflight.yml` workflow is the
release gate for iOS. It selects an available simulator from `simctl` JSON,
runs the native `RunnerTests` suite with simulator signing enabled, creates and
verifies the production IPA, stores the IPA as a workflow artifact, and uploads
it to App Store Connect when `upload_to_testflight` is enabled. Its optional
`build_number` input overrides `CFBundleVersion`; when omitted, CI uses the UTC
`yyMMddHHmm` timestamp.

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
collection follows the user's SongBrief setting. The TestFlight workflow uses
the Firebase iOS service configuration with the Crashlytics CocoaPod's
`upload-symbols` tool. It requires the release archive to contain
`Runner.app.dSYM`, uploads the archive dSYMs to Firebase, and stores them with
the IPA artifact for manual recovery.

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
