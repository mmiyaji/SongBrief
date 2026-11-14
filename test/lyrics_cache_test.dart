import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/data/library_snapshot_repository.dart';
import 'package:songbrief/src/data/music_library_channel.dart';
import 'package:songbrief/src/data/music_stats_repository.dart';
import 'package:songbrief/src/features/home/home_controller.dart';

void main() {
  for (final lyrics in <String?>[null, 'Local lyrics']) {
    testWidgets('player tab caches lyrics result $lyrics and expires it', (
      tester,
    ) async {
      final repository = _LyricsRepository(lyrics);
      final container = ProviderContainer(
        overrides: [musicStatsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final provider = trackLyricsProvider('cloud-song');
      var subscription = container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), lyrics);
      subscription.close();
      await tester.pump(const Duration(seconds: 1));
      subscription = container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), lyrics);
      expect(repository.calls, 1);
      subscription.close();
      await tester.pump(const Duration(minutes: 3));
      await tester.pump();
      subscription = container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), lyrics);
      expect(repository.calls, 2);
      subscription.close();
      container.dispose();
      await tester.pump();
    });
  }
}

class _LyricsRepository extends MusicStatsRepository {
  _LyricsRepository(this.lyrics)
    : super(const PlatformMusicLibraryClient(), LibrarySnapshotRepository());
  final String? lyrics;
  int calls = 0;
  @override
  Future<String?> fetchLyrics(String trackId) async {
    calls++;
    return lyrics;
  }
}
