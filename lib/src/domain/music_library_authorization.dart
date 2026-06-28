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

  String get label {
    return switch (this) {
      MusicLibraryAuthorizationStatus.notDetermined => 'Not requested',
      MusicLibraryAuthorizationStatus.authorized => 'Authorized',
      MusicLibraryAuthorizationStatus.denied => 'Denied',
      MusicLibraryAuthorizationStatus.restricted => 'Restricted',
      MusicLibraryAuthorizationStatus.unsupported => 'Demo mode',
    };
  }

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
