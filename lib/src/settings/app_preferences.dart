import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appLanguagePreferenceKey = 'songbrief_app_language_v1';

enum AppLanguage {
  system,
  japanese,
  english,
  chineseSimplified,
  korean;

  Locale? get locale {
    return switch (this) {
      AppLanguage.system => null,
      AppLanguage.japanese => const Locale('ja'),
      AppLanguage.english => const Locale('en'),
      AppLanguage.chineseSimplified => const Locale('zh'),
      AppLanguage.korean => const Locale('ko'),
    };
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

class AppLanguageController extends Notifier<AppLanguage> {
  var _changedByUser = false;

  @override
  AppLanguage build() {
    _restore();
    return AppLanguage.system;
  }

  void setLanguage(AppLanguage language) {
    _changedByUser = true;
    state = language;
    unawaited(_save(language));
  }

  void _restore() {
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
    });
    unawaited(() async {
      final preferences = await SharedPreferences.getInstance();
      final language = _appLanguageFromName(
        preferences.getString(_appLanguagePreferenceKey),
      );
      if (!disposed && !_changedByUser && language != null) {
        state = language;
      }
    }());
  }

  Future<void> _save(AppLanguage language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_appLanguagePreferenceKey, language.name);
  }
}

AppLanguage? _appLanguageFromName(String? name) {
  for (final language in AppLanguage.values) {
    if (language.name == name) {
      return language;
    }
  }
  return null;
}
