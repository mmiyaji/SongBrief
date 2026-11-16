Future<T> runPlatformCallOffUiIsolate<T>({
  required Future<T> Function() offUiIsolate,
  required Future<T> Function() onUiIsolate,
  required String debugName,
}) {
  return onUiIsolate();
}
