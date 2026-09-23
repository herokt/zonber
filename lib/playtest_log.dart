import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 플레이 로그 — 밸런스 확인용. 판이 끝날 때마다 한 줄씩 이 기기에 쌓는다(최근 300판).
// 통계 화면의 "플레이 기록 복사" 로 CSV 를 클립보드에 담아 전달한다. 서버로 보내지 않는다.
// logcat 에도 'ZONBER_RUN {...}' 으로 찍는다(adb logcat -s flutter).
// ─────────────────────────────────────────────────────────────
class PlaytestLog {
  static const _key = 'playtest_runs';
  static const _max = 300;
  static const columns = ['date', 'stage', 'time', 'level', 'stat', 'statCount', 'coins', 'bonus', 'revive', 'character'];

  static Future<void> add(Map<String, Object?> run) async {
    if (AuthService.isGuest) return;
    final line = jsonEncode({'date': DateTime.now().toIso8601String().substring(0, 19), ...run});
    debugPrint('ZONBER_RUN $line');
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? <String>[];
      list.add(line);
      if (list.length > _max) list.removeRange(0, list.length - _max);
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).length;
  }

  /// CSV(머리글 + 한 판에 한 줄)
  static Future<String> exportCsv() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = <String>[columns.join(',')];
    for (final line in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final m = jsonDecode(line) as Map<String, dynamic>;
        rows.add(columns.map((c) => '${m[c] ?? ''}').join(','));
      } catch (_) {}
    }
    return rows.join('\n');
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
