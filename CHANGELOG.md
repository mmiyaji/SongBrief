# Changelog

## Unreleased

### Added

- Added privacy-safe native diagnostics for background listening-record
  scheduling, capture, CloudKit upload, completion, and error results.
- Added a settings status view and JSONL log export for support investigations.
- Added an in-app recent background activity history that does not require
  exporting diagnostic log files.

### Changed

- Background snapshot requests now use a fixed six-hour minimum opportunity;
  iOS still decides the actual execution time.
- Pending 24-hour requests left by earlier builds are replaced with the new
  six-hour minimum request the next time the app opens.
- Detailed logs rotate daily, expire after 14 days, and are capped at 512 KiB
  per file and 2 MiB in total.
- Simplified the background-recording settings by hiding scheduling details
  and placing support diagnostics in a secondary disclosure.
- Background history now groups duplicate reservations and shows user-facing
  record and iCloud outcomes instead of low-level task lifecycle events.
- Pending background requests are labeled as waiting for iOS instead of
  implying execution at a fixed time.

### Fixed

- A successful local background record is no longer reported as failed when
  its best-effort iCloud upload exceeds the background execution window.
- Background diagnostics no longer share page-storage state with the settings
  scroll position, preventing a type error that rendered a large gray card.

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
  `CFBundleVersion` `2607102045`.
- Added Dart coverage and native iOS unit-test gates to the TestFlight release workflow.
- Added verified Firebase Crashlytics dSYM uploads and retained release dSYMs
  with the workflow artifact for manual recovery.
- Made simulator discovery compatible with current Xcode runners and restored
  simulator test signing so the native test host can launch reliably.

### Release Operations

- Added `filterSignature` (String) to the CloudKit `DailySnapshot` record type
  and deployed the schema change to Production.
- Passed the complete TestFlight workflow, including IPA verification,
  Crashlytics dSYM upload, and App Store Connect upload, in
  [iOS TestFlight #40](https://github.com/mmiyaji/SongBrief/actions/runs/29122438513).
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
