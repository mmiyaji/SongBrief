import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_firebase.dart';

const _firebaseAnalyticsEnabled = bool.fromEnvironment(
  'SONGBRIEF_FIREBASE_ANALYTICS_ENABLED',
  defaultValue: true,
);

final appAnalyticsProvider = Provider<AppAnalytics>(
  (ref) => const AppAnalytics.disabled(),
);

class AppAnalytics {
  const AppAnalytics._(this._analytics, {required this.enabled});

  const AppAnalytics.disabled() : this._(null, enabled: false);

  final FirebaseAnalytics? _analytics;
  final bool enabled;

  static Future<AppAnalytics> initialize() async {
    if (!_firebaseAnalyticsEnabled) {
      return const AppAnalytics.disabled();
    }

    try {
      await ensureSongBriefFirebaseInitialized();
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      await analytics.logAppOpen();
      return AppAnalytics._(analytics, enabled: true);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase Analytics disabled: $error');
      }
      return const AppAnalytics.disabled();
    }
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    try {
      await analytics.logEvent(
        name: name,
        parameters: _analyticsParameters(parameters),
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase Analytics event failed: $name $error');
      }
    }
  }

  Future<void> logScreenView(String screenName) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    try {
      await analytics.logScreenView(
        screenClass: 'SongBrief',
        screenName: screenName,
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase Analytics screen failed: $screenName $error');
      }
    }
  }

  Future<void> setUserProperty(String name, String? value) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }

    try {
      await analytics.setUserProperty(name: name, value: value);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase Analytics property failed: $name $error');
      }
    }
  }
}

Map<String, Object>? _analyticsParameters(Map<String, Object?> parameters) {
  if (parameters.isEmpty) {
    return null;
  }

  final result = <String, Object>{};
  for (final entry in parameters.entries) {
    final value = _analyticsValue(entry.value);
    if (value != null) {
      result[entry.key] = value;
    }
  }
  return result.isEmpty ? null : result;
}

Object? _analyticsValue(Object? value) {
  return switch (value) {
    null => null,
    String() => value.length > 100 ? value.substring(0, 100) : value,
    bool() => value ? 1 : 0,
    int() => value,
    num() => value.toDouble(),
    Enum() => value.name,
    _ =>
      value.toString().length > 100
          ? value.toString().substring(0, 100)
          : value.toString(),
  };
}
