import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_track.dart';

const excludedPlaylistsPreferenceKey = 'songbrief_excluded_playlists_v1';
const excludedGenresPreferenceKey = 'songbrief_excluded_genres_v1';
const excludedKeywordsPreferenceKey = 'songbrief_excluded_keywords_v1';

final libraryFilterPreferencesProvider =
    NotifierProvider<
      LibraryFilterPreferencesController,
      LibraryFilterPreferences
    >(LibraryFilterPreferencesController.new);

class LibraryFilterPreferences {
  LibraryFilterPreferences({
    List<String> excludedPlaylists = const <String>[],
    List<String> excludedGenres = const <String>[],
    List<String> excludedKeywords = const <String>[],
  }) : excludedPlaylists = List.unmodifiable(_cleanRules(excludedPlaylists)),
       excludedGenres = List.unmodifiable(_cleanRules(excludedGenres)),
       excludedKeywords = List.unmodifiable(_cleanRules(excludedKeywords));

  final List<String> excludedPlaylists;
  final List<String> excludedGenres;
  final List<String> excludedKeywords;

  bool get isEmpty =>
      excludedPlaylists.isEmpty &&
      excludedGenres.isEmpty &&
      excludedKeywords.isEmpty;

  int get ruleCount =>
      excludedPlaylists.length +
      excludedGenres.length +
      excludedKeywords.length;

