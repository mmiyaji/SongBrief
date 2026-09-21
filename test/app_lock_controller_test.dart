import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbrief/src/settings/app_lock.dart';

void main() {
  test(
    'unlock can be retried after an asynchronous authentication error',
    () async {
      SharedPreferences.setMockInitialValues({
        appLockEnabledPreferenceKey: true,
      });
      final authentication = _FakeLocalAuthentication(
        checkSupport: () async => true,
        authenticateResult: true,
      )..authenticateError = PlatformException(code: 'temporarily_unavailable');
      final container = _createContainer(authentication);
      addTearDown(container.dispose);
      await container.read(appLockControllerProvider.future);
      await _drainSupportCheck();
      final controller = container.read(appLockControllerProvider.notifier);

      await controller.unlock(localizedReason: 'Unlock SongBrief.');

      final failed = container.read(appLockControllerProvider).requireValue;
      expect(failed.locked, isTrue);
      expect(failed.authenticating, isFalse);
      expect(failed.errorMessage, 'authentication_failed');
      authentication.authenticateError = null;
      await controller.unlock(localizedReason: 'Unlock SongBrief.');
      expect(
        container.read(appLockControllerProvider).requireValue.locked,
        isFalse,
      );
      expect(authentication.authenticateCalls, 2);
    },
  );

  test(
    'setup exits busy state after an asynchronous authentication error',
    () async {
      SharedPreferences.setMockInitialValues({});
      final authentication = _FakeLocalAuthentication(
        checkSupport: () async => true,
      )..authenticateError = PlatformException(code: 'temporarily_unavailable');
      final container = _createContainer(
        authentication,
        initiallyEnabled: false,
      );
      addTearDown(container.dispose);
      await container.read(appLockControllerProvider.future);

      await container
          .read(appLockControllerProvider.notifier)
          .setEnabled(true, localizedReason: 'Enable SongBrief lock.');

      final failed = container.read(appLockControllerProvider).requireValue;
      expect(failed.enabled, isFalse);
      expect(failed.authenticating, isFalse);
      expect(failed.errorMessage, 'authentication_failed');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(appLockEnabledPreferenceKey), isFalse);
    },
  );

  test(
    'keeps a saved lock enabled and locked when support check times out',
    () async {
      SharedPreferences.setMockInitialValues({
        appLockEnabledPreferenceKey: true,
      });
      final authentication = _FakeLocalAuthentication(
        checkSupport: () => Completer<bool>().future,
      );
      final container = _createContainer(authentication);
      addTearDown(container.dispose);

      await container.read(appLockControllerProvider.future);
      await _drainSupportCheck();

      final lockState = container.read(appLockControllerProvider).requireValue;
      final preferences = await SharedPreferences.getInstance();
      expect(lockState.enabled, isTrue);
      expect(lockState.locked, isTrue);
      expect(lockState.supported, isTrue);
      expect(preferences.getBool(appLockEnabledPreferenceKey), isTrue);
    },
  );

  test(
    'keeps a saved lock enabled and locked after a transient support error',
    () async {
      SharedPreferences.setMockInitialValues({
        appLockEnabledPreferenceKey: true,
      });
      final authentication = _FakeLocalAuthentication(
        checkSupport: () async {
          await Future<void>.delayed(Duration.zero);
          throw PlatformException(code: 'temporarily_unavailable');
        },
      );
      final container = _createContainer(authentication);
      addTearDown(container.dispose);

      await container.read(appLockControllerProvider.future);
      await _drainSupportCheck();

      final lockState = container.read(appLockControllerProvider).requireValue;
      final preferences = await SharedPreferences.getInstance();
      expect(lockState.enabled, isTrue);
      expect(lockState.locked, isTrue);
      expect(lockState.supported, isTrue);
      expect(preferences.getBool(appLockEnabledPreferenceKey), isTrue);
    },
  );

  test('continues setup authentication when support check times out', () async {
    SharedPreferences.setMockInitialValues({});
    final authentication = _FakeLocalAuthentication(
      checkSupport: () => Completer<bool>().future,
      authenticateResult: true,
    );
    final container = _createContainer(authentication, initiallyEnabled: false);
    addTearDown(container.dispose);

    await container.read(appLockControllerProvider.future);
    await container
        .read(appLockControllerProvider.notifier)
        .setEnabled(true, localizedReason: 'Enable SongBrief lock.');

    final lockState = container.read(appLockControllerProvider).requireValue;
    final preferences = await SharedPreferences.getInstance();
    expect(authentication.authenticateCalls, 1);
    expect(lockState.enabled, isTrue);
    expect(lockState.locked, isFalse);
    expect(preferences.getBool(appLockEnabledPreferenceKey), isTrue);
  });
}

ProviderContainer _createContainer(
  LocalAuthentication authentication, {
  bool initiallyEnabled = true,
}) {
  return ProviderContainer(
    overrides: [
      initialAppLockEnabledProvider.overrideWithValue(initiallyEnabled),
      localAuthenticationProvider.overrideWithValue(authentication),
      appLockSupportCheckTimeoutProvider.overrideWithValue(
        const Duration(milliseconds: 1),
      ),
    ],
  );
}

Future<void> _drainSupportCheck() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

class _FakeLocalAuthentication extends LocalAuthentication {
  _FakeLocalAuthentication({
    required this.checkSupport,
    this.authenticateResult = false,
  });

  final Future<bool> Function() checkSupport;
  final bool authenticateResult;
  int authenticateCalls = 0;
  Object? authenticateError;

  @override
  Future<bool> isDeviceSupported() => checkSupport();

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Object? authMessages,
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalls += 1;
    await Future<void>.delayed(Duration.zero);
    final error = authenticateError;
    if (error != null) {
      throw error;
    }
    return authenticateResult;
  }
}
