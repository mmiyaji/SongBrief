import 'dart:io';

const _defaultLcovPath = 'coverage/lcov.info';
const _defaultReportPath = 'test/coverage_report.md';
const _minimumCoverage = 95.0;

const _unitCoverageTargets = {
  'lib/src/domain/apple_music_link.dart',
  'lib/src/domain/library_overview.dart',
  'lib/src/domain/library_snapshot.dart',
  'lib/src/domain/library_track.dart',
  'lib/src/domain/music_library_authorization.dart',
  'lib/src/domain/music_stats_state.dart',
  'lib/src/data/library_snapshot_repository.dart',
  'lib/src/export/library_exporter.dart',
  'lib/src/settings/app_preferences.dart',
  'lib/src/settings/library_filter_preferences.dart',
  'lib/src/settings/snapshot_preferences.dart',
  'lib/src/theme/app_theme.dart',
  'lib/src/monetization/ad_consent_state.dart',
  'lib/src/monetization/monetization_config.dart',
};

void main(List<String> args) {
  final lcovPath = args.isEmpty ? _defaultLcovPath : args[0];
  final reportPath = args.length < 2 ? _defaultReportPath : args[1];
  final records = _parseLcov(File(lcovPath));
  final targetRecords = [
    for (final target in _unitCoverageTargets)
      records[target] ?? CoverageRecord(file: target),
  ]..sort((a, b) => a.file.compareTo(b.file));

  final summary = CoverageSummary(targetRecords);
  final markdown = _buildMarkdown(summary);
  File(reportPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(markdown);

  stdout.writeln(
    'Unit coverage: ${summary.coveredLines}/${summary.totalLines} '
    '(${summary.percent.toStringAsFixed(2)}%)',
  );
  stdout.writeln('Report: $reportPath');

  if (summary.percent < _minimumCoverage) {
    stderr.writeln(
      'Coverage is below ${_minimumCoverage.toStringAsFixed(0)}%.',
    );
    exitCode = 1;
  }
}

Map<String, CoverageRecord> _parseLcov(File file) {
  if (!file.existsSync()) {
    throw StateError('LCOV file not found: ${file.path}');
  }

  final records = <String, CoverageRecord>{};
  CoverageRecord? current;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = CoverageRecord(file: _normalizePath(line.substring(3)));
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final lineNumber = int.tryParse(parts[0]);
        final hitCount = int.tryParse(parts[1]);
        if (lineNumber != null && hitCount != null) {
          current.addLine(lineNumber, hitCount);
        }
      }
    } else if (line == 'end_of_record' && current != null) {
      records[current.file] = current;
      current = null;
    }
  }
  return records;
}

String _normalizePath(String path) {
  return path.replaceAll('\\', '/');
}

String _buildMarkdown(CoverageSummary summary) {
  final generatedAt = DateTime.now().toLocal();
  final buffer = StringBuffer()
    ..writeln('# Unit Coverage Report')
    ..writeln()
    ..writeln('- Generated: ${_formatDate(generatedAt)}')
    ..writeln('- Command: `flutter test --coverage`')
    ..writeln('- Gate: ${_minimumCoverage.toStringAsFixed(0)}% or higher')
    ..writeln(
      '- Result: ${summary.coveredLines}/${summary.totalLines} '
      'lines (${summary.percent.toStringAsFixed(2)}%)',
    )
    ..writeln()
    ..writeln('## Scope')
    ..writeln()
    ..writeln(
      'This report measures unit-testable Dart logic: domain models, snapshot '
      'storage, export formatting, preference controllers, theme tokens, and '
      'small monetization value objects. Generated localization files, '
      'Flutter UI widgets, Firebase/AdMob runtimes, and iOS MethodChannel '
      'adapters are intentionally excluded from this unit coverage gate and '
      'remain covered by widget/integration/manual release checks.',
    )
    ..writeln()
    ..writeln('## Files')
    ..writeln()
    ..writeln('| File | Covered | Total | Coverage |')
    ..writeln('| --- | ---: | ---: | ---: |');

  for (final record in summary.records) {
    buffer.writeln(
      '| `${record.file}` | ${record.coveredLines} | ${record.totalLines} | '
      '${record.percent.toStringAsFixed(2)}% |',
    );
  }

  return buffer.toString();
}

String _formatDate(DateTime dateTime) {
  return [
    dateTime.year.toString().padLeft(4, '0'),
    dateTime.month.toString().padLeft(2, '0'),
    dateTime.day.toString().padLeft(2, '0'),
  ].join('-');
}

class CoverageRecord {
  CoverageRecord({required this.file});

  final String file;
  final _lines = <int, int>{};

  int get totalLines => _lines.length;

  int get coveredLines => _lines.values.where((count) => count > 0).length;

  double get percent => totalLines == 0 ? 100 : coveredLines * 100 / totalLines;

  void addLine(int lineNumber, int hitCount) {
    _lines[lineNumber] = hitCount;
  }
}

class CoverageSummary {
  CoverageSummary(this.records);

  final List<CoverageRecord> records;

  int get totalLines =>
      records.fold(0, (total, item) => total + item.totalLines);

  int get coveredLines =>
      records.fold(0, (total, item) => total + item.coveredLines);

  double get percent => totalLines == 0 ? 100 : coveredLines * 100 / totalLines;
}
