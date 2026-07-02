import 'dart:convert';

import '../domain/music_stats_state.dart';

enum LibraryExportFormat { csv, json }

class LibraryExportPayload {
  const LibraryExportPayload({
    required this.fileName,
    required this.mimeType,
    required this.content,
  });

  final String fileName;
  final String mimeType;
  final String content;
}

LibraryExportPayload buildLibraryExportPayload(
  MusicStatsState stats,
  LibraryExportFormat format, {
  DateTime? exportedAt,
}) {
  final timestamp = _compactTimestamp(exportedAt ?? DateTime.now());
  return switch (format) {
    LibraryExportFormat.csv => LibraryExportPayload(
      fileName: 'songbrief-library-$timestamp.csv',
      mimeType: 'text/csv',
      content: buildLibraryCsv(stats),
    ),
    LibraryExportFormat.json => LibraryExportPayload(
      fileName: 'songbrief-library-$timestamp.json',
      mimeType: 'application/json',
      content: buildLibraryJson(stats, exportedAt: exportedAt),
    ),
  };
}

String buildLibraryCsv(MusicStatsState stats) {
  final buffer = StringBuffer()
    ..writeln(
      [
        'id',
        'title',
        'artist',
        'albumTitle',
        'albumArtist',
        'genre',
        'appleMusicStoreId',
        'durationSeconds',
        'playCount',
        'skipCount',
        'listeningSeconds',
        'lastPlayedAt',
        'isCloudItem',
        'playlistNames',
        'hasLyrics',
      ].map(_csvCell).join(','),
    );

  for (final track in stats.overview.tracks) {
    buffer.writeln(
      [
        track.id,
        track.title,
        track.artist,
        track.albumTitle,
        track.albumArtist ?? '',
        track.genre ?? '',
        track.appleMusicStoreId ?? '',
        track.duration.inSeconds.toString(),
        track.playCount.toString(),
        track.skipCount.toString(),
        track.listeningSeconds.toString(),
        track.lastPlayedAt?.toIso8601String() ?? '',
        track.isCloudItem.toString(),
        track.playlistNames.join('|'),
        (track.lyrics?.trim().isNotEmpty ?? false).toString(),
      ].map(_csvCell).join(','),
    );
  }

  return buffer.toString();
}

String buildLibraryJson(MusicStatsState stats, {DateTime? exportedAt}) {
  final overview = stats.overview;
  final payload = <String, Object?>{
    'version': 1,
    'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
    'generatedAt': overview.generatedAt.toIso8601String(),
    'isDemo': overview.isDemo,
    'totals': {
      'tracks': overview.totalTracks,
      'artists': overview.totalArtists,
      'albums': overview.totalAlbums,
      'playCount': overview.totalPlayCount,
      'skipCount': overview.totalSkipCount,
      'listeningSeconds': overview.totalListeningSeconds,
    },
    'tracks': overview.tracks
        .map(
          (track) => {
            'id': track.id,
            'title': track.title,
            'artist': track.artist,
            'albumTitle': track.albumTitle,
            if (track.albumArtist != null) 'albumArtist': track.albumArtist,
            if (track.genre != null) 'genre': track.genre,
            if (track.appleMusicStoreId != null)
              'appleMusicStoreId': track.appleMusicStoreId,
            'durationSeconds': track.duration.inSeconds,
            'playCount': track.playCount,
            'skipCount': track.skipCount,
            'listeningSeconds': track.listeningSeconds,
            if (track.lastPlayedAt != null)
              'lastPlayedAt': track.lastPlayedAt!.toIso8601String(),
            'isCloudItem': track.isCloudItem,
            'playlistNames': track.playlistNames,
            'hasLyrics': track.lyrics?.trim().isNotEmpty ?? false,
          },
        )
        .toList(growable: false),
    'snapshots': stats.snapshotHistory.snapshots
        .map(
          (snapshot) => {
            'dateKey': snapshot.dateKey,
            'capturedAt': snapshot.capturedAt.toIso8601String(),
            'source': snapshot.source,
            'trackCount': snapshot.trackCount,
            'totalPlayCount': snapshot.totalPlayCount,
            'totalSkipCount': snapshot.totalSkipCount,
            'totalListeningSeconds': snapshot.totalListeningSeconds,
          },
        )
        .toList(growable: false),
  };

  return const JsonEncoder.withIndent('  ').convert(payload);
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _compactTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  return [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
    '-',
    local.hour.toString().padLeft(2, '0'),
    local.minute.toString().padLeft(2, '0'),
  ].join();
}
