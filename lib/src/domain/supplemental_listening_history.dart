import 'dart:convert';

import 'library_track.dart';

/// Confirmed minimum plays: each actual song/timestamp pair contributes once.
/// An undated history row proves at most one play until a dated row is seen.
class SupplementalListeningHistory {
  const SupplementalListeningHistory.empty() : _entries = const [];

  SupplementalListeningHistory._(Iterable<_HistoryEntry> entries)
    : _entries = List.unmodifiable(entries);

  final List<_HistoryEntry> _entries;

  List<LibraryTrack> get tracks => List.unmodifiable(
    _entries.map(
      (entry) => entry.track.copyWith(playCount: entry.count, skipCount: 0),
    ),
  );

  int get undatedTrackCount =>
      _entries.where((entry) => entry.dates.isEmpty).length;

  int get totalPlayCount =>
      _entries.fold(0, (total, entry) => total + entry.count);

  /// Only actual timestamps can be assigned to a day or listening trend.
  List<SupplementalListeningEvent> get datedEvents {
    final events =
        <SupplementalListeningEvent>[
          for (final entry in _entries)
            for (final date in entry.dates)
              SupplementalListeningEvent(
                track: _withDate(entry.track, date).copyWith(playCount: 1),
                playedAt: DateTime.fromMicrosecondsSinceEpoch(
                  date,
                  isUtc: true,
                ),
              ),
        ]..sort((a, b) {
          final byDate = a.playedAt.compareTo(b.playedAt);
          return byDate != 0 ? byDate : _key(a.track).compareTo(_key(b.track));
        });
    return List.unmodifiable(events);
  }

  /// A single minimum assigned to the day playback was observed. Actual dates,
  /// when available, replace this fallback rather than adding another play.
  List<SupplementalListeningEvent> get observedEvents => List.unmodifiable([
    for (final entry in _entries)
      if (entry.dates.isEmpty && entry.firstObservedAt != null)
        SupplementalListeningEvent(
          track: _withDate(
            entry.track,
            entry.firstObservedAt,
          ).copyWith(playCount: 1, lastPlayedAtIsObservation: true),
          playedAt: DateTime.fromMicrosecondsSinceEpoch(
            entry.firstObservedAt!,
            isUtc: true,
          ),
          isObservation: true,
        ),
  ]);

  List<SupplementalListeningEvent> get calendarEvents {
    final events = [...datedEvents, ...observedEvents]
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    return List.unmodifiable(events);
  }

  SupplementalListeningHistory ingest(Iterable<LibraryTrack> tracks) =>
      _ingest(tracks);

