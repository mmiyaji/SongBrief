import 'dart:async';
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_firebase.dart';

const crashReportingEnabledPreferenceKey =
    'songbrief_crash_reporting_enabled_v1';

const _firebaseCrashlyticsBuildEnabled = bool.fromEnvironment(
  'SONGBRIEF_FIREBASE_CRASHLYTICS_ENABLED',
  defaultValue: !kDebugMode,
);

final initialCrashReportingStateProvider = Provider<CrashReportingState>(
  (ref) => const CrashReportingState(
    available: false,
    enabled: false,
    updating: false,
    unavailableReason: CrashReportingUnavailableReason.disabledByBuild,
  ),
);

final crashReportingControllerProvider =
    NotifierProvider<CrashReportingController, CrashReportingState>(
      CrashReportingController.new,
    );

enum CrashReportingUnavailableReason {
  disabledByBuild,
  unsupportedPlatform,
  initializationFailed,
}

class CrashReportingState {
  const CrashReportingState({
    required this.available,
    required this.enabled,
    required this.updating,
    this.unavailableReason,
  });

  final bool available;
  final bool enabled;
  final bool updating;
  final CrashReportingUnavailableReason? unavailableReason;

  bool get canToggle => available && !updating;

  CrashReportingState copyWith({
    bool? available,
    bool? enabled,
    bool? updating,
    CrashReportingUnavailableReason? unavailableReason,
    bool clearUnavailableReason = false,
  }) {
    return CrashReportingState(
      available: available ?? this.available,
      enabled: enabled ?? this.enabled,
      updating: updating ?? this.updating,
      unavailableReason: clearUnavailableReason
          ? null
          : unavailableReason ?? this.unavailableReason,
    );
  }
}

class CrashReportingController extends Notifier<CrashReportingState> {
  @override
  CrashReportingState build() {
    return ref.watch(initialCrashReportingStateProvider);
  }

  Future<void> setEnabled(bool enabled) async {
    if (!state.available || state.updating) {
      return;
    }

    state = state.copyWith(updating: true, clearUnavailableReason: true);
    final next = await CrashReporting.setEnabled(enabled);
    state = next;
  }
}

class CrashReporting {
  const CrashReporting._();

  static var _collectionEnabled = false;
  static var _crashlyticsConfigured = false;
  static var _handlersInstalled = false;
  static FlutterExceptionHandler? _previousFlutterOnError;
  static ErrorCallback? _previousPlatformOnError;

  static Future<CrashReportingState> initialize(
    SharedPreferences preferences,
  ) async {
    final enabled =
        preferences.getBool(crashReportingEnabledPreferenceKey) ?? false;
    return _applyCollectionEnabled(enabled);
  }

  static Future<CrashReportingState> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final next = await _applyCollectionEnabled(enabled);
    if (next.available) {
      await preferences.setBool(
        crashReportingEnabledPreferenceKey,
        next.enabled,
      );
    }
    return next;
  }

  static Future<CrashReportingState> _applyCollectionEnabled(
    bool enabled,
  ) async {
    if (!_firebaseCrashlyticsBuildEnabled) {
      _collectionEnabled = false;
      return const CrashReportingState(
        available: false,
        enabled: false,
        updating: false,
        unavailableReason: CrashReportingUnavailableReason.disabledByBuild,
      );
    }
    if (kIsWeb) {
      _collectionEnabled = false;
      return const CrashReportingState(
        available: false,
        enabled: false,
        updating: false,
        unavailableReason: CrashReportingUnavailableReason.unsupportedPlatform,
      );
    }

    if (!enabled && !_crashlyticsConfigured) {
      _collectionEnabled = false;
      return const CrashReportingState(
        available: true,
        enabled: false,
        updating: false,
      );
    }

    try {
      await ensureSongBriefFirebaseInitialized();
      _crashlyticsConfigured = true;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
      _collectionEnabled = enabled;
      _installHandlers();
      return CrashReportingState(
        available: true,
        enabled: enabled,
        updating: false,
      );
    } on Object catch (error) {
      _collectionEnabled = false;
      if (kDebugMode) {
        debugPrint('Firebase Crashlytics disabled: $error');
      }
      return const CrashReportingState(
        available: false,
        enabled: false,
        updating: false,
        unavailableReason: CrashReportingUnavailableReason.initializationFailed,
      );
    }
  }

  static void _installHandlers() {
    if (_handlersInstalled) {
      return;
    }
    _handlersInstalled = true;
    _previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final previous = _previousFlutterOnError;
      if (previous == null) {
        FlutterError.presentError(details);
      } else {
        previous(details);
      }
      if (_collectionEnabled) {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      }
    };

    _previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      final handledByPrevious =
          _previousPlatformOnError?.call(error, stack) ?? false;
      if (_collectionEnabled) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
        return true;
      }
      return handledByPrevious;
    };
  }
}
