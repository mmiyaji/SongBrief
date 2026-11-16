import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

Future<T> runPlatformCallOffUiIsolate<T>({
  required Future<T> Function() offUiIsolate,
  required Future<T> Function() onUiIsolate,
  required String debugName,
}) {
  final token = Platform.environment.containsKey('FLUTTER_TEST')
      ? null
      : RootIsolateToken.instance;
  if (token == null) {
    return onUiIsolate();
  }
  return Isolate.run(() {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    return offUiIsolate();
  }, debugName: debugName);
}