  /// Combines independently accumulated device ledgers. Exact timestamps are
  /// set-unioned; undated observations remain a single minimum until an exact
  /// timestamp is available. Sorting the input evidence makes the result
  /// independent of which device is the receiver.
  SupplementalListeningHistory merge(SupplementalListeningHistory other) {
    final source = [..._entries, ...other._entries]
      ..sort((a, b) {
        final byKey = _key(a.track).compareTo(_key(b.track));
        if (byKey != 0) return byKey;
        final byTrack = jsonEncode(_trackMap(a.track))
            .compareTo(jsonEncode(_trackMap(b.track)));
        if (byTrack != 0) return byTrack;
        return jsonEncode(_entryMap(a)).compareTo(jsonEncode(_entryMap(b)));
      });
    final datedRows = <LibraryTrack>[];
    final observedByTime = <int, List<LibraryTrack>>{};
    final undatedRows = <LibraryTrack>[];
    for (final entry in source) {
      final evidenceTracks = <LibraryTrack>[entry.track];
      final orderedAliases = entry.aliases.toList()..sort();
      for (final alias in orderedAliases) {
        final parts = (jsonDecode(alias) as List<dynamic>).cast<String>();
        if (parts.length == 3) {
          evidenceTracks.add(_withMetadata(entry.track, parts));
        }
      }
      for (final evidence in evidenceTracks) {
        if (entry.dates.isNotEmpty) {
          for (final date in entry.dates) {
            datedRows.add(_withDate(evidence, date));
          }
        } else if (entry.firstObservedAt != null) {
          observedByTime
              .putIfAbsent(entry.firstObservedAt!, () => <LibraryTrack>[])
              .add(evidence);
        } else {
          undatedRows.add(evidence);
        }
      }
    }
    var result = const SupplementalListeningHistory.empty();
    if (datedRows.isNotEmpty) result = result.ingest(datedRows);
    if (observedByTime.isNotEmpty) {
      final observationRows = <LibraryTrack>[];
      final timesByTrack = <LibraryTrack, int>{};
      final observationTimes = observedByTime.keys.toList()..sort();
      for (final time in observationTimes) {
        for (final track in observedByTime[time]!) {
          observationRows.add(track);
          timesByTrack[track] = time;
        }
      }
      result = result._ingest(
        observationRows,
        observationTimesByTrack: timesByTrack,
      );
    }
    if (undatedRows.isNotEmpty) result = result.ingest(undatedRows);
    // Exact-date replay suppresses observation events, but the earliest proof
    // remains part of the ledger and must survive a merge or round trip.
    final mergedEntries = [...result._entries];
    final byCatalogId = <String, int>{};
    final byMetadata = <String, int>{};
    for (var index = 0; index < mergedEntries.length; index++) {
      final entry = mergedEntries[index];
      final catalogId = _storeId(entry.track);
      if (catalogId != null) byCatalogId[catalogId] = index;
      byMetadata[_metadata(entry.track)] = index;
      for (final alias in entry.aliases) {
        byMetadata[alias] = index;
      }
    }
    for (final original in source) {
      final observedAt = original.firstObservedAt;
      if (observedAt == null) continue;
      final index =
          byCatalogId[_storeId(original.track)] ??
          byMetadata[_metadata(original.track)];
      if (index == null) continue;
      final entry = mergedEntries[index];
      mergedEntries[index] = _HistoryEntry(
        entry.track,
        entry.dates,
        entry.aliases,
        firstObservedAt: _minNullable(entry.firstObservedAt, observedAt),
      );
    }
    result = SupplementalListeningHistory._(mergedEntries);
    return result;
  }

  /// Records proof of playback, not a MusicKit completion timestamp. Repeated
  /// observations never move the first confirmation or increment the minimum.
  SupplementalListeningHistory observe(
    LibraryTrack track, {
    required DateTime at,
  }) => _ingest([track], observedAt: at);

