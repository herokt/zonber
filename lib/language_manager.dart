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
  /// Set listen: false when calling from event handlers (onPressed, onTap, etc.)
  static LanguageManager of(BuildContext context, {bool listen = true}) {
    return Provider.of<LanguageManager>(context, listen: listen);
  }

  Future<void> init() async {
    print('LanguageManager: init() called');
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'en';
    print('LanguageManager: Loaded language $_currentLanguage');
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    print('LanguageManager: changeLanguage($languageCode) called. Current: $_currentLanguage');
    if (_currentLanguage == languageCode) return;

    if (appTranslations.containsKey(languageCode)) {
      // Optimistic update
      _currentLanguage = languageCode;
      notifyListeners();
      print('LanguageManager: Language changed to $languageCode (Optimistic)');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language', languageCode);
        print('LanguageManager: Persisted language to prefs');
      } catch (e) {
        print('LanguageManager: Failed to save language: $e');
      }
    } else {
      print('LanguageManager: Invalid language code $languageCode');
    }
  }

  String translate(String key) {
    // Default to EN if key missing in current language
    return appTranslations[_currentLanguage]?[key] ??
        appTranslations['en']?[key] ??
        key;
  }
}
