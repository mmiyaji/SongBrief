import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage {
  system,
  japanese,
  english;

  String get label {
    return switch (this) {
      AppLanguage.system => 'System',
      AppLanguage.japanese => '日本語',
      AppLanguage.english => 'English',
    };
  }

  Locale? get locale {
    return switch (this) {
      AppLanguage.system => null,
      AppLanguage.japanese => const Locale('ja'),
      AppLanguage.english => const Locale('en'),
    };
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    return AppLanguage.system;
  }

  void setLanguage(AppLanguage language) {
    state = language;
  }
}
