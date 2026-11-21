import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_data_preferences_storage.dart';

const _appLanguagePreferenceKey = 'songbrief_app_language_v1';
const _phonePlayingLayoutPreferenceKey = 'songbrief_phone_playing_layout_v1';
const songBriefSimplifiedChineseLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hans',
);

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
      AppLanguage.chineseSimplified => songBriefSimplifiedChineseLocale,
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

enum PhonePlayingLayout { overlay, sideBySide }

final phonePlayingLayoutProvider =
    NotifierProvider<PhonePlayingLayoutController, PhonePlayingLayout>(
      PhonePlayingLayoutController.new,
    );

class PhonePlayingLayoutController extends Notifier<PhonePlayingLayout> {
  bool _changedByUser = false;
  late Future<SharedPreferences?> _preferences;

  @override
  PhonePlayingLayout build() {
    final preferences = ref.read(musicDataSharedPreferencesProvider);
    if (preferences != null) {
      _preferences = Future.value(preferences);
      return _readLayout(preferences);
    }
    _preferences = ref.read(musicDataPreferencesFallbackProvider);
    unawaited(_restore());
    return PhonePlayingLayout.overlay;
  }

  Future<void> _restore() async {
    final preferences = await _preferences;
    if (ref.mounted && !_changedByUser && preferences != null) {
      state = _readLayout(preferences);
    }
  }

  PhonePlayingLayout _readLayout(SharedPreferences preferences) =>
      preferences.get(_phonePlayingLayoutPreferenceKey) ==
          PhonePlayingLayout.sideBySide.name
      ? PhonePlayingLayout.sideBySide
      : PhonePlayingLayout.overlay;

  void setLayout(PhonePlayingLayout layout) {
    _changedByUser = true;
    state = layout;
    unawaited(_save(layout));
  }

  Future<void> _save(PhonePlayingLayout layout) async {
    final preferences = await _preferences;
    try {
      await preferences?.setString(
        _phonePlayingLayoutPreferenceKey,
        layout.name,
      );
    } on Exception {
      // The layout can still be changed for the current session.
    }
  }
}
