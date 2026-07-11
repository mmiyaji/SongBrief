import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget extension does not inherit Runner linker flags', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    for (final configurationId in const [
      '8C2A00112F10001100C0DE01',
      '8C2A00122F10001200C0DE01',
      '8C2A00132F10001300C0DE01',
    ]) {
      final configuration = RegExp(
        '$configurationId.*?buildSettings = \\{(.*?)\\n\\s*\\};',
        dotAll: true,
      ).firstMatch(project);

      expect(configuration, isNotNull, reason: configurationId);
      expect(
        configuration!.group(1),
        contains('OTHER_LDFLAGS = "";'),
        reason: configurationId,
      );
    }
  });
}
