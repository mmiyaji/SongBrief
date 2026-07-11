import 'library_overview.dart';
import 'library_track.dart';

const librarySnapshotFallbackPreferencesKey =
    'songbrief_daily_snapshots_fallback_v1';
const legacyLibrarySnapshotPreferencesKeys = [
  'songbrief_daily_snapshots_v1',
  'songbrief_daily_snapshots_v2',
];
const maxSnapshotTrackCounters = 500;
const detailedSnapshotHistoryEntries = 400;

class TrackCounterSnapshot {
  const TrackCounterSnapshot({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumTitle,
    required this.playCount,
    required this.skipCount,
    required this.listeningSeconds,
    this.albumArtist,
    this.genre,
    this.lastPlayedAt,
  });

  final String id;
  final String title;
  final String artist;
  final String albumTitle;
  final String? albumArtist;
  final String? genre;
  final int playCount;
  final int skipCount;
  final int listeningSeconds;
  final DateTime? lastPlayedAt;

  factory TrackCounterSnapshot.fromTrack(LibraryTrack track) {
    return TrackCounterSnapshot(
      id: track.id,
      title: track.title,
      artist: track.artist,
      albumTitle: track.albumTitle,
      albumArtist: track.albumArtist,
      genre: track.genre,
      playCount: track.playCount,
      skipCount: track.skipCount,
      listeningSeconds: track.listeningSeconds,
      lastPlayedAt: track.lastPlayedAt,
    );
  }

  factory TrackCounterSnapshot.fromJson(Map<String, Object?> json) {
    return TrackCounterSnapshot(
      id: _readString(json, 'id'),
      title: _readString(json, 'title'),
      artist: _readString(json, 'artist'),
      albumTitle: _readString(json, 'albumTitle'),
      albumArtist: _readNullableString(json, 'albumArtist'),
      genre: _readNullableString(json, 'genre'),
      playCount: _readInt(json, 'playCount'),
      skipCount: _readInt(json, 'skipCount'),
      listeningSeconds: _readInt(json, 'listeningSeconds'),
      lastPlayedAt: _readDate(json, 'lastPlayedAtMillis'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'albumTitle': albumTitle,
      if (albumArtist != null) 'albumArtist': albumArtist,
      if (genre != null) 'genre': genre,
      'playCount': playCount,
      'skipCount': skipCount,
      'listeningSeconds': listeningSeconds,
      if (lastPlayedAt != null)
        'lastPlayedAtMillis': lastPlayedAt!.millisecondsSinceEpoch,
    };
  }
}

class DailyLibrarySnapshot {
  const DailyLibrarySnapshot({
    required this.dateKey,
    required this.capturedAt,
    required this.source,
    required this.trackCount,
    required this.totalPlayCount,
    required this.totalSkipCount,
    required this.totalListeningSeconds,
    required this.tracks,
    this.filterSignature,
  });

  final String dateKey;
  final DateTime capturedAt;
  final String source;
  final int trackCount;
  final int totalPlayCount;
  final int totalSkipCount;
  final int totalListeningSeconds;
  final List<TrackCounterSnapshot> tracks;
  final String? filterSignature;

  factory DailyLibrarySnapshot.fromOverview(
    LibraryOverview overview, {
    DateTime? capturedAt,
    String source = 'foreground',
    String? filterSignature,
  }) {
    final now = capturedAt ?? DateTime.now();
    final tracks = _snapshotTrackCounters(overview);
    return DailyLibrarySnapshot(
      dateKey: snapshotDateKey(now),
      capturedAt: now,
      source: source,
      trackCount: overview.totalTracks,
      totalPlayCount: overview.totalPlayCount,
      totalSkipCount: overview.totalSkipCount,
      totalListeningSeconds: overview.totalListeningSeconds,
      tracks: List.unmodifiable(tracks),
      filterSignature: filterSignature,
    );
  }

