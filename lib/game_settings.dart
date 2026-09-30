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
  bool _reminderEnabled = true;
  bool _pushEnabled = true;
  bool _friendPushEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// 다크 테마. 기본은 라이트.
  bool get darkMode => _darkMode;

  /// 주간 알림(일주일 동안 안 들어왔을 때만 한 번). 기본 켬 — OS 알림 권한은 따로 받는다(ReminderService)
  bool get reminderEnabled => _reminderEnabled;

  /// 이벤트·소식 푸시(백오피스에서 보내는 것). 기본 켬 — 끄면 토픽 구독을 전부 푼다(PushService)
  bool get pushEnabled => _pushEnabled;

  /// 친구 알림(요청·수락·친구가 내 기록을 넘음 — docs/FRIENDS.md). 기본 켬. 기기 문서의 friend 값으로 서버가 본다
  bool get friendPushEnabled => _friendPushEnabled;


  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    _darkMode = prefs.getBool('dark_mode') ?? false;
    _reminderEnabled = prefs.getBool('reminder_enabled') ?? true;
    _pushEnabled = prefs.getBool('push_enabled') ?? true;
    _friendPushEnabled = prefs.getBool('friend_push_enabled') ?? true;
  }

  /// 스토어 스크린샷 모드 — 소리·진동을 끄고 라이트 테마로(메모리만, 저장하지 않는다)
  void storeShotDefaults() {
    _soundEnabled = false;
    _vibrationEnabled = false;
    _darkMode = false;
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

  Future<void> setReminder(bool enabled) async {
    _reminderEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', enabled);
  }

  Future<void> setFriendPush(bool enabled) async {
    _friendPushEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('friend_push_enabled', enabled);
  }

  Future<void> setPush(bool enabled) async {
    _pushEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_enabled', enabled);
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_darkMode == enabled) return;
    _darkMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', enabled);
  }
}
