import 'package:flutter_test/flutter_test.dart';
import 'package:songbrief/src/domain/library_snapshot.dart';
import 'package:songbrief/src/domain/library_track.dart';
import 'package:songbrief/src/domain/supplemental_listening_history.dart';

LibraryTrack song({
  DateTime? date,
  String id = 'outside',
  String title = 'STAY AWAY',
}) => LibraryTrack(
  id: id,
  title: title,
  artist: "L'Arc-en-Ciel",
  albumTitle: 'Album',
  appleMusicStoreId: '123',
  duration: const Duration(minutes: 4),
  playCount: 99,
  skipCount: 5,
  isCloudItem: true,
  lastPlayedAt: date,
);

void main() {
  test('observation retains one stable local confirmation day without claiming an actual date', () {
    final at = DateTime(2026, 10, 30, 0, 30);
    final row = song(date: DateTime(2026, 1, 1));
    final ledger = const SupplementalListeningHistory.empty().observe(
      row,
      at: at,
    );
    expect(ledger.totalPlayCount, 1);
    expect(ledger.datedEvents, isEmpty);
    expect(ledger.tracks.single.lastPlayedAt, isNull);
    expect(ledger.tracks.single.skipCount, 0);
    expect(ledger.calendarEvents.single.isObservation, isTrue);
    expect(
      ledger.calendarEvents.single.track.lastPlayedAtIsObservation,
      isTrue,
    );
    expect(
      snapshotDateKey(ledger.calendarEvents.single.playedAt),
      '2026-10-30',
    );
    expect(
      identical(
        ledger.observe(row, at: at.add(const Duration(days: 1))),
        ledger,
      ),
      isTrue,
    );
    final restored = SupplementalListeningHistory.decode(ledger.encode());
    expect(restored.calendarEvents.single.playedAt, at.toUtc());
    expect(
      restored
          .observe(row, at: at.add(const Duration(days: 2)))
          .calendarEvents
          .single
          .playedAt,
      at.toUtc(),
    );
  });

  test(
    'actual timestamps replace the observation minimum rather than adding it',
    () {
      final observed = DateTime(2026, 10, 30, 10);
      final actual = DateTime(2026, 10, 29, 22);
      final ledger = const SupplementalListeningHistory.empty()
          .observe(song(), at: observed)
          .ingest([song(date: actual), song(date: actual)]);
      expect(ledger.totalPlayCount, 1);
      expect(ledger.observedEvents, isEmpty);
      expect(ledger.calendarEvents.single.isObservation, isFalse);
      expect(ledger.calendarEvents.single.playedAt, actual.toUtc());
      final repeated = ledger.observe(
        song(),
        at: observed.add(const Duration(days: 1)),
      );
      expect(identical(repeated, ledger), isTrue);
      final two = repeated.ingest([
        song(date: actual.add(const Duration(hours: 1))),
      ]);
      expect(two.totalPlayCount, 2);
      expect(two.calendarEvents, hasLength(2));
      expect(two.calendarEvents.every((event) => !event.isObservation), isTrue);
    },
  );

  test('legacy undated minimum stays unplaced until retained observation evidence is provided', () {
    final old = const SupplementalListeningHistory.empty().ingest([song()]);
    final decoded = SupplementalListeningHistory.decode(old.encode());
    expect(decoded.calendarEvents, isEmpty);
    expect(decoded.totalPlayCount, 1);
    final confirmed = decoded.observe(
      song(id: 'catalog-alias', title: 'Different metadata'),
      at: DateTime(2026, 10, 30),
    );
    expect(confirmed.totalPlayCount, 1);
    expect(confirmed.tracks, hasLength(1));
    expect(confirmed.calendarEvents, hasLength(1));
    expect(confirmed.datedEvents, isEmpty);
  });
}
