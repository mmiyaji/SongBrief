import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/library_snapshot.dart';

const _homeWidgetTrendDayCount = 7;
const _homeWidgetComparisonDayCount = _homeWidgetTrendDayCount * 2;

class HomeWidgetDailyPlayDelta {
  const HomeWidgetDailyPlayDelta({
    required this.dateKey,
    required this.playDelta,
    required this.listeningSecondsDelta,
    required this.hasData,
  });

  final String dateKey;
  final int playDelta;
  final int listeningSecondsDelta;
  final bool hasData;

  Map<String, Object> toMap() {
    return {
      'dateKey': dateKey,
      'playDelta': playDelta,
      'listeningSecondsDelta': listeningSecondsDelta,
      'hasData': hasData,
    };
  }
}

class HomeWidgetSummary {
  const HomeWidgetSummary({
    required this.latestCapturedAtMillis,
    required this.snapshotCount,
    required this.playDelta,
    required this.skipDelta,
    required this.listeningSecondsDelta,
    required this.observedDays,
    required this.dailyPlayDeltas,
    required this.recent7PlayDelta,
    required this.previous7PlayDelta,
    required this.recent7ListeningSecondsDelta,
    required this.recent7ObservedDays,
    required this.previous7ObservedDays,
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
  final List<HomeWidgetDailyPlayDelta> dailyPlayDeltas;
  final int recent7PlayDelta;
  final int previous7PlayDelta;
  final int recent7ListeningSecondsDelta;
  final int recent7ObservedDays;
  final int previous7ObservedDays;
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
    final comparisonDeltas = _dailyPlayDeltas(
      history,
      dayCount: _homeWidgetComparisonDayCount,
    );
    final recentDeltas = comparisonDeltas
        .skip(_homeWidgetTrendDayCount)
        .toList(growable: false);
    final previousDeltas = comparisonDeltas
        .take(_homeWidgetTrendDayCount)
        .toList(growable: false);
    return HomeWidgetSummary(
      latestCapturedAtMillis: latest.capturedAt.millisecondsSinceEpoch,
      snapshotCount: history.snapshotCount,
      playDelta: delta?.totalPlayDelta ?? 0,
      skipDelta: delta?.totalSkipDelta ?? 0,
      listeningSecondsDelta: delta?.totalListeningSecondsDelta ?? 0,
      observedDays: delta?.observedDays ?? 0,
      dailyPlayDeltas: List.unmodifiable(recentDeltas),
      recent7PlayDelta: _sumAvailable(recentDeltas, (value) => value.playDelta),
      previous7PlayDelta: _sumAvailable(
        previousDeltas,
        (value) => value.playDelta,
      ),
      recent7ListeningSecondsDelta: _sumAvailable(
        recentDeltas,
        (value) => value.listeningSecondsDelta,
      ),
      recent7ObservedDays: recentDeltas.where((value) => value.hasData).length,
      previous7ObservedDays: previousDeltas
          .where((value) => value.hasData)
          .length,
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
      'dailyPlayDeltas': dailyPlayDeltas
          .map((delta) => delta.toMap())
          .toList(growable: false),
      'recent7PlayDelta': recent7PlayDelta,
      'previous7PlayDelta': previous7PlayDelta,
      'recent7ListeningSecondsDelta': recent7ListeningSecondsDelta,
      'recent7ObservedDays': recent7ObservedDays,
      'previous7ObservedDays': previous7ObservedDays,
      if (topTrackTitle != null) 'topTrackTitle': topTrackTitle,
      if (topTrackArtist != null) 'topTrackArtist': topTrackArtist,
      'topTrackPlayDelta': topTrackPlayDelta,
    };
  }

  static List<HomeWidgetDailyPlayDelta> _dailyPlayDeltas(
    SnapshotHistory history, {
    required int dayCount,
  }) {
    final latest = history.latest;
    if (latest == null) {
      return const [];
    }

    final snapshotsByDate = {
      for (final snapshot in history.snapshots) snapshot.dateKey: snapshot,
    };
    final latestLocal = latest.capturedAt.toLocal();
    final latestDate = DateTime(
      latestLocal.year,
      latestLocal.month,
      latestLocal.day,
    );

    return List.unmodifiable([
      for (var dayOffset = dayCount - 1; dayOffset >= 0; dayOffset -= 1)
        _dailyPlayDelta(
          date: DateTime(
            latestDate.year,
            latestDate.month,
            latestDate.day - dayOffset,
          ),
          snapshotsByDate: snapshotsByDate,
        ),
    ]);
  }

  static HomeWidgetDailyPlayDelta _dailyPlayDelta({
    required DateTime date,
    required Map<String, DailyLibrarySnapshot> snapshotsByDate,
  }) {
    final current = snapshotsByDate[snapshotDateKey(date)];
    final previousDate = DateTime(date.year, date.month, date.day - 1);
    final previous = snapshotsByDate[snapshotDateKey(previousDate)];
    final hasData =
        current != null &&
        previous != null &&
        current.filterSignature == previous.filterSignature;
    return HomeWidgetDailyPlayDelta(
      dateKey: snapshotDateKey(date),
      playDelta: hasData
          ? _positiveDifference(current.totalPlayCount, previous.totalPlayCount)
          : 0,
      listeningSecondsDelta: hasData
          ? _positiveDifference(
              current.totalListeningSeconds,
              previous.totalListeningSeconds,
            )
          : 0,
      hasData: hasData,
    );
  }

  static int _sumAvailable(
    Iterable<HomeWidgetDailyPlayDelta> values,
    int Function(HomeWidgetDailyPlayDelta value) select,
  ) {
    return values
        .where((value) => value.hasData)
        .fold(0, (total, value) => total + select(value));
  }

  static int _positiveDifference(int current, int previous) {
    final difference = current - previous;
    return difference < 0 ? 0 : difference;
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
