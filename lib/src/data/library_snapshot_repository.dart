import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_overview.dart';
import '../domain/library_snapshot.dart';

final librarySnapshotRepositoryProvider = Provider<LibrarySnapshotRepository>((
  ref,
) {
  return const LibrarySnapshotRepository();
});

class LibrarySnapshotRepository {
  const LibrarySnapshotRepository();

  Future<SnapshotHistory> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(librarySnapshotPreferencesKey);
    if (raw == null || raw.isEmpty) {
      return SnapshotHistory.empty;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return SnapshotHistory.fromJson(decoded.cast<String, Object?>());
      }
    } on FormatException {
      return SnapshotHistory.empty;
    }
    return SnapshotHistory.empty;
  }

  Future<SnapshotHistory> recordSnapshot(
    LibraryOverview overview, {
    DateTime? capturedAt,
    String source = 'foreground',
  }) async {
    if (!overview.hasTracks) {
      return loadHistory();
    }

    final history = await loadHistory();
    final next = history.withSnapshot(
      DailyLibrarySnapshot.fromOverview(
        overview,
        capturedAt: capturedAt,
        source: source,
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      librarySnapshotPreferencesKey,
      jsonEncode(next.toJson()),
    );
    return next;
  }
}
