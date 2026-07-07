import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/library_snapshot.dart';
import 'library_snapshot_store_base.dart';

typedef SnapshotDirectoryProvider = Future<Directory> Function();

SnapshotStore createSnapshotStore() {
  return const FileSnapshotStore();
}

class FileSnapshotStore implements SnapshotStore {
  const FileSnapshotStore({SnapshotDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider;

  static final _snapshotFileNamePattern = RegExp(r'^\d{4}-\d{2}-\d{2}\.json$');
  static final _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static const _snapshotIndexFileName = '_snapshot_index_v1.json';
  static const _snapshotIndexVersion = 1;

  final SnapshotDirectoryProvider? _directoryProvider;

  @override
  Future<SnapshotHistory> loadHistory() async {
    final directory = await _directory(create: false);
    if (!await directory.exists()) {
      return SnapshotHistory.empty;
    }

    final snapshotFiles = await _snapshotFileRefs(directory);
    if (snapshotFiles.isEmpty) {
      await _deleteSnapshotIndex(directory);
      return SnapshotHistory.empty;
    }

    final summaries = await _loadSnapshotSummaries(directory, snapshotFiles);
    if (summaries.isEmpty) {
      return SnapshotHistory.empty;
    }

    final detailedSnapshots = await _loadDetailedSnapshots(snapshotFiles);
    final snapshotsByDateKey = {
      for (final snapshot in summaries) snapshot.dateKey: snapshot,
      for (final snapshot in detailedSnapshots) snapshot.dateKey: snapshot,
    };
    final snapshots = snapshotsByDateKey.values.toList(growable: false)
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return SnapshotHistory(snapshots: List.unmodifiable(snapshots));
  }

  @override
  Future<void> writeSnapshot(DailyLibrarySnapshot snapshot) async {
    if (!_dateKeyPattern.hasMatch(snapshot.dateKey)) {
      return;
    }
    final directory = await _directory(create: true);
    final target = File(_snapshotPath(directory, snapshot.dateKey));
    final temp = File('${target.path}.tmp');
    final encoded = await compute(_encodeSnapshotFile, snapshot.toJson());
    await temp.writeAsString(encoded, flush: true);
    try {
      await temp.rename(target.path);
    } on FileSystemException {
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
    }
    await _updateSnapshotIndexAfterWrite(directory, snapshot);
  }

  @override
  Future<void> deleteSnapshotsOlderThan(DateTime cutoff) async {
    final directory = await _directory(create: false);
    if (!await directory.exists()) {
      return;
    }
    final cutoffKey = snapshotDateKey(cutoff);
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !_isSnapshotFile(entity)) {
        continue;
      }
      final dateKey = _dateKeyFromFile(entity);
      if (dateKey != null && dateKey.compareTo(cutoffKey) < 0) {
        await entity.delete();
      }
    }
    await _reconcileSnapshotIndex(directory);
  }

