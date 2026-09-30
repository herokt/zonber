import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../game_settings.dart';
import '../language_manager.dart';
import '../promotions.dart';
import 'analytics_service.dart';
import 'auth_service.dart';

/// 주간 알림 — **일주일 동안 안 들어온 사람에게만** 한 번, 그 뒤로도 안 오면 일주일에 한 번.
///
/// 앱을 켜거나 돌아올 때마다 [reschedule] 이 예약을 "지금부터 7일 뒤"로 다시 건다 →
/// 일주일 안에 한 번이라도 들어오는 사람은 알림을 받지 않는다. 서버·푸시 없이 기기 안에서만 돈다(로컬 알림).
///
/// - 문구: 회원이고 주간 선물(`weekly_gift`)이 진행 중이면 "주간 선물이 도착했어요 — 코인 N",
///   아니면 "존이 기다려요". 예약할 때의 언어로 쓴다(언어를 바꾸면 다음에 켤 때 바뀐다)
/// - 권한: 첫 판을 마치고 홈으로 나갈 때 한 번 묻는다([maybeAsk]) — 앱을 켜자마자 묻지 않는다
/// - 끄기: 프로필 › 설정 › 주간 알림(GameSettings.reminderEnabled)
/// - 반복 예약(periodicallyShow)을 쓰지 않는다 — Android 플러그인이 예약하는 순간과 같은 1ms 안에 처리되면
///   첫 알림 시각을 "지금"으로 잡아, 앱을 켜자마자 주간 알림이 뜨는 일이 있었다(2026-09-30 기기 알람 기록으로 확인).
///   대신 날짜를 박은 한 번짜리 알림을 7·14·21·28일 뒤로 4개 건다(id 7001 · 7010~7012) → 한 달 넘게 안 오면 더 보내지 않는다
/// - 다시 예약하면 이전 것을 모두 지우고 건다(쌓이지 않는다)
/// - 앱을 켜면 알림 트레이의 이 앱 알림을 비운다([clearShown]) — 지난 알림이 쌓여 있다 한꺼번에 보이지 않게
class ReminderService {
  static const int _id = 7001;
  static const List<int> _ids = [_id, 7010, 7011, 7012]; // 1·2·3·4주 뒤
  static const String _channelId = 'weekly_reminder';

  /// 이벤트·소식 푸시(PushService) 채널 — 서버 함수(functions/index.js)의 android.notification.channelId 와 같다
  static const String newsChannelId = 'news';

