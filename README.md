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

## Legal Pages

GitHub Pages publishes the App Store legal pages from `docs/`:

- Privacy Policy: https://mmiyaji.github.io/SongBrief/privacy/
- Terms of Use: https://mmiyaji.github.io/SongBrief/terms/
