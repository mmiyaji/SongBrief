import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget extension declares a non-empty bundle name', () {
    final infoPlist = File('ios/SongBriefWidget/Info.plist').readAsStringSync();

    expect(
      infoPlist,
      contains('<key>CFBundleName</key>\n\t<string>\$(PRODUCT_NAME)</string>'),
    );
  });

  test('widget extension does not inherit Runner linker flags', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    for (final configurationId in const [
      '8C2A00112F10001100C0DE01',
      '8C2A00122F10001200C0DE01',
      '8C2A00132F10001300C0DE01',
    ]) {
      final configuration = RegExp(
        '$configurationId.*?buildSettings = \\{(.*?)\\n\\s*\\};',
        dotAll: true,
      ).firstMatch(project);

      expect(configuration, isNotNull, reason: configurationId);
      expect(
        configuration!.group(1),
        contains('OTHER_LDFLAGS = "";'),
        reason: configurationId,
      );
    }
  });

  test('background snapshots use a fixed six-hour earliest request', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      appDelegate,
      contains('private static let refreshIntervalHours = 6'),
    );
    expect(appDelegate, contains('TimeInterval(intervalHours * 60 * 60)'));
    expect(appDelegate, contains('getPendingTaskRequests'));
    expect(appDelegate, contains('pendingRequestToleranceMinutes = 5'));
    expect(appDelegate, contains('event: "schedule_replaced"'));
    expect(appDelegate, contains('reason: "legacy_interval"'));
    expect(
      infoPlist,
      contains('<string>app.songbrief.snapshot-refresh</string>'),
    );
    expect(infoPlist, contains('<string>fetch</string>'));
  });

  test('background diagnostics rotate privacy-safe JSONL files', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final logStoreStart = appDelegate.indexOf('enum SnapshotRefreshLogStore');
    final logStoreEnd = appDelegate.indexOf(
      'private final class SnapshotRefreshCompletion',
    );

    expect(logStoreStart, greaterThanOrEqualTo(0));
    expect(logStoreEnd, greaterThan(logStoreStart));
    final logStore = appDelegate.substring(logStoreStart, logStoreEnd);
    expect(logStore, contains('static let retentionDays = 14'));
    expect(logStore, contains('maximumFileBytes = 512 * 1024'));
    expect(logStore, contains('maximumTotalBytes = 2 * 1024 * 1024'));
    expect(logStore, contains('snapshot-refresh-'));
    expect(logStore, contains('.jsonl'));
    expect(logStore, contains('isExcludedFromBackup = true'));
    expect(logStore, contains('completeUntilFirstUserAuthentication'));
    expect(logStore, isNot(contains('"title"')));
    expect(logStore, isNot(contains('"artist"')));
    expect(logStore, isNot(contains('"playlist"')));
    expect(logStore, isNot(contains('localizedDescription')));
  });
}
