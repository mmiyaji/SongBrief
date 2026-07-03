import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/settings/app_lock.dart';

void main() {
  testWidgets('locks above modal sheets and blocks sheet actions', (
    tester,
  ) async {
    var sheetActions = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockControllerProvider.overrideWith(
            () => _TestAppLockController(
              const AppLockState(enabled: true, locked: false, supported: true),
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey('open-sheet'),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (context) {
                          return SafeArea(
                            child: TextButton(
                              key: const ValueKey('sheet-action'),
                              onPressed: () {
                                sheetActions += 1;
                              },
                              child: const Text('Sheet action'),
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('Open sheet'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Sheet action'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('SongBrief is locked'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('sheet-action')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(sheetActions, 0);
  });
}

class _TestAppLockController extends AppLockController {
  _TestAppLockController(this.initialState);

  final AppLockState initialState;

  @override
  Future<AppLockState> build() async {
    return initialState;
  }

  @override
  Future<void> lock() async {
    final current = state.value ?? initialState;
    if (!current.enabled ||
        !current.supported ||
        current.locked ||
        current.authenticating) {
      return;
    }
    state = AsyncData(current.copyWith(locked: true));
  }

  @override
  Future<void> unlock({required String localizedReason}) async {
    final current = state.value ?? initialState;
    state = AsyncData(current.copyWith(locked: false, authenticating: false));
  }
}
