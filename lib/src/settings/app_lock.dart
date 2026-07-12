import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appLockEnabledPreferenceKey = 'songbrief_app_lock_enabled_v1';
const appLockPrivacyScreenImageName = 'PrivacyScreen';

final initialAppLockEnabledProvider = Provider<bool>((ref) => false);

final localAuthenticationProvider = Provider<LocalAuthentication>(
  (ref) => LocalAuthentication(),
);

final appLockSupportCheckTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

final appLockControllerProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(
      AppLockController.new,
    );

final appLockPrivacyProtectorProvider = Provider<AppLockPrivacyProtector>(
  (ref) => const AppLockPrivacyProtector(),
);

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.locked,
    required this.supported,
    this.authenticating = false,
    this.errorMessage,
  });

  final bool enabled;
  final bool locked;
  final bool supported;
  final bool authenticating;
  final String? errorMessage;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? supported,
    bool? authenticating,
    String? errorMessage,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      supported: supported ?? this.supported,
      authenticating: authenticating ?? this.authenticating,
      errorMessage: errorMessage,
    );
  }
}

class AppLockPrivacyProtector {
  const AppLockPrivacyProtector();

  Future<void> setLocked(bool locked) async {
    if (!_supportsLockPreviewProtection) {
      return;
    }

    try {
      if (locked) {
        await ScreenProtector.protectDataLeakageWithImage(
          appLockPrivacyScreenImageName,
        );
      } else {
        await ScreenProtector.protectDataLeakageOff();
      }
    } on MissingPluginException {
      // Preview protection is best-effort and should not block app locking.
    } on PlatformException {
      // Keep the visual lock active even if native secure preview setup fails.
    }
  }
}

bool get _supportsLockPreviewProtection {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

class AppLockController extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() {
    final enabled = ref.watch(initialAppLockEnabledProvider);
    if (enabled) {
      unawaited(_verifySavedLockSupport());
    }
    return Future.value(
      AppLockState(enabled: enabled, locked: enabled, supported: true),
    );
  }

  Future<void> setEnabled(
    bool enabled, {
    required String localizedReason,
  }) async {
    final current = _currentState();
    if (!enabled) {
      await _saveEnabled(false);
      state = AsyncData(
        current.copyWith(enabled: false, locked: false, authenticating: false),
      );
      return;
    }

    final support = await _checkSupport();
    if (support == _AppLockSupport.unsupported) {
      await _saveEnabled(false);
      state = AsyncData(
        current.copyWith(
          enabled: false,
          locked: false,
          supported: false,
          authenticating: false,
          errorMessage: 'device_authentication_unavailable',
        ),
      );
      return;
    }

    state = AsyncData(
      current.copyWith(
        supported: true,
        authenticating: true,
        errorMessage: null,
      ),
    );
    final unlocked = await _authenticate(localizedReason);
    if (!unlocked) {
      await _saveEnabled(false);
      state = AsyncData(
        current.copyWith(
          enabled: false,
          locked: false,
          supported: true,
          authenticating: false,
          errorMessage: 'authentication_failed',
        ),
      );
      return;
    }

    await _saveEnabled(true);
    state = const AsyncData(
      AppLockState(enabled: true, locked: false, supported: true),
    );
  }

  Future<void> lock() async {
    final current = state.value;
    if (current == null ||
        !current.enabled ||
        !current.supported ||
        current.locked ||
        current.authenticating) {
      return;
    }
    state = AsyncData(current.copyWith(locked: true));
  }

  Future<void> unlock({required String localizedReason}) async {
    final current = _currentState();
    if (!current.enabled || !current.supported || current.authenticating) {
      return;
    }

    state = AsyncData(
      current.copyWith(authenticating: true, errorMessage: null),
    );
    final unlocked = await _authenticate(localizedReason);
    state = AsyncData(
      current.copyWith(
        locked: !unlocked,
        authenticating: false,
        errorMessage: unlocked ? null : 'authentication_failed',
      ),
    );
  }

  Future<void> _saveEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(appLockEnabledPreferenceKey, enabled);
  }

  Future<void> _verifySavedLockSupport() async {
    final support = await _checkSupport();
    final current = state.value;
    if (current == null || !current.enabled) {
      return;
    }
    if (support == _AppLockSupport.indeterminate) {
      // A timeout or transient platform failure must not silently remove a
      // saved lock. Keep the app locked and allow authentication to be retried.
      return;
    }
    if (support == _AppLockSupport.unsupported) {
      await _saveEnabled(false);
      state = AsyncData(
        current.copyWith(enabled: false, locked: false, supported: false),
      );
      return;
    }
    state = AsyncData(current.copyWith(supported: true));
  }

  Future<_AppLockSupport> _checkSupport() async {
    if (kIsWeb) {
      return _AppLockSupport.unsupported;
    }
    try {
      final supported = await ref
          .read(localAuthenticationProvider)
          .isDeviceSupported()
          .timeout(ref.read(appLockSupportCheckTimeoutProvider));
      return supported
          ? _AppLockSupport.supported
          : _AppLockSupport.unsupported;
    } on TimeoutException {
      return _AppLockSupport.indeterminate;
    } on Object {
      return _AppLockSupport.indeterminate;
    }
  }

  Future<bool> _authenticate(String localizedReason) async {
    try {
      return ref
          .read(localAuthenticationProvider)
          .authenticate(
            localizedReason: localizedReason,
            persistAcrossBackgrounding: true,
          );
    } on Object {
      return false;
    }
  }

  AppLockState _currentState() {
    return state.value ??
        const AppLockState(enabled: false, locked: false, supported: false);
  }
}

enum _AppLockSupport { supported, unsupported, indeterminate }
