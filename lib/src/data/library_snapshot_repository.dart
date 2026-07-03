import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  static const _maxStoredSnapshotCharacters = 1500000;

  Future<SnapshotHistory> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await _removeLegacyHistory(preferences);
    final raw = preferences.getString(librarySnapshotPreferencesKey);
    if (raw == null || raw.isEmpty) {
      return SnapshotHistory.empty;
    }

    if (raw.length > _maxStoredSnapshotCharacters) {
      await preferences.remove(librarySnapshotPreferencesKey);
      return SnapshotHistory.empty;
    }

    try {
      return await compute(_decodeSnapshotHistory, raw);
    } on FormatException {
      return SnapshotHistory.empty;
    }
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

    final encoded = await compute(_encodeSnapshotHistory, next.toJson());
    final preferences = await SharedPreferences.getInstance();
    if (encoded.length > _maxStoredSnapshotCharacters) {
      await preferences.remove(librarySnapshotPreferencesKey);
      return next;
    }
    await preferences.setString(librarySnapshotPreferencesKey, encoded);
    return next;
  }

  Future<void> _removeLegacyHistory(SharedPreferences preferences) async {
    for (final key in legacyLibrarySnapshotPreferencesKeys) {
      await preferences.remove(key);
    }
  }
}

SnapshotHistory _decodeSnapshotHistory(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map) {
    return SnapshotHistory.fromJson(decoded.cast<String, Object?>());
  }
  return SnapshotHistory.empty;
}

String _encodeSnapshotHistory(Map<String, Object?> json) {
  return jsonEncode(json);
}
