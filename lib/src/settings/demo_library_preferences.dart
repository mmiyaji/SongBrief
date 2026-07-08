import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const temporaryDemoLibraryEnabledPreferenceKey =
    'songbrief_temporary_demo_library_enabled_v1';

final temporaryDemoLibraryProvider =
    NotifierProvider<TemporaryDemoLibraryController, bool>(
      TemporaryDemoLibraryController.new,
    );

class TemporaryDemoLibraryController extends Notifier<bool> {
  var _changedByUser = false;

  @override
  bool build() {
    _restore();
    return false;
  }

  void setEnabled(bool enabled) {
    _changedByUser = true;
    state = enabled;
    unawaited(_save(enabled));
  }

  void _restore() {
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      final preferences = await SharedPreferences.getInstance();
      final enabled = preferences.getBool(
        temporaryDemoLibraryEnabledPreferenceKey,
      );
      if (!disposed && !_changedByUser && enabled != null) {
        state = enabled;
      }
    }());
  }

  Future<void> _save(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      temporaryDemoLibraryEnabledPreferenceKey,
      enabled,
    );
  }
}
