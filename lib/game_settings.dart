import 'package:shared_preferences/shared_preferences.dart';

class GameSettings {
  static final GameSettings _instance = GameSettings._internal();
  factory GameSettings() => _instance;
  GameSettings._internal();

  static const double minSensitivity = 0.6;
  static const double maxSensitivity = 1.8;
  static const double defaultSensitivity = 1.0;

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  double _sensitivity = defaultSensitivity;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// 드래그 이동량 배수. 캐릭터의 speedMultiplier와 곱해져 최종 이동량이 된다.
  double get sensitivity => _sensitivity;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    _sensitivity = (prefs.getDouble('drag_sensitivity') ?? defaultSensitivity)
        .clamp(minSensitivity, maxSensitivity);
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

  Future<void> setSensitivity(double value) async {
    _sensitivity = value.clamp(minSensitivity, maxSensitivity);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('drag_sensitivity', _sensitivity);
  }
}