  SupplementalListeningHistory _ingest(
    Iterable<LibraryTrack> tracks, {
    DateTime? observedAt,
    Map<LibraryTrack, int>? observationTimesByTrack,
  }) {
    final entries = [..._entries];
    final byStoreId = <String, int>{};
    final byMetadata = <String, int>{};
    final withoutStoreId = <String, int>{};
    final bySong = <String, int>{};
    final songWithoutStoreId = <String, int>{};
    final unknownAlbumBySong = <String, int>{};
    final unknownAlbumWithoutStoreId = <String, int>{};
    void indexEntry(int index) {
      final entry = entries[index];
      final storeId = _storeId(entry.track);
      final hasUnknownAlbum = _unknownAlbum(entry.track.albumTitle);
      if (storeId != null) byStoreId[storeId] = index;
      for (final alias in entry.aliases) {
        final parts = (jsonDecode(alias) as List<dynamic>).cast<String>();
        final song = jsonEncode(parts.take(2).toList());
        byMetadata.putIfAbsent(alias, () => index);
        bySong.putIfAbsent(song, () => index);
        if (storeId == null) {
          withoutStoreId[alias] = index;
          songWithoutStoreId[song] = index;
        } else if (withoutStoreId[alias] == index) {
          withoutStoreId.remove(alias);
        }
        if (storeId != null && songWithoutStoreId[song] == index) {
          songWithoutStoreId.remove(song);
        }
        if (hasUnknownAlbum) {
          unknownAlbumBySong.putIfAbsent(song, () => index);
          if (storeId == null) unknownAlbumWithoutStoreId[song] = index;
        } else if (unknownAlbumBySong[song] == index) {
          unknownAlbumBySong.remove(song);
        }
        if ((!hasUnknownAlbum || storeId != null) &&
            unknownAlbumWithoutStoreId[song] == index) {
          unknownAlbumWithoutStoreId.remove(song);
        }
      }
    }

    for (var index = 0; index < entries.length; index++) {
      indexEntry(index);
    }
    var changed = false;
    for (final track in tracks) {
      final observationTime = observationTimesByTrack?[track];
      final hasObservation = observedAt != null || observationTime != null;
      final storeId = _storeId(track);
      final metadata = _metadata(track);
      final song = jsonEncode([
        _normalize(track.title),
        _normalize(track.artist),
      ]);
      final hasUnknownAlbum = _unknownAlbum(track.albumTitle);
      final index = storeId == null
          ? byMetadata[metadata] ??
                (hasUnknownAlbum ? bySong[song] : unknownAlbumBySong[song])
          : byStoreId[storeId] ??
                withoutStoreId[metadata] ??
                (hasUnknownAlbum
                    ? songWithoutStoreId[song]
                    : unknownAlbumWithoutStoreId[song]);
      final previous = index == null ? null : entries[index];
      final playedAt = hasObservation ? null : track.lastPlayedAt;
      final timestamp = playedAt?.microsecondsSinceEpoch;
      if (previous != null &&
          previous.aliases.contains(metadata) &&
          (track.appleMusicUrl == null ||
              track.appleMusicUrl == previous.track.appleMusicUrl) &&
          (storeId == null || storeId == _storeId(previous.track)) &&
          (timestamp == null || previous.dates.contains(timestamp)) &&
          (!hasObservation ||
              previous.firstObservedAt != null ||
              previous.dates.isNotEmpty)) {
        continue;
      }
      changed = true;
      final dates = {...?previous?.dates};
      if (timestamp != null) dates.add(timestamp);
      // Keep the representative's newest real time, never a polling time.
      final newest = dates.isEmpty
          ? null
          : dates.reduce((a, b) => a > b ? a : b);
      final keepPrevious =
          storeId == null &&
          previous != null &&
          (_storeId(previous.track) != null ||
              !_unknownAlbum(previous.track.albumTitle) ||
              hasUnknownAlbum);
      final representative = (keepPrevious ? previous.track : track).copyWith(
        appleMusicUrl: track.appleMusicUrl ?? previous?.track.appleMusicUrl,
      );
      final entry = _HistoryEntry(
        _withDate(representative, newest),
        Set.unmodifiable(dates),
        Set.unmodifiable({...?previous?.aliases, metadata}),
        firstObservedAt:
            previous?.firstObservedAt ??
            observationTime ??
            observedAt?.microsecondsSinceEpoch,
      );
      if (index == null) {
        entries.add(entry);
        indexEntry(entries.length - 1);
      } else {
        entries[index] = entry;
        indexEntry(index);
      }
    }
    return changed ? SupplementalListeningHistory._(entries) : this;
  }

  String encode() {
    final entries = [..._entries]
      ..sort((a, b) => _key(a.track).compareTo(_key(b.track)));
    return jsonEncode({
      'version': 1,
      'entries': entries
          .map(
            (entry) => {'track': _trackMap(entry.track), ..._entryMap(entry)},
          )
          .toList(),
    });
  }

