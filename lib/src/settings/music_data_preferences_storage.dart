import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef MusicDataPreferencesLoader = Future<SharedPreferences> Function();

const musicDataPreferencesLoadTimeout = Duration(seconds: 2);

/// Overridden at startup so music-data settings can be restored synchronously.
///
/// Tests and alternate entry points may leave this unset. In that case the
/// controllers use [musicDataPreferencesLoaderProvider] as an asynchronous
/// fallback.
final musicDataSharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

final musicDataPreferencesLoaderProvider = Provider<MusicDataPreferencesLoader>(
  (ref) {
    return SharedPreferences.getInstance;
  },
);

/// Shares one cancellable fallback load across all music-data settings.
final musicDataPreferencesFallbackProvider =
    Provider<Future<SharedPreferences?>>((ref) {
      final loader = ref.watch(musicDataPreferencesLoaderProvider);
      final completer = Completer<SharedPreferences?>();
      var disposed = false;
      late final Timer timeout;

      void complete(SharedPreferences? preferences) {
        if (disposed || completer.isCompleted) {
          return;
        }
        timeout.cancel();
        completer.complete(preferences);
      }

      timeout = Timer(musicDataPreferencesLoadTimeout, () => complete(null));
      ref.onDispose(() {
        disposed = true;
        timeout.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      unawaited(
        Future<void>.sync(() async {
          try {
            complete(await loader());
          } on Object {
            complete(null);
          }
        }),
      );
      return completer.future;
    });
