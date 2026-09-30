import 'dart:io';

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin_emails.dart';
import '../game_settings.dart';
import '../inbox.dart';
import '../language_manager.dart';
import '../push.dart';
import 'analytics_service.dart';
import 'auth_service.dart';
import 'reminder_service.dart';

/// 푸시(FCM) — 백오피스에서 보낸 이벤트·소식(토픽)과 친구 알림(기기 토큰)을 받는다. 무엇을 누구에게는 lib/push.dart.
///
/// - 이벤트·소식: 토픽만 쓴다 — 언어 하나 + 회원/게스트 하나 + (관리자 계정이면) tester
/// - 친구 알림(docs/FRIENDS.md): 회원이면 기기 토큰을 users/{uid}/devices/{기기 id} 에 둔다(본인만 읽는다).
///   로그아웃 때 [unregisterDevice] 로 지운다. 설정 › 친구 알림을 끄면 friend: false(서버가 안 보낸다)
/// - [sync] 가 지금 상태(언어·로그인·설정)에 맞게 구독을 고친다 — 앱 시작·돌아올 때·언어 변경·로그인/로그아웃 때 부른다.
///   구독한 목록은 기기에 적어 두고(차이만 고친다) 설정에서 끄면 전부 해제한다
/// - 권한은 주간 알림과 같은 OS 권한(ReminderService). 권한이 없어도 구독은 해 둔다 — 나중에 허락하면 바로 받는다
/// - 앱을 켜 둔 채 오면 Android 는 직접 띄우고(ReminderService.showNews) iOS 는 FCM 이 띄운다
class PushService {
  static const String _kTopics = 'push_topics'; // 기기 설정 — 지금 구독 중인 토픽
  static const String _kDeviceId = 'push_device_id'; // 기기 설정 — 기기 문서 id(한 번 만들고 그대로)
  static const String _kDeviceSig = 'push_device_sig'; // 마지막으로 서버에 쓴 값(uid|토큰|언어|친구) — 같으면 안 쓴다

  /// 알림(친구·이벤트 소식)을 눌러 앱이 열렸다 — main 이 알림 페이지로 간다
  static final ValueNotifier<int> openInbox = ValueNotifier(0);

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
        if (n == null) return;
        Inbox.unread.value = Inbox.unread.value + 1; // 앱을 켜 둔 채 왔다 — 종 아이콘 점
        if (!Platform.isAndroid) return;
        final friend = (msg.data['kind'] as String? ?? '').startsWith('friend_');
        ReminderService.showNews(title: n.title ?? 'ZONBER', body: n.body ?? '', friend: friend);
      });
      m.onTokenRefresh.listen((_) => sync(force: true));
      FirebaseMessaging.onMessageOpenedApp.listen(_opened);
      final first = await m.getInitialMessage();
      if (first != null) _opened(first);
      _ready = true;
    } catch (e) {
      debugPrint('push init failed: $e');
    }
  }

  static void _opened(RemoteMessage msg) {
    final kind = msg.data['kind'] as String? ?? '';
    AnalyticsService().logPushOpen(campaign: msg.data['campaign'] as String? ?? kind);
    openInbox.value++;
  }

  /// 토픽 구독 · 기기 문서를 지금 상태에 맞춘다(겹쳐 불러도 한 번씩 차례로). [force] = 토큰이 바뀌었다
  static Future<void> sync({bool force = false}) {
    if (!_ready) return Future.value();
    final prev = _syncing ?? Future.value();
    final next = prev.then((_) async {
      await _syncTopics();
      await _syncDevice(force: force);
    });
    _syncing = next;
    return next;
  }

  static Future<void> _syncTopics() async {
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

  /// 친구 알림용 기기 문서 — 회원만. 바뀐 게 없으면 쓰지 않는다
  static Future<void> _syncDevice({bool force = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || AuthService.isGuest) return; // 게스트는 아무것도 저장하지 않는다(로그아웃 때 이미 지웠다)
      if (Platform.isIOS && await FirebaseMessaging.instance.getAPNSToken() == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final lang = LanguageManager().currentLanguage;
      final friend = GameSettings().friendPushEnabled;
      final sig = '${user.uid}|$token|$lang|$friend';
      if (!force && prefs.getString(_kDeviceSig) == sig) return;
      await _deviceRef(user.uid, prefs).set({
        'token': token,
        'lang': lang,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'friend': friend,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await prefs.setString(_kDeviceSig, sig);
    } catch (e) {
      debugPrint('push device sync failed: $e');
    }
  }

  static DocumentReference<Map<String, dynamic>> _deviceRef(String uid, SharedPreferences prefs) {
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(20, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join();
      prefs.setString(_kDeviceId, id);
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').doc(id);
  }

  /// 로그아웃·탈퇴 직전(아직 로그인한 동안) — 이 기기로 그 계정의 친구 알림이 오지 않게 기기 문서를 지운다
  static Future<void> unregisterDevice() async {
    if (!_ready) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      await _deviceRef(user.uid, prefs).delete().timeout(const Duration(seconds: 2));
      await prefs.remove(_kDeviceSig);
    } catch (e) {
      debugPrint('push device remove failed: $e');
    }
  }

  /// 설정 › 친구 알림
  static Future<bool> setFriendEnabled(bool on) async {
    await GameSettings().setFriendPush(on);
    if (on && !await ReminderService.allowed() && !await ReminderService.requestPermission()) {
      await GameSettings().setFriendPush(false);
      await sync();
      return false;
    }
    await sync();
    return on;
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