  String get snapshotSignature {
    final canonical = [
      'p:${excludedPlaylists.map(_ruleKey).join('\u001f')}',
      'g:${excludedGenres.map(_ruleKey).join('\u001f')}',
      'k:${excludedKeywords.map(_searchKey).join('\u001f')}',
    ].join('\u001e');
    var hash = 0x811c9dc5;
    for (final codeUnit in canonical.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  LibraryFilterPreferences copyWith({
    List<String>? excludedPlaylists,
    List<String>? excludedGenres,
    List<String>? excludedKeywords,
  }) {
    return LibraryFilterPreferences(
      excludedPlaylists: excludedPlaylists ?? this.excludedPlaylists,
      excludedGenres: excludedGenres ?? this.excludedGenres,
      excludedKeywords: excludedKeywords ?? this.excludedKeywords,
    );
  }

  List<LibraryTrack> apply(List<LibraryTrack> tracks) {
    if (isEmpty || tracks.isEmpty) {
      return tracks;
    }
    final compiled = _CompiledLibraryFilterPreferences(this);
    return List<LibraryTrack>.unmodifiable(
      tracks.where((track) => !compiled.excludes(track)),
    );
  }

  bool excludes(LibraryTrack track) {
    return _CompiledLibraryFilterPreferences(this).excludes(track);
  }
}

class _CompiledLibraryFilterPreferences {
  _CompiledLibraryFilterPreferences(LibraryFilterPreferences preferences)
    : excludedPlaylistKeys = preferences.excludedPlaylists
          .map(_ruleKey)
          .toSet(),
      excludedGenreKeys = preferences.excludedGenres.map(_ruleKey).toSet(),
      excludedKeywordKeys = preferences.excludedKeywords
          .map(_searchKey)
          .where((keyword) => keyword.isNotEmpty)
          .toList(growable: false);

  final Set<String> excludedPlaylistKeys;
  final Set<String> excludedGenreKeys;
  final List<String> excludedKeywordKeys;

  bool excludes(LibraryTrack track) {
    if (excludedPlaylistKeys.isNotEmpty) {
      for (final playlistName in track.playlistNames) {
        if (excludedPlaylistKeys.contains(_ruleKey(playlistName))) {
          return true;
        }
      }
    }

    final genre = track.genre;
    if (genre != null &&
        excludedGenreKeys.isNotEmpty &&
        excludedGenreKeys.contains(_ruleKey(genre))) {
      return true;
    }

    if (excludedKeywordKeys.isNotEmpty) {
      final searchText = _trackSearchKey(track);
      for (final keyword in excludedKeywordKeys) {
        if (keyword.isNotEmpty && searchText.contains(keyword)) {
          return true;
        }
      }
    }

    return false;
  }
}

class LibraryFilterPreferencesController
    extends Notifier<LibraryFilterPreferences> {
  var _changedByUser = false;
  var _restoreStarted = false;
  final _restored = Completer<void>();

  Future<void> get restored =>
      _restoreStarted ? _restored.future : Future<void>.value();

  @override
  LibraryFilterPreferences build() {
    _restore();
    return LibraryFilterPreferences();
  }

  void addExcludedPlaylist(String playlistName) {
    _update(
      state.copyWith(
        excludedPlaylists: _addRule(state.excludedPlaylists, playlistName),
      ),
    );
  }

  void removeExcludedPlaylist(String playlistName) {
    _update(
      state.copyWith(
        excludedPlaylists: _removeRule(state.excludedPlaylists, playlistName),
      ),
    );
  }

  void addExcludedGenre(String genre) {
    _update(
      state.copyWith(excludedGenres: _addRule(state.excludedGenres, genre)),
    );
  }

  void removeExcludedGenre(String genre) {
    _update(
      state.copyWith(excludedGenres: _removeRule(state.excludedGenres, genre)),
    );
  }

  void addExcludedKeyword(String keyword) {
    _update(
      state.copyWith(
        excludedKeywords: _addRule(state.excludedKeywords, keyword),
      ),
    );
  }

  void removeExcludedKeyword(String keyword) {
    _update(
      state.copyWith(
        excludedKeywords: _removeRule(state.excludedKeywords, keyword),
      ),
    );
  }

  void clearAll() {
    _update(LibraryFilterPreferences());
  }

  void _update(LibraryFilterPreferences preferences) {
    _changedByUser = true;
    state = preferences;
    unawaited(_save(preferences));
  }

  void _restore() {
    _restoreStarted = true;
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final restored = LibraryFilterPreferences(
          excludedPlaylists:
              preferences.getStringList(excludedPlaylistsPreferenceKey) ??
              const <String>[],
          excludedGenres:
              preferences.getStringList(excludedGenresPreferenceKey) ??
              const <String>[],
          excludedKeywords:
              preferences.getStringList(excludedKeywordsPreferenceKey) ??
              const <String>[],
        );
        if (!disposed && !_changedByUser) {
          state = restored;
        }
      } finally {
        if (!_restored.isCompleted) {
          _restored.complete();
        }
      }
    }());
  }

  Future<void> _save(LibraryFilterPreferences preferences) async {
    final storage = await SharedPreferences.getInstance();
    await storage.setStringList(
      excludedPlaylistsPreferenceKey,
      preferences.excludedPlaylists,
    );
    await storage.setStringList(
      excludedGenresPreferenceKey,
      preferences.excludedGenres,
    );
    await storage.setStringList(
      excludedKeywordsPreferenceKey,
      preferences.excludedKeywords,
    );
  }
}

List<String> _addRule(List<String> current, String value) {
  return _cleanRules([...current, value]);
}

List<String> _removeRule(List<String> current, String value) {
  final target = _ruleKey(value);
  return _cleanRules(current.where((item) => _ruleKey(item) != target));
}

List<String> _cleanRules(Iterable<String> values) {
  final byKey = <String, String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    byKey.putIfAbsent(_ruleKey(trimmed), () => trimmed);
  }
  final rules = byKey.values.toList(growable: false)
    ..sort((a, b) => _ruleKey(a).compareTo(_ruleKey(b)));
  return rules;
}

String _ruleKey(String value) => value.trim().toLowerCase();

String _searchKey(String value) => _ruleKey(value);

String _trackSearchKey(LibraryTrack track) {
  return [
    track.title,
    track.artist,
    track.albumTitle,
    track.albumArtist,
    track.genre,
    ...track.playlistNames,
  ].whereType<String>().map(_searchKey).join(' ');
}
