import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appLockEnabledKey = 'songbrief_app_lock_enabled_v1';

final localAuthenticationProvider = Provider<LocalAuthentication>(
  (ref) => LocalAuthentication(),
);

final appLockControllerProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(
      AppLockController.new,
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

class AppLockController extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() async {
    final preferences = await SharedPreferences.getInstance();
    final supported = await _isSupported();
    final enabled = preferences.getBool(_appLockEnabledKey) ?? false;
    return AppLockState(
      enabled: enabled && supported,
      locked: enabled && supported,
      supported: supported,
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

    final supported = await _isSupported();
    if (!supported) {
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
    await preferences.setBool(_appLockEnabledKey, enabled);
  }

  Future<bool> _isSupported() async {
    if (kIsWeb) {
      return false;
    }
    try {
      return ref
          .read(localAuthenticationProvider)
          .isDeviceSupported()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
    } on Object {
      return false;
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
