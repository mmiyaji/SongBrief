import 'library_track.dart';

bool hasAppleMusicSongLink(LibraryTrack track) {
  return _officialTrackUrl(track.appleMusicUrl) != null ||
      _appleMusicCatalogId(track) != null;
}

Uri appleMusicUrlForTrack(LibraryTrack track) {
  final officialUrl = _officialTrackUrl(track.appleMusicUrl);
  if (officialUrl != null) return officialUrl;
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
  return validAppleMusicCatalogId(track.appleMusicStoreId);
}

Uri? _officialTrackUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'music.apple.com' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort && uri.port != 443 ||
      uri.hasFragment) {
    return null;
  }
  final segments = uri.pathSegments;
  final songIndex = segments.indexOf('song');
  final songRouteLength = segments.length - songIndex;
  final isSongRoute =
      songIndex >= 0 &&
      (songRouteLength == 2 || songRouteLength == 3) &&
      validAppleMusicCatalogId(segments.last) != null;
  final albumIndex = segments.indexOf('album');
  final isAlbumTrackRoute =
      albumIndex >= 0 &&
      segments.length - albumIndex >= 3 &&
      validAppleMusicCatalogId(uri.queryParameters['i']) != null;
  if (!isSongRoute && !isAlbumTrackRoute) return null;
  return uri;
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
