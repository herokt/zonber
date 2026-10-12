import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// 새로 깐 사람 — 유료 유입 테스트(store/paid_ua_test.md)용 (2026-10-12)
///
/// - 설치 첫 24시간은 전면 광고를 띄우지 않는다([isFirstDay] → `AdManager.showInterstitialIfReady`).
///   광고 수익은 거의 없는데 첫날 전면 광고는 다음 날 재방문을 깎는다. 배너·리워드(부활)는 그대로.
/// - `engaged_user` 를 기기당 한 번 남긴다 — 설치 24시간 안에 [engagedRuns]판을 끝냄(runs_3) 또는
///   설치 24~48시간 사이에 다시 켬(day2_return). Google Ads 앱 캠페인 인앱 전환으로 가져갈 "남을 사람" 신호.
///
/// 설치 시각은 OS 가 준다(Android firstInstallTime · iOS 문서 폴더 생성 시각 — 앱 업데이트로 바뀌지 않는다).
/// 그래서 업데이트로 이 코드를 처음 받은 옛 유저는 첫날·이벤트 대상이 아니다.
/// 키는 기기 설정이라 게스트 진입·로그아웃에도 지우지 않는다(`reminder_asked` 와 같다).
class NewUser {
  static const String _kRuns = 'install_day_runs'; // 설치 첫 24시간 안에 끝낸 판 수
  static const String _kEngaged = 'engaged_logged'; // engaged_user 를 남겼나

  /// 첫날 이만큼 판을 끝내면 engaged_user(runs_3)
  static const int engagedRuns = 3;

  static DateTime? _installedAt;

  /// 설치 첫 24시간인가 — 설치 시각을 모르면(모바일 밖 · 읽기 실패) false
  static bool get isFirstDay {
    final age = _age;
    return age != null && isFirstDayAge(age);
  }

  static Duration? get _age {
    final t = _installedAt;
    return t == null ? null : DateTime.now().difference(t);
  }

  static bool isFirstDayAge(Duration age) => !age.isNegative && age < const Duration(hours: 24);

  static bool isDay2Age(Duration age) => age >= const Duration(hours: 24) && age < const Duration(hours: 48);

  /// 앱 시작 때 한 번
  static Future<void> load() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      _installedAt = (await PackageInfo.fromPlatform()).installTime;
    } catch (e) {
      debugPrint('NewUser: install time unavailable: $e');
    }
  }

  /// 앱을 켜거나 돌아올 때 — 설치 24~48시간 사이면 day2_return
  static Future<void> onOpen() async {
    final age = _age;
    if (age == null || !isDay2Age(age)) return;
    final prefs = await SharedPreferences.getInstance();
    await _logOnce(prefs, 'day2_return', age, prefs.getInt(_kRuns) ?? 0);
  }

  /// 판이 끝날 때(게임 오버 — 게스트 포함) — 첫날 [engagedRuns]판째면 runs_3
  static Future<void> onRunFinished() async {
    final age = _age;
    if (age == null || !isFirstDayAge(age)) return;
    final prefs = await SharedPreferences.getInstance();
    final runs = (prefs.getInt(_kRuns) ?? 0) + 1;
    await prefs.setInt(_kRuns, runs);
    if (runs >= engagedRuns) await _logOnce(prefs, 'runs_$engagedRuns', age, runs);
  }

  static Future<void> _logOnce(SharedPreferences prefs, String reason, Duration age, int runs) async {
    if (prefs.getBool(_kEngaged) ?? false) return;
    await prefs.setBool(_kEngaged, true);
    AnalyticsService().logEngagedUser(reason: reason, hoursSinceInstall: age.inHours, runs: runs);
  }
}
