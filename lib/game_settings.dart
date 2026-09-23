import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정 값. 테마(darkMode) 변경은 리스너(main)가 받아 앱 전체를 다시 그린다.
class GameSettings extends ChangeNotifier {
  static final GameSettings _instance = GameSettings._internal();
  factory GameSettings() => _instance;
  GameSettings._internal();


  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkMode = false;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// 다크 테마. 기본은 라이트.
  bool get darkMode => _darkMode;


  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    _darkMode = prefs.getBool('dark_mode') ?? false;
  }

  Future<void> setSound(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> setVibration(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', enabled);
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_darkMode == enabled) return;
    _darkMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', enabled);
  }
}
