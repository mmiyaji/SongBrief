import 'dart:convert';
import 'dart:io';

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

  final SnapshotDirectoryProvider? _directoryProvider;

  @override
  Future<SnapshotHistory> loadHistory() async {
    final directory = await _directory(create: false);
    if (!await directory.exists()) {
      return SnapshotHistory.empty;
    }

    final snapshots = <DailyLibrarySnapshot>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !_isSnapshotFile(entity)) {
        continue;
      }
      final snapshot = await _readSnapshot(entity);
      if (snapshot != null) {
        snapshots.add(snapshot);
      }
    }
    snapshots.sort((a, b) => a.dateKey.compareTo(b.dateKey));
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
    await temp.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
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

  static String _fileName(String path) {
    final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
    return separatorIndex < 0 ? path : path.substring(separatorIndex + 1);
  }

  static Future<DailyLibrarySnapshot?> _readSnapshot(File file) async {
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DailyLibrarySnapshot.fromJson(decoded.cast<String, Object?>());
      }
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
    return null;
  }
}
