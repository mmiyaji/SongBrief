import 'background_platform_call_stub.dart'
    if (dart.library.io) 'background_platform_call_io.dart'
    as impl;

/// Runs a large platform-channel call and its decoding on a background
/// isolate so the UI isolate keeps animating while the payload is decoded.
///
/// Falls back to [onUiIsolate] when background platform channels are not
/// available (web, tests with mocked channels).
Future<T> runPlatformCallOffUiIsolate<T>({
  required Future<T> Function() offUiIsolate,
  required Future<T> Function() onUiIsolate,
  required String debugName,
}) {
  return impl.runPlatformCallOffUiIsolate(
    offUiIsolate: offUiIsolate,
    onUiIsolate: onUiIsolate,
    debugName: debugName,
  );
}
