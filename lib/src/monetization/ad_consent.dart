import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_runtime.dart';
import 'ad_consent_state.dart';
import 'monetization_config.dart';

final adConsentControllerProvider =
    AsyncNotifierProvider<AdConsentController, AdConsentState>(
      AdConsentController.new,
    );

class AdConsentState {
  const AdConsentState({
    required this.supported,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    required this.updating,
    this.errorMessage,
  });

  const AdConsentState.unsupported()
    : supported = false,
      canRequestAds = false,
      privacyOptionsRequired = false,
      updating = false,
      errorMessage = null;

  final bool supported;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final bool updating;
  final String? errorMessage;

  AdConsentState copyWith({
    bool? supported,
    bool? canRequestAds,
    bool? privacyOptionsRequired,
    bool? updating,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AdConsentState(
      supported: supported ?? this.supported,
      canRequestAds: canRequestAds ?? this.canRequestAds,
      privacyOptionsRequired:
          privacyOptionsRequired ?? this.privacyOptionsRequired,
      updating: updating ?? this.updating,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  static AdConsentState fromPlatform(PlatformAdConsentResult result) {
    return AdConsentState(
      supported: result.supported,
      canRequestAds: result.canRequestAds,
      privacyOptionsRequired: result.privacyOptionsRequired,
      updating: false,
      errorMessage: result.errorMessage,
    );
  }
}

class AdConsentController extends AsyncNotifier<AdConsentState> {
  @override
  Future<AdConsentState> build() async {
    if (!_usesPlatformConsent) {
      return const AdConsentState.unsupported();
    }
    return _updateConsent();
  }

  Future<AdConsentState> refresh() async {
    if (!_usesPlatformConsent) {
      const next = AdConsentState.unsupported();
      state = const AsyncData(next);
      return next;
    }

    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(
        previous.copyWith(updating: true, clearErrorMessage: true),
      );
    }
    final next = await _updateConsent();
    state = AsyncData(next);
    return next;
  }

  Future<AdConsentState> showPrivacyOptions() async {
    if (!_usesPlatformConsent) {
      const next = AdConsentState.unsupported();
      state = const AsyncData(next);
      return next;
    }

    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(
        previous.copyWith(updating: true, clearErrorMessage: true),
      );
    }

    final next = await _readPlatformConsent(showAdPrivacyOptionsIfSupported());
    state = AsyncData(next);
    return next;
  }

  bool get _usesPlatformConsent =>
      MonetizationConfig.adMode.showsAdSlots && adRuntimeCanLoadAds;

  Future<AdConsentState> _updateConsent() {
    return _readPlatformConsent(updateAdConsentIfSupported());
  }

  Future<AdConsentState> _readPlatformConsent(
    Future<PlatformAdConsentResult> source,
  ) async {
    try {
      return AdConsentState.fromPlatform(await source);
    } on Object catch (error) {
      return AdConsentState(
        supported: adRuntimeCanLoadAds,
        canRequestAds: false,
        privacyOptionsRequired: false,
        updating: false,
        errorMessage: error.toString(),
      );
    }
  }
}