  factory DailyLibrarySnapshot.fromJson(
    Map<String, Object?> json, {
    bool includeTracks = true,
  }) {
    final rawTracks = json['tracks'];
    return DailyLibrarySnapshot(
      dateKey: _readString(json, 'dateKey'),
      capturedAt: _readDate(json, 'capturedAtMillis') ?? DateTime.now(),
      source: _readString(json, 'source', fallback: 'foreground'),
      trackCount: _readInt(json, 'trackCount'),
      totalPlayCount: _readInt(json, 'totalPlayCount'),
      totalSkipCount: _readInt(json, 'totalSkipCount'),
      totalListeningSeconds: _readInt(json, 'totalListeningSeconds'),
      tracks: includeTracks && rawTracks is List
          ? List.unmodifiable(
              _compactTrackCounters(
                rawTracks.whereType<Map>().map(
                  (track) => TrackCounterSnapshot.fromJson(
                    track.cast<String, Object?>(),
                  ),
                ),
              ),
            )
          : const [],
      filterSignature: _readNullableString(json, 'filterSignature'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'dateKey': dateKey,
      'capturedAtMillis': capturedAt.millisecondsSinceEpoch,
      'source': source,
      'trackCount': trackCount,
      'totalPlayCount': totalPlayCount,
      'totalSkipCount': totalSkipCount,
      'totalListeningSeconds': totalListeningSeconds,
      'tracks': tracks.map((track) => track.toJson()).toList(growable: false),
      if (filterSignature != null) 'filterSignature': filterSignature,
    };
  }
}

class SnapshotHistory {
  const SnapshotHistory({required this.snapshots});

  static const empty = SnapshotHistory(snapshots: []);

  final List<DailyLibrarySnapshot> snapshots;

  DailyLibrarySnapshot? get latest => snapshots.isEmpty ? null : snapshots.last;

  DailyLibrarySnapshot? get previous =>
      snapshots.length < 2 ? null : snapshots[snapshots.length - 2];

  SnapshotDelta? get latestDelta {
    final current = latest;
    final baseline = previous;
    if (current == null || baseline == null) {
      return null;
    }
    return SnapshotDelta.compare(previous: baseline, current: current);
  }

  int get snapshotCount => snapshots.length;

  int daysSinceLatest(DateTime now) {
    final current = latest;
    if (current == null) {
      return 0;
    }
    return _dateOnly(now).difference(_dateOnly(current.capturedAt)).inDays;
  }

  SnapshotHistory withSnapshot(DailyLibrarySnapshot snapshot) {
    final next = [
      for (final existing in snapshots)
        if (existing.dateKey != snapshot.dateKey) existing,
      snapshot,
    ]..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    return SnapshotHistory(snapshots: List.unmodifiable(next));
  }

  factory SnapshotHistory.fromJson(Map<String, Object?> json) {
    final rawSnapshots = json['snapshots'];
    if (rawSnapshots is! List) {
      return SnapshotHistory.empty;
    }

    final snapshots =
        rawSnapshots
            .whereType<Map>()
            .map(
              (snapshot) => DailyLibrarySnapshot.fromJson(
                snapshot.cast<String, Object?>(),
              ),
            )
            .toList()
          ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return SnapshotHistory(snapshots: List.unmodifiable(snapshots));
  }

  Map<String, Object?> toJson() {
    return {
      'version': 1,
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'snapshots': snapshots
          .map((snapshot) => snapshot.toJson())
          .toList(growable: false),
    };
  }
}

List<TrackCounterSnapshot> _snapshotTrackCounters(LibraryOverview overview) {
  final selected = <String, LibraryTrack>{};

  void addTracks(Iterable<LibraryTrack> tracks, int limit) {
    var added = 0;
    for (final track in tracks) {
      selected.putIfAbsent(track.id, () => track);
      added += 1;
      if (added >= limit || selected.length >= maxSnapshotTrackCounters) {
        return;
      }
    }
  }

  addTracks(overview.tracksByPlayCount, 260);
  addTracks(overview.recentTrackDetails, 160);
  addTracks(overview.tracksBySkipCount, 80);
  if (selected.length < maxSnapshotTrackCounters) {
    addTracks(overview.tracksByTitle, maxSnapshotTrackCounters);
  }

  final tracks =
      selected.values
          .map(TrackCounterSnapshot.fromTrack)
          .toList(growable: false)
        ..sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(tracks);
}

List<TrackCounterSnapshot> _compactTrackCounters(
  Iterable<TrackCounterSnapshot> tracks,
) {
  final sorted = tracks.toList(growable: false)
    ..sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      if (byPlays != 0) {
        return byPlays;
      }
      final bySkips = b.skipCount.compareTo(a.skipCount);
      if (bySkips != 0) {
        return bySkips;
      }
      return a.id.compareTo(b.id);
    });
  final compacted = sorted.take(maxSnapshotTrackCounters).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return compacted;
}

