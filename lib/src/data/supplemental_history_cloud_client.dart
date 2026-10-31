import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SupplementalHistoryCloudStatus {
  success,
  conflict,
  disabled,
  unavailable,
  error,
}

class SupplementalHistoryCloudResult {
  const SupplementalHistoryCloudResult({
    required this.status,
    this.payload,
    this.revision,
  });

  final SupplementalHistoryCloudStatus status;
  final String? payload;
  final String? revision;
}

abstract interface class SupplementalHistoryCloudClient {
  Future<SupplementalHistoryCloudResult> fetch();

  Future<SupplementalHistoryCloudResult> save({
    required String payload,
    required String? revision,
  });
}

class MethodChannelSupplementalHistoryCloudClient
    implements SupplementalHistoryCloudClient {
  const MethodChannelSupplementalHistoryCloudClient({
    this._channel = const MethodChannel('app.songbrief/music_library'),
  });

  final MethodChannel _channel;

  @override
  Future<SupplementalHistoryCloudResult> fetch() async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'fetchSupplementalListeningHistory',
      );
      return _result(raw);
    } on MissingPluginException {
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.unavailable,
      );
    } on PlatformException {
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.error,
      );
    } on Object {
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.error,
      );
    }
  }

  @override
  Future<SupplementalHistoryCloudResult> save({
    required String payload,
    required String? revision,
  }) async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'saveSupplementalListeningHistory',
        {'payload': payload, 'revision': revision},
      );
      return _result(raw);
    } on MissingPluginException {
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.unavailable,
      );
    } on PlatformException {
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.error,
      );
    } on Object {
      return const SupplementalHistoryCloudResult(
        status: SupplementalHistoryCloudStatus.error,
      );
    }
  }

  SupplementalHistoryCloudResult _result(Map<Object?, Object?>? raw) {
    final status = switch (raw?['status']) {
      'success' => SupplementalHistoryCloudStatus.success,
      'conflict' => SupplementalHistoryCloudStatus.conflict,
      'disabled' => SupplementalHistoryCloudStatus.disabled,
      'unavailable' => SupplementalHistoryCloudStatus.unavailable,
      _ => SupplementalHistoryCloudStatus.error,
    };
    return SupplementalHistoryCloudResult(
      status: status,
      payload: raw?['payload'] is String ? raw!['payload'] as String : null,
      revision: raw?['revision'] is String ? raw!['revision'] as String : null,
    );
  }
}

final supplementalHistoryCloudClientProvider =
    Provider<SupplementalHistoryCloudClient>(
      (ref) => const MethodChannelSupplementalHistoryCloudClient(),
    );

/// Overridable for controller tests. Production support is iOS only.
final supplementalHistoryCloudPlatformSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
);
