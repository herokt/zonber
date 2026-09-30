import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin_emails.dart';
import '../game_settings.dart';
import '../language_manager.dart';
import '../push.dart';
import 'analytics_service.dart';
import 'auth_service.dart';
import 'reminder_service.dart';

/// 이벤트·소식 푸시(FCM) — 백오피스에서 보낸 것을 받는다. 무엇을 누구에게는 lib/push.dart.
///
/// - 토픽만 쓴다: 언어 하나 + 회원/게스트 하나 + (관리자 계정이면) tester. 기기 토큰은 서버에 저장하지 않는다
/// - [sync] 가 지금 상태(언어·로그인·설정)에 맞게 구독을 고친다 — 앱 시작·돌아올 때·언어 변경·로그인/로그아웃 때 부른다.
///   구독한 목록은 기기에 적어 두고(차이만 고친다) 설정에서 끄면 전부 해제한다
/// - 권한은 주간 알림과 같은 OS 권한(ReminderService). 권한이 없어도 구독은 해 둔다 — 나중에 허락하면 바로 받는다
/// - 앱을 켜 둔 채 오면 Android 는 직접 띄우고(ReminderService.showNews) iOS 는 FCM 이 띄운다
class PushService {
  static const String _kTopics = 'push_topics'; // 기기 설정 — 지금 구독 중인 토픽

  static bool _ready = false;
  static Future<void>? _syncing;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 앱 시작 때 한 번(Firebase 초기화 뒤)
  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      final m = FirebaseMessaging.instance;
      // iOS — 앱을 켜 둔 채 와도 배너로 보이게
      await m.setForegroundNotificationPresentationOptions(alert: true, badge: false, sound: true);
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n == null || !Platform.isAndroid) return;
        ReminderService.showNews(title: n.title ?? 'ZONBER', body: n.body ?? '');
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_opened);
      final first = await m.getInitialMessage();
      if (first != null) _opened(first);
      _ready = true;
    } catch (e) {
      debugPrint('push init failed: $e');
    }
  }

  static void _opened(RemoteMessage msg) => AnalyticsService().logPushOpen(campaign: msg.data['campaign'] as String? ?? '');

  /// 구독을 지금 상태에 맞춘다(겹쳐 불러도 한 번씩 차례로)
  static Future<void> sync() {
    if (!_ready) return Future.value();
    final prev = _syncing ?? Future.value();
    final next = prev.then((_) => _sync());
    _syncing = next;
    return next;
  }

  static Future<void> _sync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final have = (prefs.getStringList(_kTopics) ?? const <String>[]).toSet();
      final want = GameSettings().pushEnabled ? _wanted() : <String>{};
      if (want.length == have.length && want.containsAll(have)) return;
      // iOS 는 APNs 토큰이 생긴 뒤에야 구독된다 — 아직이면 다음 sync 때
      if (Platform.isIOS && await FirebaseMessaging.instance.getAPNSToken() == null) return;
      final m = FirebaseMessaging.instance;
      for (final t in have.difference(want)) {
        await m.unsubscribeFromTopic(t);
      }
      for (final t in want.difference(have)) {
        await m.subscribeToTopic(t);
      }
      await prefs.setStringList(_kTopics, want.toList()..sort());
    } catch (e) {
      debugPrint('push sync failed: $e'); // 오프라인 등 — 적어 둔 목록은 그대로라 다음에 다시 한다
    }
  }

  static Set<String> _wanted() {
    final email = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();
    final member = !AuthService.isGuest;
    return PushTopics.forDevice(
      lang: LanguageManager().currentLanguage,
      member: member,
      tester: member && kAdminEmails.contains(email),
    );
  }

  /// 설정에서 켜고 끌 때. 켰는데 OS 권한이 없으면 요청한다 — 끝내 없으면 false(스위치를 되돌린다)
  static Future<bool> setEnabled(bool on) async {
    await GameSettings().setPush(on);
    if (on && !await ReminderService.allowed() && !await ReminderService.requestPermission()) {
      await GameSettings().setPush(false);
      await sync();
      return false;
    }
    await sync();
    return on;
  }
}
