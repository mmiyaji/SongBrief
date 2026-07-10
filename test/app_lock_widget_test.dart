import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songbrief/src/app.dart';
import 'package:songbrief/src/settings/app_lock.dart';

void main() {
  testWidgets('does not keep preview protection enabled when app lock is off', (
    tester,
  ) async {
    final protector = _FakeAppLockPrivacyProtector();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockControllerProvider.overrideWith(
            () => _TestAppLockController(
              const AppLockState(
                enabled: false,
                locked: false,
                supported: true,
              ),
            ),
          ),
          appLockPrivacyProtectorProvider.overrideWithValue(protector),
        ],
        child: const MaterialApp(home: AppLockGate(child: Text('Unlocked'))),
      ),
    );
    await tester.pumpAndSettle();
    protector.lockStates.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    expect(protector.lockStates.last, isFalse);
  });

  testWidgets('blocks content while app lock state initializes', (
    tester,
  ) async {
    var taps = 0;
    final protector = _FakeAppLockPrivacyProtector();
    final privateActionFocusNode = FocusNode(
      debugLabel: 'private-action-focus',
    );
    addTearDown(privateActionFocusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppLockEnabledProvider.overrideWithValue(true),
          appLockControllerProvider.overrideWith(_LoadingAppLockController.new),
          appLockPrivacyProtectorProvider.overrideWithValue(protector),
        ],
        child: MaterialApp(
          home: AppLockGate(
            child: TextButton(
              focusNode: privateActionFocusNode,
              onPressed: () {
                taps += 1;
              },
              child: const Text('Private action'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('app-lock-initializing')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-lock-privacy-mark')), findsOneWidget);
    expect(find.semantics.byLabel('Private action'), findsNothing);

    privateActionFocusNode.requestFocus();
    await tester.pump();

    await tester.tap(find.text('Private action'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
    expect(privateActionFocusNode.hasFocus, isFalse);
    expect(protector.lockStates, contains(true));
  });

  testWidgets('locks above modal sheets and blocks sheet actions', (
    tester,
  ) async {
    var sheetActions = 0;
    final protector = _FakeAppLockPrivacyProtector();
    final sheetActionFocusNode = FocusNode(debugLabel: 'sheet-action-focus');
    addTearDown(sheetActionFocusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockControllerProvider.overrideWith(
            () => _TestAppLockController(
              const AppLockState(enabled: true, locked: false, supported: true),
            ),
          ),
          appLockPrivacyProtectorProvider.overrideWithValue(protector),
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
                              focusNode: sheetActionFocusNode,
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
    sheetActionFocusNode.requestFocus();
    await tester.pump();
    expect(sheetActionFocusNode.hasFocus, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('SongBrief is locked'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-lock-privacy-mark')), findsOneWidget);
    expect(find.semantics.byLabel('Sheet action'), findsNothing);
    expect(find.semantics.byLabel('Unlock'), findsOne);
    expect(sheetActionFocusNode.hasFocus, isFalse);
    expect(protector.lockStates, contains(true));

    sheetActionFocusNode.requestFocus();
    await tester.pump();
    expect(sheetActionFocusNode.hasFocus, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('sheet-action')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(sheetActions, 0);
  });
}

class _LoadingAppLockController extends AppLockController {
  @override
  Future<AppLockState> build() {
    return Completer<AppLockState>().future;
  }
}

class _FakeAppLockPrivacyProtector extends AppLockPrivacyProtector {
  final lockStates = <bool>[];

  @override
  Future<void> setLocked(bool locked) async {
    lockStates.add(locked);
  }
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
