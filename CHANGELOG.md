# Changelog

## [1.0.1] - 2026-07-10

Reliability, recovery, and accessibility update for the next App Store release.

### Fixed

- Protected listening records from overlapping refreshes and concurrent snapshot writes.
- Kept local and iCloud snapshot history consistent when filters differ between devices or cloud deletion fails.
- Prevented temporary demo data from being recorded, synced, or managed as real listening history.
- Made App Lock fail closed when authentication times out or cannot be completed.
- Restored full filtered-library playback queues instead of starting single-track queues.
- Added recovery actions for denied Music access and failed library scans.
- Improved chart, heatmap, settings, selection, text-scaling, and dark-theme accessibility.

### Changed

- Updated the source version to `1.0.1+2`. The accepted TestFlight build uses
  `CFBundleVersion` `2607101442`.
- Added Dart coverage and native iOS unit-test gates to the TestFlight release workflow.
- Made simulator discovery compatible with current Xcode runners and restored
  simulator test signing so the native test host can launch reliably.

### Release Operations

- Added `filterSignature` (String) to the CloudKit `DailySnapshot` record type
  and deployed the schema change to Production.
- Passed the complete TestFlight workflow, including IPA verification and App
  Store Connect upload, in
  [iOS TestFlight #37](https://github.com/mmiyaji/SongBrief/actions/runs/29100791603).
- App Store availability and review submission remain pending.

## [1.0.0] - 2026-07-09

Initial App Store release candidate.

### Added

- iOS Music library statistics based on Apple Music / Music app metadata.
- Current playback view with artwork, track details, playback controls, lyrics display, recent plays, and Apple Music / web search links.
- Rankings for tracks, artists, albums, and recent playback, plus rising, rediscovery, and rank-change sections based on daily listening records.
- Overview statistics including total plays, skips, listening time, daily-record trends, listening maps, release-year charts, activity heatmaps, smart lists, recap, diversity, milestones, burnout, and album completion views.
- Library browsing with search, sort, drilldown, playlist and genre views, exclusion rules, and export to CSV / JSON files.
- Daily listening records stored locally as per-day files, with optional private iCloud sync through CloudKit.
- Temporary demo-data mode for users who have not granted Music access or have no songs in the local Music library.
- Settings for theme, appearance, language, app lock, privacy screen, crash reports, ad privacy, cache/history cleanup, iCloud sync, and external links.
- App Store legal pages and public site hosted at `https://songbrief.ruhenheim.org/`.
- Production AdMob configuration, optional Firebase Crashlytics, privacy manifest, and app-ads.txt support.

### Notes

- Premium purchase UI remains disabled for the initial release.
- Daily listening records are observational snapshots. Background refresh is best effort and controlled by iOS.
- SongBrief does not send song titles, artist names, album names, lyrics, playlist names, listening history, or local music identifiers to advertising, analytics, or crash-reporting events.
