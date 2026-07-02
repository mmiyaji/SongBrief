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

The iOS app also registers a `BGAppRefreshTask` to attempt a daily background
snapshot. iOS decides whether and when that task actually runs, so foreground
launch, resume, and manual refresh scans remain the reliable source of truth.
When scans are several days apart, the app treats the result as an observed
multi-day window rather than exact per-day listening history.

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

## Monetization Notes

Ads are opt-in by launch mode. The default mode is ad-free:

```sh
flutter run --dart-define=SONGBRIEF_AD_MODE=off
flutter run --dart-define=SONGBRIEF_AD_MODE=admobTest
flutter run --dart-define=SONGBRIEF_AD_MODE=admobLive \
  --dart-define=SONGBRIEF_ADMOB_IOS_BANNER_AD_UNIT_ID=ca-app-pub-5321136982470738/2315074663 \
  --dart-define=SONGBRIEF_ADMOB_ANDROID_BANNER_AD_UNIT_ID=ca-app-pub-.../...
```

`admobTest` uses Google's sample banner ad units. Web and desktop builds show
a quiet ad preview instead of loading the mobile AdMob SDK. Premium removal can
be previewed with:

```sh
flutter run --dart-define=SONGBRIEF_AD_MODE=admobTest \
  --dart-define=SONGBRIEF_PREMIUM_UNLOCKED=true
```

The iOS native AdMob App ID is configured in `ios/Flutter/AdMob.xcconfig`.
Android still uses Google's sample App ID until an Android AdMob app is created:

- Android: pass `-PSONGBRIEF_ADMOB_ANDROID_APP_ID=ca-app-pub-...~...` to Gradle
  or update the default manifest placeholder in `android/app/build.gradle.kts`

The premium product ID defaults to `songbrief_premium_lifetime` and can be
changed with `--dart-define=SONGBRIEF_PREMIUM_PRODUCT_ID=...`.

## Legal Pages

GitHub Pages publishes the App Store legal pages from `docs/`:

- Privacy Policy: https://mmiyaji.github.io/SongBrief/privacy/
- Terms of Use: https://mmiyaji.github.io/SongBrief/terms/
