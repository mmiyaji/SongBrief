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

  SupplementalListeningHistory ingest(Iterable<LibraryTrack> tracks) {
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
      final playedAt = track.lastPlayedAt;
      final timestamp = playedAt?.microsecondsSinceEpoch;
      if (previous != null &&
          previous.aliases.contains(metadata) &&
          (storeId == null || storeId == _storeId(previous.track)) &&
          (timestamp == null || previous.dates.contains(timestamp))) {
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
      final representative = keepPrevious ? previous.track : track;
      final entry = _HistoryEntry(
        _withDate(representative, newest),
        Set.unmodifiable(dates),
        Set.unmodifiable({...?previous?.aliases, metadata}),
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
            (entry) => {
              'track': _trackMap(entry.track),
              'dates': entry.dates.toList()..sort(),
              'aliases': entry.aliases.toList()..sort(),
            },
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
          ),
        );
      }
      return SupplementalListeningHistory._(entries);
    } on Object {
      return const SupplementalListeningHistory.empty();
    }
  }
}

class SupplementalListeningEvent {
  const SupplementalListeningEvent({
    required this.track,
    required this.playedAt,
  });

  final LibraryTrack track;
  final DateTime playedAt;
}

class _HistoryEntry {
  const _HistoryEntry(this.track, this.dates, this.aliases);
  final LibraryTrack track;
  final Set<int> dates;
  final Set<String> aliases;
  int get count => dates.isEmpty ? 1 : dates.length;
}

String? _storeId(LibraryTrack track) {
  final value = track.appleMusicStoreId?.trim();
  return value == null || value.isEmpty || value == '0' ? null : value;
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

Map<String, Object?> _trackMap(LibraryTrack track) => {
  'id': track.id,
  'title': track.title,
  'artist': track.artist,
  'albumTitle': track.albumTitle,
  'albumArtist': track.albumArtist,
  'genre': track.genre,
  'appleMusicStoreId': track.appleMusicStoreId,
  'releaseDateMillis': track.releaseDate?.millisecondsSinceEpoch,
  'durationSeconds': track.duration.inSeconds,
  'isCloudItem': track.isCloudItem,
  'lyrics': track.lyrics,
  'playlistNames': track.playlistNames,
};
