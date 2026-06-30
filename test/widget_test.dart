import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';

void main() {
  testWidgets('shows the SongBrief dashboard shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SongBriefApp()));
    await tester.pumpAndSettle();

    expect(find.text('SongBrief'), findsOneWidget);
    expect(find.text('Skyline Echo'), findsWidgets);
    expect(find.text('再生回数'), findsWidgets);
    expect(find.text('今週の傾向'), findsOneWidget);
    expect(find.text('最近再生した曲'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });
}