  /// 친구 알림 채널 — functions/notify.js 의 CHANNEL 과 같다
  static const String friendsChannelId = 'friends';
  static const String _kAsked = 'reminder_asked'; // 기기 설정 — 권한을 물었나(게스트 진입·로그아웃에도 지우지 않는다)

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 앱 시작 때 한 번. 알림을 눌러 앱이 열렸으면 분석에 남긴다
  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          // 권한은 여기서 묻지 않는다 — maybeAsk 가 좋은 때에 묻는다
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => AnalyticsService().logReminderOpen(),
      );
      _ready = true;
      // 푸시 채널 — 앱이 꺼져 있을 때 FCM 이 이 채널로 띄운다(AndroidManifest default_notification_channel_id)
      final lm = LanguageManager();
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
            AndroidNotificationChannel(newsChannelId, lm.translate('push_setting'), description: lm.translate('push_setting_desc'), importance: Importance.high),
          );
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
            AndroidNotificationChannel(friendsChannelId, lm.translate('friend_push_setting'),
                description: lm.translate('friend_push_setting_desc'), importance: Importance.high),
          );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) AnalyticsService().logReminderOpen();
    } catch (e) {
      debugPrint('reminder init failed: $e');
    }
  }

  /// 알림을 보낼 수 있나(OS 권한) — 주간 알림·푸시가 같은 권한을 쓴다
  static Future<bool> allowed() => _ready ? _allowed() : Future.value(false);

  /// OS 권한 요청 창 — 허락했으면 true
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final granted = await _request();
    AnalyticsService().logReminderPermission(granted: granted);
    return granted;
  }

  static Future<bool> _allowed() async {
    if (Platform.isAndroid) {
      return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled() ?? false;
    }
    final p = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
    return p?.isEnabled ?? false;
  }

  /// OS 권한 요청 창 — 허락했으면 true
  static Future<bool> _request() async {
    if (Platform.isAndroid) {
      return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
  }

  /// 예약을 "지금부터 7일 뒤 · 14일 · 21일 · 28일 뒤"로 다시 건다. 꺼 두었거나 권한이 없으면 지우기만 한다
  static Future<void> reschedule() async {
    if (!_ready) return;
    try {
      await _cancelWeekly();
      if (!GameSettings().reminderEnabled || !await _allowed()) return;
      final lm = LanguageManager();
      final gift = AuthService.isGuest ? null : await _weeklyGiftCoins();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          lm.translate('reminder_setting'),
          channelDescription: lm.translate('reminder_setting_desc'),
        ),
        iOS: const DarwinNotificationDetails(),
      );
      final now = tz.TZDateTime.now(tz.UTC);
      for (var i = 0; i < _ids.length; i++) {
        await _plugin.zonedSchedule(
          id: _ids[i],
          scheduledDate: now.add(Duration(days: 7 * (i + 1))),
          title: lm.translate(gift != null ? 'reminder_gift_title' : 'reminder_title'),
          body: gift != null ? lm.translate('reminder_gift_body').replaceAll('{n}', '$gift') : lm.translate('reminder_body'),
          notificationDetails: details,
          // 정확한 시각은 필요 없다(정확한 알람 권한을 받지 않는다) — 일주일 뒤 즈음이면 된다
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('reminder schedule failed: $e');
    }
  }

  static Future<void> _cancelWeekly() async {
    for (final id in _ids) {
      await _plugin.cancel(id: id);
    }
  }

  /// 알림 트레이에 떠 있는 이 앱 알림(주간 알림 · 푸시)을 모두 치운다 — 앱을 켜거나 돌아올 때.
  /// 예약도 함께 지워지므로 부른 뒤에는 [reschedule] 을 부른다(main 이 둘을 이어 부른다)
  static Future<void> clearShown() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('clear notifications failed: $e');
    }
  }

  /// 진행 중인 주간 선물의 코인 — 없으면 null
  static Future<int?> _weeklyGiftCoins() async {
    for (final p in await PromoService.load()) {
      if (p.id == 'weekly_gift' && p.coins > 0) return p.coins;
    }
    return null;
  }

  /// 첫 판을 마치고 홈으로 나갈 때 — 권한을 아직 안 물었으면 한 번 묻고 예약한다. 물었으면 true
  static Future<bool> maybeAsk() async {
    if (!_ready || !GameSettings().reminderEnabled) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAsked) ?? false) return false;
      await prefs.setBool(_kAsked, true);
      if (await _allowed()) {
        await reschedule(); // Android 12 이하 · 이미 허락한 기기는 창 없이 예약만
        return false;
      }
      final granted = await _request();
      AnalyticsService().logReminderPermission(granted: granted);
      if (granted) await reschedule();
      return true;
    } catch (e) {
      debugPrint('reminder ask failed: $e');
      return false;
    }
  }

  /// 설정에서 켜고 끌 때. 켰는데 권한이 없으면 요청한다 — 끝내 권한이 없으면 false(스위치를 되돌린다)
  static Future<bool> setEnabled(bool on) async {
    await GameSettings().setReminder(on);
    if (!_ready) return on;
    if (!on) {
      await _cancelWeekly();
      return false;
    }
    if (!await _allowed()) {
      final granted = await _request();
      AnalyticsService().logReminderPermission(granted: granted);
      if (!granted) {
        await GameSettings().setReminder(false);
        return false;
      }
    }
    await reschedule();
    return true;
  }
}