  static SupplementalListeningHistory decode(String? source) {
    if (source == null) return const SupplementalListeningHistory.empty();
    try {
      final data = jsonDecode(source) as Map<String, dynamic>;
      if (data['version'] != 1) {
        return const SupplementalListeningHistory.empty();
      }
      final entries = <_HistoryEntry>[];
      for (final raw in data['entries'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        final map = Map<Object?, Object?>.from(item['track'] as Map);
        final track = LibraryTrack.fromPlatformMap(map);
        final dates = (item['dates'] as List<dynamic>).cast<int>().toSet();
        final newest = dates.isEmpty
            ? null
            : dates.reduce((a, b) => a > b ? a : b);
        entries.add(
          _HistoryEntry(
            _withDate(track, newest),
            Set.unmodifiable(dates),
            Set.unmodifiable((item['aliases'] as List<dynamic>).cast<String>()),
            firstObservedAt: item['firstObservedAt'] is int
                ? item['firstObservedAt'] as int
                : null,
          ),
        );
      }
      return SupplementalListeningHistory._(entries);
    } on Object {
      return const SupplementalListeningHistory.empty();
    }
  }
}

Map<String, Object?> _entryMap(_HistoryEntry entry) => {
  'dates': entry.dates.toList()..sort(),
  'aliases': entry.aliases.toList()..sort(),
  if (entry.firstObservedAt != null) 'firstObservedAt': entry.firstObservedAt,
};

int? _minNullable(int? a, int? b) => a == null
    ? b
    : b == null
    ? a
    : (a < b ? a : b);

class SupplementalListeningEvent {
  const SupplementalListeningEvent({
    required this.track,
    required this.playedAt,
    this.isObservation = false,
  });

  final LibraryTrack track;
  final DateTime playedAt;
  final bool isObservation;
}

class _HistoryEntry {
  const _HistoryEntry(
    this.track,
    this.dates,
    this.aliases, {
    this.firstObservedAt,
  });
  final LibraryTrack track;
  final Set<int> dates;
  final Set<String> aliases;
  final int? firstObservedAt;
  int get count => dates.isEmpty ? 1 : dates.length;
}

String? _storeId(LibraryTrack track) {
  return validAppleMusicCatalogId(track.appleMusicStoreId);
}

String _metadata(LibraryTrack track) {
  return jsonEncode(
    [track.title, track.artist, track.albumTitle].map(_normalize).toList(),
  );
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _unknownAlbum(String value) {
  final normalized = _normalize(value);
  return normalized.isEmpty || normalized == 'unknown album';
}

String _key(LibraryTrack track) => _storeId(track) ?? _metadata(track);

LibraryTrack _withDate(LibraryTrack track, int? microseconds) => LibraryTrack(
  id: track.id,
  title: track.title,
  artist: track.artist,
  albumTitle: track.albumTitle,
  albumArtist: track.albumArtist,
  genre: track.genre,
  artworkAsset: track.artworkAsset,
  appleMusicStoreId: track.appleMusicStoreId,
  appleMusicUrl: track.appleMusicUrl,
  releaseDate: track.releaseDate,
  duration: track.duration,
  playCount: 0,
  skipCount: 0,
  lastPlayedAt: microseconds == null
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true),
  isCloudItem: track.isCloudItem,
  lyrics: track.lyrics,
  playlistNames: track.playlistNames,
);

LibraryTrack _withMetadata(LibraryTrack track, List<String> metadata) =>
    LibraryTrack(
      id: track.id,
      title: metadata[0],
      artist: metadata[1],
      albumTitle: metadata[2],
      albumArtist: track.albumArtist,
      genre: track.genre,
      artworkAsset: track.artworkAsset,
      appleMusicStoreId: track.appleMusicStoreId,
      appleMusicUrl: track.appleMusicUrl,
      releaseDate: track.releaseDate,
      duration: track.duration,
      playCount: 0,
      skipCount: 0,
      lastPlayedAt: track.lastPlayedAt,
      isCloudItem: track.isCloudItem,
      lyrics: track.lyrics,
      playlistNames: track.playlistNames,
    );

Map<String, Object?> _trackMap(LibraryTrack track) => {
  'id': track.id,
  'title': track.title,
  'artist': track.artist,
  'albumTitle': track.albumTitle,
  'albumArtist': track.albumArtist,
  'genre': track.genre,
  'appleMusicStoreId': track.appleMusicStoreId,
  'appleMusicUrl': track.appleMusicUrl,
  'releaseDateMillis': track.releaseDate?.millisecondsSinceEpoch,
  'durationSeconds': track.duration.inSeconds,
  'isCloudItem': track.isCloudItem,
  'lyrics': track.lyrics,
  'playlistNames': track.playlistNames,
};
