import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const webAppFontFamily = 'SongBrief UI';
Future<void>? _preparation;

/// Web's automatic CJK fallback arrives in many shards and invalidates text
/// layouts after the first content frame. Register one local font beforehand.
/// Native platforms continue to use their system fonts.
Future<void> prepareAppTypography() {
  if (!kIsWeb) return Future<void>.value();
  return _preparation ??= _loadWebFont();
}

Future<void> _loadWebFont() async {
  try {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        'Noto Sans JP',
      ], await rootBundle.loadString('assets/fonts/OFL-NotoSansJP.txt'));
    });
    final loader = FontLoader(webAppFontFamily)
      ..addFont(rootBundle.load('assets/fonts/SongBriefUI.woff2'));
    await loader.load();
  } catch (error, stack) {
    // A failed asset must not prevent the app from starting. The existing
    // system/engine fallback remains available if registration fails.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'SongBrief typography',
      ),
    );
  }
}
