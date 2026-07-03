import 'library_track.dart';

bool hasAppleMusicSongLink(LibraryTrack track) {
  return _appleMusicCatalogId(track) != null;
}

Uri appleMusicUrlForTrack(LibraryTrack track) {
  final catalogId = _appleMusicCatalogId(track);
  if (catalogId != null) {
    return Uri.https(
      'music.apple.com',
      '/song/${_appleMusicSlug(track.title)}/$catalogId',
    );
  }

  final query = [
    track.title,
    track.artist,
    track.albumTitle,
  ].where((value) => value.trim().isNotEmpty).join(' ');
  return Uri.https('music.apple.com', '/search', {'term': query});
}

String? _appleMusicCatalogId(LibraryTrack track) {
  final id = track.appleMusicStoreId?.trim();
  if (id == null || id.isEmpty || id == '0') {
    return null;
  }
  return id;
}

String _appleMusicSlug(String title) {
  final slug = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'song' : slug;
}
