import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/music_library_channel.dart';

void main() {
  test('parses native background refresh diagnostics', () {
    final diagnostics = SnapshotRefreshDiagnostics.fromPlatformValue({
      'availability': 'available',
      'intervalHours': 24,
      'detailedLoggingEnabled': true,
      'retentionDays': 14,
      'logFileCount': 3,
      'logBytes': 4096,
      'nextEarliestBeginAtMillis': 1000,
      'lastEvent': 'task_completed',
      'lastEventAtMillis': 2000,
      'lastTaskStartedAtMillis': 2500,
      'lastSuccessfulCaptureAtMillis': 3000,
    });

    expect(
      diagnostics.availability,
      SnapshotBackgroundRefreshAvailability.available,
    );
    expect(diagnostics.intervalHours, 6);
    expect(diagnostics.detailedLoggingEnabled, isTrue);
    expect(diagnostics.retentionDays, 14);
    expect(diagnostics.logFileCount, 3);
    expect(diagnostics.logBytes, 4096);
    expect(
      diagnostics.nextEarliestBeginAt,
      DateTime.fromMillisecondsSinceEpoch(1000),
    );
    expect(diagnostics.lastEvent, 'task_completed');
    expect(
      diagnostics.lastTaskStartedAt,
      DateTime.fromMillisecondsSinceEpoch(2500),
    );
    expect(diagnostics.hasLogs, isTrue);
  });

  test('malformed diagnostics fall back without throwing', () {
    final diagnostics = SnapshotRefreshDiagnostics.fromPlatformValue({
      'availability': 42,
      'detailedLoggingEnabled': 'true',
      'retentionDays': 0,
      'logFileCount': double.nan,
      'logBytes': double.infinity,
      'nextEarliestBeginAtMillis': double.negativeInfinity,
      'lastEvent': 42,
    });

    expect(
      diagnostics.availability,
      SnapshotBackgroundRefreshAvailability.unsupported,
    );
    expect(diagnostics.intervalHours, 6);
    expect(diagnostics.detailedLoggingEnabled, isFalse);
    expect(diagnostics.retentionDays, 14);
    expect(diagnostics.logFileCount, 0);
    expect(diagnostics.logBytes, 0);
    expect(diagnostics.nextEarliestBeginAt, isNull);
    expect(diagnostics.lastEvent, isNull);
    expect(diagnostics.hasLogs, isFalse);
  });

  test('non-map diagnostics are unsupported', () {
    const expected = SnapshotBackgroundRefreshAvailability.unsupported;

    expect(
      SnapshotRefreshDiagnostics.fromPlatformValue(null).availability,
      expected,
    );
    expect(
      SnapshotRefreshDiagnostics.fromPlatformValue('invalid').availability,
      expected,
    );
  });
}