  @override
  Future<void> clearHistory() async {
    final directory = await _directory(create: false);
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && _isSnapshotFile(entity)) {
        await entity.delete();
      }
    }
    await _deleteSnapshotIndex(directory);
  }

  Future<Directory> _directory({required bool create}) async {
    final directory = _directoryProvider == null
        ? await _defaultSnapshotsDirectory()
        : await _directoryProvider();
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<Directory> _defaultSnapshotsDirectory() async {
    Directory support;
    try {
      support = await getApplicationSupportDirectory();
    } on Object {
      support = Directory(
        [
          Directory.systemTemp.path,
          'songbrief_snapshot_store_$pid',
        ].join(Platform.pathSeparator),
      );
    }
    return Directory(
      [support.path, 'SongBrief', 'Snapshots'].join(Platform.pathSeparator),
    );
  }

  static bool _isSnapshotFile(File file) {
    return _snapshotFileNamePattern.hasMatch(_fileName(file.path));
  }

  static String? _dateKeyFromFile(File file) {
    final name = _fileName(file.path);
    if (!_snapshotFileNamePattern.hasMatch(name)) {
      return null;
    }
    return name.substring(0, name.length - '.json'.length);
  }

  static String _snapshotPath(Directory directory, String dateKey) {
    return [directory.path, '$dateKey.json'].join(Platform.pathSeparator);
  }

  static String _snapshotIndexPath(Directory directory) {
    return [
      directory.path,
      _snapshotIndexFileName,
    ].join(Platform.pathSeparator);
  }

  static String _fileName(String path) {
    final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
    return separatorIndex < 0 ? path : path.substring(separatorIndex + 1);
  }

  Future<List<_SnapshotFileRef>> _snapshotFileRefs(Directory directory) async {
    final refs = <_SnapshotFileRef>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !_isSnapshotFile(entity)) {
        continue;
      }
      final dateKey = _dateKeyFromFile(entity);
      if (dateKey == null) {
        continue;
      }
      try {
        final stat = await entity.stat();
        refs.add(
          _SnapshotFileRef(
            file: entity,
            dateKey: dateKey,
            modifiedMillis: stat.modified.millisecondsSinceEpoch,
          ),
        );
      } on FileSystemException {
        continue;
      }
    }
    refs.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return refs;
  }

  Future<List<DailyLibrarySnapshot>> _loadSnapshotSummaries(
    Directory directory,
    List<_SnapshotFileRef> refs,
  ) async {
    final index = await _readSnapshotIndex(directory);
    if (index != null && _snapshotRefsMatch(index.files, refs)) {
      return index.snapshots;
    }
    return _rebuildSnapshotIndex(directory, refs);
  }

  Future<List<DailyLibrarySnapshot>> _loadDetailedSnapshots(
    List<_SnapshotFileRef> refs,
  ) async {
    final detailedRefs = refs.length > detailedSnapshotHistoryEntries
        ? refs.sublist(refs.length - detailedSnapshotHistoryEntries)
        : refs;
    return _readSnapshotRefs(detailedRefs, includeTracks: true);
  }

  Future<List<DailyLibrarySnapshot>> _rebuildSnapshotIndex(
    Directory directory,
    List<_SnapshotFileRef> refs,
  ) async {
    final summaries = await _readSnapshotRefs(refs, includeTracks: false);
    final validDateKeys = summaries.map((snapshot) => snapshot.dateKey).toSet();
    final invalidRefs = refs.where(
      (ref) => !validDateKeys.contains(ref.dateKey),
    );
    await _deleteSnapshotFiles(invalidRefs);
    final currentRefs = invalidRefs.isEmpty
        ? refs
        : await _snapshotFileRefs(directory);
    final currentDateKeys = currentRefs.map((ref) => ref.dateKey).toSet();
    final currentSummaries = summaries
        .where((snapshot) => currentDateKeys.contains(snapshot.dateKey))
        .toList(growable: false);
    await _writeSnapshotIndex(directory, currentSummaries, currentRefs);
    return currentSummaries;
  }

  Future<List<DailyLibrarySnapshot>> _readSnapshotRefs(
    List<_SnapshotFileRef> refs, {
    required bool includeTracks,
  }) async {
    final rawSnapshots = <Map<String, Object?>>[];
    for (final ref in refs) {
      try {
        rawSnapshots.add({
          'raw': await ref.file.readAsString(),
          'includeTracks': includeTracks,
        });
      } on FileSystemException {
        continue;
      }
    }
    if (rawSnapshots.isEmpty) {
      return const [];
    }
    final snapshots = await compute(_decodeSnapshotFiles, rawSnapshots);
    snapshots.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return snapshots;
  }

  Future<void> _updateSnapshotIndexAfterWrite(
    Directory directory,
    DailyLibrarySnapshot snapshot,
  ) async {
    final refs = await _snapshotFileRefs(directory);
    final index = await _readSnapshotIndex(directory);
    if (index != null &&
        _snapshotRefsCanAcceptWrite(index.files, refs, snapshot.dateKey)) {
      final summaries = SnapshotHistory(
        snapshots: index.snapshots,
      ).withSnapshot(_summaryOnly(snapshot)).snapshots;
      await _writeSnapshotIndex(directory, summaries, refs);
      return;
    }
    await _rebuildSnapshotIndex(directory, refs);
  }

  Future<void> _reconcileSnapshotIndex(Directory directory) async {
    final refs = await _snapshotFileRefs(directory);
    if (refs.isEmpty) {
      await _deleteSnapshotIndex(directory);
      return;
    }
    await _rebuildSnapshotIndex(directory, refs);
  }

  Future<_SnapshotIndex?> _readSnapshotIndex(Directory directory) async {
    final indexFile = File(_snapshotIndexPath(directory));
    if (!await indexFile.exists()) {
      return null;
    }
    try {
      return await compute(
        _decodeSnapshotIndex,
        await indexFile.readAsString(),
      );
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _writeSnapshotIndex(
    Directory directory,
    List<DailyLibrarySnapshot> summaries,
    List<_SnapshotFileRef> refs,
  ) async {
    final indexFile = File(_snapshotIndexPath(directory));
    final temp = File('${indexFile.path}.tmp');
    final payload = <String, Object?>{
      'version': _snapshotIndexVersion,
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'files': refs
          .map(
            (ref) => {
              'dateKey': ref.dateKey,
              'modifiedMillis': ref.modifiedMillis,
            },
          )
          .toList(growable: false),
      'snapshots': summaries.map(_snapshotSummaryJson).toList(growable: false),
    };
    final encoded = await compute(_encodeSnapshotFile, payload);
    await temp.writeAsString(encoded, flush: true);
    try {
      await temp.rename(indexFile.path);
    } on FileSystemException {
      if (await indexFile.exists()) {
        await indexFile.delete();
      }
      await temp.rename(indexFile.path);
    }
  }

  Future<void> _deleteSnapshotIndex(Directory directory) async {
    final indexFile = File(_snapshotIndexPath(directory));
    try {
      if (await indexFile.exists()) {
        await indexFile.delete();
      }
    } on FileSystemException {
      return;
    }
  }

  Future<void> _deleteSnapshotFiles(Iterable<_SnapshotFileRef> refs) async {
    for (final ref in refs) {
      try {
        if (await ref.file.exists()) {
          await ref.file.delete();
        }
      } on FileSystemException {
        continue;
      }
    }
  }

  bool _snapshotRefsMatch(
    List<_SnapshotFileState> states,
    List<_SnapshotFileRef> refs,
  ) {
    if (states.length != refs.length) {
      return false;
    }
    for (var index = 0; index < refs.length; index += 1) {
      if (states[index].dateKey != refs[index].dateKey ||
          states[index].modifiedMillis != refs[index].modifiedMillis) {
        return false;
      }
    }
    return true;
  }

  bool _snapshotRefsCanAcceptWrite(
    List<_SnapshotFileState> states,
    List<_SnapshotFileRef> refs,
    String writtenDateKey,
  ) {
    final statesByDateKey = {for (final state in states) state.dateKey: state};
    for (final ref in refs) {
      if (ref.dateKey == writtenDateKey) {
        continue;
      }
      final state = statesByDateKey.remove(ref.dateKey);
      if (state == null || state.modifiedMillis != ref.modifiedMillis) {
        return false;
      }
    }
    return statesByDateKey.isEmpty;
  }
}

class _SnapshotFileRef {
  const _SnapshotFileRef({
    required this.file,
    required this.dateKey,
    required this.modifiedMillis,
  });

  final File file;
  final String dateKey;
  final int modifiedMillis;
}

class _SnapshotFileState {
  const _SnapshotFileState({
    required this.dateKey,
    required this.modifiedMillis,
  });

  final String dateKey;
  final int modifiedMillis;
}

class _SnapshotIndex {
  const _SnapshotIndex({required this.snapshots, required this.files});

  final List<DailyLibrarySnapshot> snapshots;
  final List<_SnapshotFileState> files;
}

String _encodeSnapshotFile(Map<String, Object?> json) {
  return jsonEncode(json);
}

_SnapshotIndex? _decodeSnapshotIndex(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final rawFiles = decoded['files'];
    final rawSnapshots = decoded['snapshots'];
    if (rawFiles is! List || rawSnapshots is! List) {
      return null;
    }
    final files =
        rawFiles
            .whereType<Map>()
            .map((file) {
              final json = file.cast<String, Object?>();
              final dateKey = json['dateKey'];
              final modifiedMillis = json['modifiedMillis'];
              if (dateKey is! String || modifiedMillis is! int) {
                return null;
              }
              return _SnapshotFileState(
                dateKey: dateKey,
                modifiedMillis: modifiedMillis,
              );
            })
            .whereType<_SnapshotFileState>()
            .toList(growable: false)
          ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    final snapshots =
        rawSnapshots
            .whereType<Map>()
            .map(
              (snapshot) => DailyLibrarySnapshot.fromJson(
                snapshot.cast<String, Object?>(),
                includeTracks: false,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return _SnapshotIndex(
      snapshots: List.unmodifiable(snapshots),
      files: List.unmodifiable(files),
    );
  } on FormatException {
    return null;
  }
}

List<DailyLibrarySnapshot> _decodeSnapshotFiles(
  List<Map<String, Object?>> rawSnapshots,
) {
  final snapshots = <DailyLibrarySnapshot>[];
  for (final entry in rawSnapshots) {
    final raw = entry['raw'];
    if (raw is! String) {
      continue;
    }
    final includeTracksValue = entry['includeTracks'];
    final includeTracks = includeTracksValue is bool
        ? includeTracksValue
        : true;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        snapshots.add(
          DailyLibrarySnapshot.fromJson(
            decoded.cast<String, Object?>(),
            includeTracks: includeTracks,
          ),
        );
      }
    } on FormatException {
      continue;
    }
  }
  return snapshots;
}

DailyLibrarySnapshot _summaryOnly(DailyLibrarySnapshot snapshot) {
  return DailyLibrarySnapshot(
    dateKey: snapshot.dateKey,
    capturedAt: snapshot.capturedAt,
    source: snapshot.source,
    trackCount: snapshot.trackCount,
    totalPlayCount: snapshot.totalPlayCount,
    totalSkipCount: snapshot.totalSkipCount,
    totalListeningSeconds: snapshot.totalListeningSeconds,
    tracks: const [],
  );
}

Map<String, Object?> _snapshotSummaryJson(DailyLibrarySnapshot snapshot) {
  return {
    'dateKey': snapshot.dateKey,
    'capturedAtMillis': snapshot.capturedAt.millisecondsSinceEpoch,
    'source': snapshot.source,
    'trackCount': snapshot.trackCount,
    'totalPlayCount': snapshot.totalPlayCount,
    'totalSkipCount': snapshot.totalSkipCount,
    'totalListeningSeconds': snapshot.totalListeningSeconds,
  };
}
