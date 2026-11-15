# SongBrief 1.2.8 store screenshots

Approved style: real app screens with no added copy, device frame, or annotation. Japanese and English each have six views for iPhone, iPad and iPhone Duo (36 images).

- `raw/`: actual production widgets rendered by `tool/capture_store_test.dart` with fictional fixture data, original demo artwork and a Japanese-capable Noto Sans JP font.
- `ja.json`, `en.json`: reproducible storeframe raw-layout configurations.
- `output/<language>/app-store/`: approved opaque PNG files for upload.
- `review-*.jpg`: six-screen contact sheets, reviewed visually at full and reduced size on 2026-11-16 JST. Titles, controls and data are legible; no added captions or important UI covered by overlays. Scroll positions intentionally expose calendar and monthly recap.
- `upload-manifest.json`: exact build, filenames, order, dimensions and SHA-256 hashes; the uploader verifies these before any App Store change.
- `specs/manifest.json`: project-owned normalization of Apple's official screenshot specifications, reviewed 2026-11-16 JST. Required dimensions and formats pass validation for all 36 files. Apple does not state all byte/pixel maxima; these remain unknown in the machine reports. Their `manualReview: pending` and `submissionReady: false` are generator defaults; visual review is recorded here, not represented as Apple acceptance.

Capture: `flutter test tool/capture_store_test.dart --dart-define=SONGBRIEF_SCREENSHOT_MODE=true --no-pub` (requires Japanese-capable font; set SONGBRIEF_PREVIEW_FONT as needed).
Generate each configuration from the storeframe checkout with `npm run generate -- --config <absolute-path-to-ja-or-en.json>`.
Validate using storeframe's `validate(outputDir, specsDir)` API with this project's `specs/` directory, including its officially reviewed Duo target.

Apple specification: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

Only editable draft metadata is changed. Current public resources are protected. All uploaded files must finish processing and match the manifest before review submission.

Release binary: 1.2.8 (2611151724), source c4612f59a6304a01650240543fb411eb8513a7f9. Full release checks and upload: https://github.com/mmiyaji/SongBrief/actions/runs/43740849468
Screenshot upload verification (36 COMPLETE): https://github.com/mmiyaji/SongBrief/actions/runs/43741061241
