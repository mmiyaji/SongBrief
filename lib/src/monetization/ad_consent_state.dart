class PlatformAdConsentResult {
  const PlatformAdConsentResult({
    required this.supported,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    this.errorMessage,
  });

  const PlatformAdConsentResult.unsupported()
    : supported = false,
      canRequestAds = false,
      privacyOptionsRequired = false,
      errorMessage = null;

  final bool supported;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final String? errorMessage;
}
