import 'package:flutter/services.dart';

import 'game_settings.dart';

// ─────────────────────────────────────────────────────────────
// 진동 — 설정(진동 끔)을 한 곳에서 확인하고, 종류마다 최소 간격을 둬서 연달아 울릴 때 뭉개지지 않게 한다.
//   tick   아주 약함 — 추가 기록 · 키퍼 터치 · 탭      (120ms)
//   light  약함     — 선방 · 장착                       (60ms)
//   medium 중간     — 보상 받기 · 구매 · 레벨업 · 신기록  (80ms)
//   heavy  강함     — 피격 · 실점                       (60ms)
// ─────────────────────────────────────────────────────────────
class Haptics {
  static final Map<String, int> _last = {};

  static void _run(String key, int minGapMs, Future<void> Function() fire) {
    if (!GameSettings().vibrationEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[key] ?? 0) < minGapMs) return;
    _last[key] = now;
    fire();
  }

  static void tick() => _run('tick', 120, HapticFeedback.selectionClick);
  static void light() => _run('light', 60, HapticFeedback.lightImpact);
  static void medium() => _run('medium', 80, HapticFeedback.mediumImpact);
  static void heavy() => _run('heavy', 60, HapticFeedback.heavyImpact);

  /// 위기(에너지 1칸) — 심장박동에 맞춰 약하게
  static void heartbeat() => _run('heart', 600, HapticFeedback.lightImpact);

  /// 게임 오버 — 강하게 세 번
  static void gameOver() {
    if (!GameSettings().vibrationEnabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 240), HapticFeedback.heavyImpact);
  }
}
