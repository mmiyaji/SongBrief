enum MusicLibraryAuthorizationStatus {
  notDetermined,
  authorized,
  denied,
  restricted,
  unsupported;

  bool get canReadLibrary => this == MusicLibraryAuthorizationStatus.authorized;

  bool get canAskForAccess =>
      this == MusicLibraryAuthorizationStatus.notDetermined ||
      this == MusicLibraryAuthorizationStatus.denied ||
      this == MusicLibraryAuthorizationStatus.restricted;

  static MusicLibraryAuthorizationStatus fromPlatformValue(Object? value) {
    return switch (value) {
      'authorized' => MusicLibraryAuthorizationStatus.authorized,
      'denied' => MusicLibraryAuthorizationStatus.denied,
      'restricted' => MusicLibraryAuthorizationStatus.restricted,
      'notDetermined' => MusicLibraryAuthorizationStatus.notDetermined,
      _ => MusicLibraryAuthorizationStatus.unsupported,
    };
  }
}
