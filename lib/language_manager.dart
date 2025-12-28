import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';

class LanguageManager extends ChangeNotifier {
  static final LanguageManager _instance = LanguageManager._internal();
  factory LanguageManager() => _instance;
  LanguageManager._internal();

  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  /// Helper to access via Provider context to ensure rebuilds on change.
  static LanguageManager of(BuildContext context) {
    return Provider.of<LanguageManager>(context, listen: true);
  }

  Future<void> init() async {
    // Load from GameSettings (or prefs directly if GameSettings doesn't support it yet)
    // For now, let's just use GameSettings to persist it.
    // We will update GameSettings to support language first.
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;

    if (appTranslations.containsKey(languageCode)) {
      _currentLanguage = languageCode;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', languageCode);

      notifyListeners();
    }
  }

  String translate(String key) {
    // Default to EN if key missing in current language
    return appTranslations[_currentLanguage]?[key] ??
        appTranslations['en']?[key] ??
        key;
  }
}
