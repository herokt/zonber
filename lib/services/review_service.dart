import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../badges.dart';
import 'analytics_service.dart';
import 'auth_service.dart';

/// 앱 리뷰 요청 — 기분 좋은 순간(신기록 · 새 뱃지)이 있었던 회원에게만, 판을 [minRuns] 번 이상 했을 때,
/// [gap] 에 한 번. 결과 화면에서 [markHappy] 로 표시해 두고, 홈으로 나갈 때 [maybeAsk] 가 띄운다
/// (다시 하기를 누른 뒤 게임 중에 창이 떠서 판을 망치지 않게).
/// OS 도 자체 한도가 있어(iOS 1년 3회) 요청해도 안 뜰 수 있다.
class ReviewPrompt {
  static const _kAskedAt = 'review_asked_at'; // 기기 설정 — 게스트 진입·로그아웃에도 지우지 않는다
  static const int minRuns = 5;
  static const Duration gap = Duration(days: 120);

  static bool _happy = false;

  static void markHappy() => _happy = true;

  /// 리뷰 창을 띄웠으면 true — 같은 때 다른 창(주간 알림 권한)을 겹쳐 띄우지 않게
  static Future<bool> maybeAsk() async {
    if (!_happy) return false;
    _happy = false;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS) || AuthService.isGuest) return false;
    try {
      final p = await SharedPreferences.getInstance();
      final last = p.getInt(_kAskedAt);
      if (last != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < gap) return false;
      final runs = (await BadgeStatsStore.load()).runs;
      if (runs < minRuns) return false;
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return false;
      await p.setInt(_kAskedAt, DateTime.now().millisecondsSinceEpoch);
      AnalyticsService().logReviewPrompt(runs: runs);
      await review.requestReview();
      return true;
    } catch (e) {
      debugPrint('review prompt failed: $e');
      return false;
    }
  }
}