class SnapshotDelta {
  const SnapshotDelta({
    required this.previous,
    required this.current,
    required this.observedDays,
    required this.totalPlayDelta,
    required this.totalSkipDelta,
    required this.totalListeningSecondsDelta,
    required this.trackDeltas,
  });

  final DailyLibrarySnapshot previous;
  final DailyLibrarySnapshot current;
  final int observedDays;
  final int totalPlayDelta;
  final int totalSkipDelta;
  final int totalListeningSecondsDelta;
  final List<TrackCounterDelta> trackDeltas;

  factory SnapshotDelta.compare({
    required DailyLibrarySnapshot previous,
    required DailyLibrarySnapshot current,
  }) {
    final previousTracks = {
      for (final track in previous.tracks) track.id: track,
    };
    final trackDeltasByIdentity = <String, TrackCounterDelta>{};
    for (final track in current.tracks) {
      final baseline = previousTracks[track.id];
      if (baseline == null) {
        continue;
      }
      final delta = TrackCounterDelta.compare(
        previous: baseline,
        current: track,
      );
      if (delta.playDelta > 0 || delta.skipDelta > 0) {
        final identity = _trackCounterIdentity(track);
        final existing = trackDeltasByIdentity[identity];
        trackDeltasByIdentity[identity] = existing == null
            ? delta
            : existing.merge(delta);
      }
    }
    final trackDeltas = trackDeltasByIdentity.values.toList();
    trackDeltas.sort((a, b) {
      final byPlays = b.playDelta.compareTo(a.playDelta);
      if (byPlays != 0) {
        return byPlays;
      }
      final bySkips = b.skipDelta.compareTo(a.skipDelta);
      if (bySkips != 0) {
        return bySkips;
      }
      return a.title.compareTo(b.title);
    });

    return SnapshotDelta(
      previous: previous,
      current: current,
      observedDays: _dateOnly(
        current.capturedAt,
      ).difference(_dateOnly(previous.capturedAt)).inDays.abs(),
      totalPlayDelta: _positiveDelta(
        current.totalPlayCount,
        previous.totalPlayCount,
      ),
      totalSkipDelta: _positiveDelta(
        current.totalSkipCount,
        previous.totalSkipCount,
      ),
      totalListeningSecondsDelta: _positiveDelta(
        current.totalListeningSeconds,
        previous.totalListeningSeconds,
      ),
      trackDeltas: List.unmodifiable(trackDeltas),
    );
  }
}

class TrackCounterDelta {
  const TrackCounterDelta({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumTitle,
    required this.playDelta,
    required this.skipDelta,
    required this.listeningSecondsDelta,
  });

  final String id;
  final String title;
  final String artist;
  final String albumTitle;
  final int playDelta;
  final int skipDelta;
  final int listeningSecondsDelta;

  factory TrackCounterDelta.compare({
    required TrackCounterSnapshot previous,
    required TrackCounterSnapshot current,
  }) {
    return TrackCounterDelta(
      id: current.id,
      title: current.title,
      artist: current.artist,
      albumTitle: current.albumTitle,
      playDelta: _positiveDelta(current.playCount, previous.playCount),
      skipDelta: _positiveDelta(current.skipCount, previous.skipCount),
      listeningSecondsDelta: _positiveDelta(
        current.listeningSeconds,
        previous.listeningSeconds,
      ),
    );
  }

  TrackCounterDelta merge(TrackCounterDelta other) {
    return TrackCounterDelta(
      id: id,
      title: title,
      artist: artist,
      albumTitle: albumTitle,
      playDelta: playDelta + other.playDelta,
      skipDelta: skipDelta + other.skipDelta,
      listeningSecondsDelta:
          listeningSecondsDelta + other.listeningSecondsDelta,
    );
  }
}

String _trackCounterIdentity(TrackCounterSnapshot track) {
  return [
    track.title,
    track.artist,
    track.albumTitle,
  ].map(_normalizeTrackCounterIdentityPart).join('\u{1f}');
}

String _normalizeTrackCounterIdentityPart(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String snapshotDateKey(DateTime date) {
  final local = date.toLocal();
  return [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
}

int _positiveDelta(int current, int previous) {
  final delta = current - previous;
  return delta < 0 ? 0 : delta;
}

DateTime _dateOnly(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _readString(
  Map<String, Object?> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

String? _readNullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return 0;
}

DateTime? _readDate(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int && value > 0) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is double && value > 0) {
    return DateTime.fromMillisecondsSinceEpoch(value.round());
  }
  return null;
}
