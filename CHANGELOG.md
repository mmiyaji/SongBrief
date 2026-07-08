# Changelog

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
