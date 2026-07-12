# Unit Coverage Report

- Generated: 2026-07-07
- Command: `flutter test --coverage`
- Gate: 95% or higher
- Result: 907/950 lines (95.47%)

## Scope

This report measures unit-testable Dart logic: domain models, snapshot storage, export formatting, preference controllers, theme tokens, and small monetization value objects. Generated localization files, Flutter UI widgets, Firebase/AdMob runtimes, and iOS MethodChannel adapters are intentionally excluded from this unit coverage gate and remain covered by widget/integration/manual release checks.

## Files

| File | Covered | Total | Coverage |
| --- | ---: | ---: | ---: |
| `lib/src/data/library_snapshot_repository.dart` | 26 | 26 | 100.00% |
| `lib/src/domain/apple_music_link.dart` | 22 | 22 | 100.00% |
| `lib/src/domain/library_overview.dart` | 190 | 198 | 95.96% |
| `lib/src/domain/library_snapshot.dart` | 186 | 211 | 88.15% |
| `lib/src/domain/library_track.dart` | 70 | 76 | 92.11% |
| `lib/src/domain/music_library_authorization.dart` | 10 | 10 | 100.00% |
| `lib/src/domain/music_stats_state.dart` | 7 | 7 | 100.00% |
| `lib/src/export/library_exporter.dart` | 99 | 99 | 100.00% |
| `lib/src/monetization/ad_consent_state.dart` | 1 | 2 | 50.00% |
| `lib/src/monetization/monetization_config.dart` | 6 | 7 | 85.71% |
| `lib/src/settings/app_preferences.dart` | 29 | 29 | 100.00% |
| `lib/src/settings/library_filter_preferences.dart` | 118 | 120 | 98.33% |
| `lib/src/settings/snapshot_preferences.dart` | 38 | 38 | 100.00% |
| `lib/src/theme/app_theme.dart` | 105 | 105 | 100.00% |
