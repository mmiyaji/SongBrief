import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coverage gate fails when a required target is missing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'songbrief-coverage-gate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final lcov = File('${directory.path}${Platform.pathSeparator}lcov.info');
    final report = File(
      '${directory.path}${Platform.pathSeparator}coverage_report.md',
    );
    await lcov.writeAsString('TN:\nend_of_record\n');

    final result = await Process.run(
      'dart',
      ['tool/coverage_report.dart', lcov.path, report.path],
      workingDirectory: Directory.current.path,
      runInShell: Platform.isWindows,
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('Coverage data is missing'));
    expect(report.existsSync(), isFalse);
  });
}
