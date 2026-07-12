import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/library_snapshot.dart';

class HomeWidgetSummary {
  const HomeWidgetSummary({
    required this.latestCapturedAtMillis,
    required this.snapshotCount,
    required this.playDelta,
    required this.skipDelta,
    required this.listeningSecondsDelta,
    required this.observedDays,
    this.topTrackTitle,
    this.topTrackArtist,
    this.topTrackPlayDelta = 0,
  });

  final int latestCapturedAtMillis;
  final int snapshotCount;
  final int playDelta;
  final int skipDelta;
  final int listeningSecondsDelta;
  final int observedDays;
  final String? topTrackTitle;
  final String? topTrackArtist;
  final int topTrackPlayDelta;

  static HomeWidgetSummary? fromHistory(SnapshotHistory history) {
    final latest = history.latest;
    if (latest == null) {
      return null;
    }
    final delta = history.latestDelta;
    final topTrack = delta?.trackDeltas.firstOrNull;
    return HomeWidgetSummary(
      latestCapturedAtMillis: latest.capturedAt.millisecondsSinceEpoch,
      snapshotCount: history.snapshotCount,
      playDelta: delta?.totalPlayDelta ?? 0,
      skipDelta: delta?.totalSkipDelta ?? 0,
      listeningSecondsDelta: delta?.totalListeningSecondsDelta ?? 0,
      observedDays: delta?.observedDays ?? 0,
      topTrackTitle: topTrack?.title,
      topTrackArtist: topTrack?.artist,
      topTrackPlayDelta: topTrack?.playDelta ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'latestCapturedAtMillis': latestCapturedAtMillis,
      'snapshotCount': snapshotCount,
      'playDelta': playDelta,
      'skipDelta': skipDelta,
      'listeningSecondsDelta': listeningSecondsDelta,
      'observedDays': observedDays,
      if (topTrackTitle != null) 'topTrackTitle': topTrackTitle,
      if (topTrackArtist != null) 'topTrackArtist': topTrackArtist,
      'topTrackPlayDelta': topTrackPlayDelta,
    };
  }
}

class HomeWidgetBridge {
  const HomeWidgetBridge._();

  static const _channel = MethodChannel('app.songbrief/music_library');

  static Future<void> update(SnapshotHistory history) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final summary = HomeWidgetSummary.fromHistory(history);
    try {
      await _channel.invokeMethod<void>('updateHomeWidget', {
        'summary': ?summary?.toMap(),
      });
    } on MissingPluginException {
      // Older native builds can safely ignore widget updates.
    } on PlatformException {
      // Widget data is a convenience surface and must not block library scans.
    }
  }
}
