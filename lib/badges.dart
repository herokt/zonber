import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievement_manager.dart';
import 'services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 뱃지 — 명패를 대신하는 수집 목표(2026-09-22). 한 번 얻으면 영구.
//  - 얻은 뱃지 키는 AchievementManager 가 저장한다(prefs + users/{uid}.achievements) — 옛 업적 키(ach_*)를 그대로 잇는다.
//  - 누적 기록(판 수·플레이 시간·신기록 횟수·미션 올클리어 일수)은 BadgeStats(prefs + users/{uid}.badgeStats).
//  - 판이 끝날 때(Badges.onRun) · 랭킹 순위를 알았을 때(onRank) · 구매(onCollection) · 출석/미션(onDaily)에 검사한다.
// 등급(tier): 1 브론즈 · 2 실버 · 3 골드 · 4 레전드. 대표 뱃지 = 가장 높은 등급 중 목록 뒤쪽.
// ─────────────────────────────────────────────────────────────

enum BadgeCategory { survival, stage, skill, career, ranking, collection, daily, special }

/// 뱃지를 검사할 때 넘기는 값 — 모르는 값은 0
class BadgeContext {
  final int stage; // 1~3 (판이 아닐 때 0)
  final double time;
  final String statKey;
  final int statCount;
  final int revive;
  final bool newBest;
  final int worldRank; // 이번 기록의 세계 순위(0 = 모름)
  final int countryRank;
  final BadgeStats stats;
  final int ownedItems;
  final int ownedCharacters;
  final int attendanceStreak;
  final Map<String, double> bestTimes; // worldId → 최고 기록
  const BadgeContext({
    this.stage = 0,
    this.time = 0,
    this.statKey = '',
    this.statCount = 0,
    this.revive = 0,
    this.newBest = false,
    this.worldRank = 0,
    this.countryRank = 0,
    required this.stats,
    this.ownedItems = 0,
    this.ownedCharacters = 0,
    this.attendanceStreak = 0,
    this.bestTimes = const {},
  });
}

class BadgeDef {
  final String key;
  final BadgeCategory category;
  final int tier;
  final IconData icon;
  final bool Function(BadgeContext c) check;
  const BadgeDef(this.key, this.category, this.tier, this.icon, this.check);

  String get nameKey => key; // 번역: 이름 = key, 설명 = key_desc
  String get descKey => '${key}_desc';

  Color get color => tierColor(tier);

  static Color tierColor(int tier) => switch (tier) {
        1 => const Color(0xFFCD8B4E), // 브론즈
        2 => const Color(0xFF9FB2C8), // 실버
        3 => const Color(0xFFF2B928), // 골드
        _ => const Color(0xFFB36BFF), // 레전드
      };
}

/// 누적 기록 — 뱃지 조건용
class BadgeStats {
  int runs;
  double playTime;
  int newBests;
  int allClearDays;
  BadgeStats({this.runs = 0, this.playTime = 0, this.newBests = 0, this.allClearDays = 0});

  Map<String, Object> toJson() => {'runs': runs, 'playTime': playTime, 'newBests': newBests, 'allClearDays': allClearDays};
  static BadgeStats fromJson(Map m) => BadgeStats(
        runs: (m['runs'] as num?)?.toInt() ?? 0,
        playTime: (m['playTime'] as num?)?.toDouble() ?? 0,
        newBests: (m['newBests'] as num?)?.toInt() ?? 0,
        allClearDays: (m['allClearDays'] as num?)?.toInt() ?? 0,
      );
}

bool _stageTime(BadgeContext c, int stage, double t) => c.stage == stage && c.time >= t;
bool _skill(BadgeContext c, String stat, int n) => c.statKey == stat && c.statCount >= n;
bool _rankIn(int r, int n) => r > 0 && r <= n;

class Badges {
  static final List<BadgeDef> all = [
    // ── 생존(어느 스테이지든 한 판) — 옛 업적 키 그대로 ──
    BadgeDef('ach_survivor', BadgeCategory.survival, 1, Icons.shield_outlined, (c) => c.time >= 60),
    BadgeDef('ach_veteran', BadgeCategory.survival, 2, Icons.shield, (c) => c.time >= 120),
    BadgeDef('ach_elite', BadgeCategory.survival, 3, Icons.bolt, (c) => c.time >= 180),
    BadgeDef('ach_master', BadgeCategory.survival, 3, Icons.whatshot, (c) => c.time >= 240),
    BadgeDef('ach_legend', BadgeCategory.survival, 4, Icons.auto_awesome, (c) => c.time >= 300),
    // ── 스테이지별 ──
    BadgeDef('b_s1_30', BadgeCategory.stage, 1, Icons.rocket_launch_outlined, (c) => _stageTime(c, 1, 30)),
    BadgeDef('b_s1_90', BadgeCategory.stage, 2, Icons.rocket_launch, (c) => _stageTime(c, 1, 90)),
    BadgeDef('b_s1_180', BadgeCategory.stage, 3, Icons.public, (c) => _stageTime(c, 1, 180)),
    BadgeDef('b_s2_30', BadgeCategory.stage, 1, Icons.sports_handball_outlined, (c) => _stageTime(c, 2, 30)),
    BadgeDef('b_s2_75', BadgeCategory.stage, 2, Icons.sports_handball, (c) => _stageTime(c, 2, 75)),
    BadgeDef('b_s2_150', BadgeCategory.stage, 3, Icons.sports_volleyball, (c) => _stageTime(c, 2, 150)),
    BadgeDef('b_s3_30', BadgeCategory.stage, 1, Icons.sports_soccer_outlined, (c) => _stageTime(c, 3, 30)),
    BadgeDef('b_s3_75', BadgeCategory.stage, 2, Icons.sports_soccer, (c) => _stageTime(c, 3, 75)),
    BadgeDef('b_s3_150', BadgeCategory.stage, 3, Icons.sports, (c) => _stageTime(c, 3, 150)),
    // ── 기술(한 판의 추가 기록) ──
    BadgeDef('b_graze_15', BadgeCategory.skill, 1, Icons.blur_on, (c) => _skill(c, 'graze', 15)),
    BadgeDef('b_graze_40', BadgeCategory.skill, 2, Icons.blur_circular, (c) => _skill(c, 'graze', 40)),
    BadgeDef('b_graze_80', BadgeCategory.skill, 3, Icons.flare, (c) => _skill(c, 'graze', 80)),
    BadgeDef('b_close_5', BadgeCategory.skill, 1, Icons.directions_run, (c) => _skill(c, 'close_dodge', 5)),
    BadgeDef('b_close_15', BadgeCategory.skill, 2, Icons.speed, (c) => _skill(c, 'close_dodge', 15)),
    BadgeDef('b_close_30', BadgeCategory.skill, 3, Icons.electric_bolt, (c) => _skill(c, 'close_dodge', 30)),
    BadgeDef('b_streak_3', BadgeCategory.skill, 1, Icons.back_hand_outlined, (c) => _skill(c, 'save_streak', 3)),
    BadgeDef('b_streak_8', BadgeCategory.skill, 2, Icons.back_hand, (c) => _skill(c, 'save_streak', 8)),
    BadgeDef('b_streak_15', BadgeCategory.skill, 3, Icons.front_hand, (c) => _skill(c, 'save_streak', 15)),
    // ── 경력(누적) ──
    BadgeDef('b_runs_10', BadgeCategory.career, 1, Icons.replay, (c) => c.stats.runs >= 10),
    BadgeDef('b_runs_100', BadgeCategory.career, 2, Icons.repeat, (c) => c.stats.runs >= 100),
    BadgeDef('b_runs_500', BadgeCategory.career, 3, Icons.all_inclusive, (c) => c.stats.runs >= 500),
    BadgeDef('b_runs_1000', BadgeCategory.career, 4, Icons.military_tech, (c) => c.stats.runs >= 1000),
    BadgeDef('b_time_1h', BadgeCategory.career, 2, Icons.schedule, (c) => c.stats.playTime >= 3600),
    BadgeDef('b_time_10h', BadgeCategory.career, 3, Icons.hourglass_full, (c) => c.stats.playTime >= 36000),
    // ── 랭킹(어느 스테이지든, 기록을 낸 순간의 순위) — 옛 업적 키 포함 ──
    BadgeDef('b_nat_top10', BadgeCategory.ranking, 2, Icons.flag_outlined, (c) => _rankIn(c.countryRank, 10)),
    BadgeDef('ach_nat_champion', BadgeCategory.ranking, 3, Icons.flag, (c) => c.countryRank == 1),
    BadgeDef('b_world_top100', BadgeCategory.ranking, 2, Icons.public_outlined, (c) => _rankIn(c.worldRank, 100)),
    BadgeDef('ach_glob_top30', BadgeCategory.ranking, 3, Icons.language, (c) => _rankIn(c.worldRank, 30)),
    BadgeDef('ach_glob_top10', BadgeCategory.ranking, 3, Icons.workspace_premium, (c) => _rankIn(c.worldRank, 10)),
    BadgeDef('ach_glob_champion', BadgeCategory.ranking, 4, Icons.emoji_events, (c) => c.worldRank == 1),
    // ── 수집 ──
    BadgeDef('b_items_5', BadgeCategory.collection, 1, Icons.shopping_bag_outlined, (c) => c.ownedItems >= 5),
    BadgeDef('b_items_15', BadgeCategory.collection, 2, Icons.shopping_bag, (c) => c.ownedItems >= 15),
    BadgeDef('b_items_30', BadgeCategory.collection, 3, Icons.inventory_2, (c) => c.ownedItems >= 30),
    BadgeDef('b_chars_all', BadgeCategory.collection, 3, Icons.groups, (c) => c.ownedCharacters >= 6),
    // ── 출석 · 미션 ──
    BadgeDef('b_att_7', BadgeCategory.daily, 2, Icons.event_available, (c) => c.attendanceStreak >= 7),
    BadgeDef('b_att_30', BadgeCategory.daily, 3, Icons.calendar_month, (c) => c.attendanceStreak >= 30),
    BadgeDef('b_mission_1', BadgeCategory.daily, 1, Icons.task_alt, (c) => c.stats.allClearDays >= 1),
    BadgeDef('b_mission_10', BadgeCategory.daily, 2, Icons.fact_check, (c) => c.stats.allClearDays >= 10),
    // ── 특별 ──
    BadgeDef('b_comeback', BadgeCategory.special, 2, Icons.restart_alt, (c) => c.revive > 0 && c.newBest),
    BadgeDef('b_newbest_10', BadgeCategory.special, 2, Icons.trending_up, (c) => c.stats.newBests >= 10),
    BadgeDef('b_all_stages_60', BadgeCategory.special, 3, Icons.diamond,
        (c) => ['cyber', 'dodgeball', 'keeper'].every((w) => (c.bestTimes[w] ?? 0) >= 60)),
  ];

  static final Map<String, BadgeDef> _byKey = {for (final b in all) b.key: b};
  static BadgeDef? byKey(String key) => _byKey[key];

  /// 대표 뱃지 — 가장 높은 등급, 같으면 목록 뒤쪽(더 어려운 것)
  static BadgeDef? best(Iterable<String> keys) {
    BadgeDef? top;
    for (final b in all) {
      if (keys.contains(b.key) && (top == null || b.tier >= top.tier)) top = b;
    }
    return top;
  }

  /// 새로 얻은 뱃지(판 결과 화면에 띄운다) — 결과 화면이 가져가면 비운다
  static final ValueNotifier<List<BadgeDef>> fresh = ValueNotifier(const []);

  /// 옛 명패(users.plates / 로컬 world_plates) → 같은 등급의 랭킹 뱃지로 옮긴다(한 번 얻은 건 영구라 그대로 준다)
  static Future<void> migratePlates(Object? plates) async {
    if (plates is! Map) return;
    final keys = <String>{};
    for (final v in plates.values) {
      if (v is! Map) continue;
      final rank = (v['rank'] as num?)?.toInt() ?? 0;
      if (rank <= 0) continue;
      if (v['scope'] == 'country') {
        if (rank <= 10) keys.add('b_nat_top10');
        if (rank == 1) keys.add('ach_nat_champion');
      } else {
        if (rank <= 100) keys.add('b_world_top100');
        if (rank <= 30) keys.add('ach_glob_top30');
        if (rank <= 10) keys.add('ach_glob_top10');
        if (rank == 1) keys.add('ach_glob_champion');
      }
    }
    if (keys.isEmpty) return;
    final owned = (await AchievementManager.getMine()).toSet();
    final add = keys.difference(owned).toList();
    if (add.isNotEmpty) await AchievementManager.unlock(add);
  }

  /// 조건을 만족하는데 아직 없는 뱃지를 저장하고 돌려준다
  static Future<List<BadgeDef>> evaluate(BadgeContext c) async {
    final owned = (await AchievementManager.getMine()).toSet();
    final got = [for (final b in all) if (!owned.contains(b.key) && b.check(c)) b];
    if (got.isNotEmpty) {
      await AchievementManager.unlock(got.map((b) => b.key).toList());
      fresh.value = [...fresh.value, ...got];
    }
    return got;
  }
}

/// 누적 기록 저장(prefs + 회원은 users/{uid}.badgeStats). 로그인하면 큰 값끼리 합친다
class BadgeStatsStore {
  static const _key = 'badge_stats';

  static Future<BadgeStats> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      return BadgeStats.fromJson(jsonDecode(p.getString(_key) ?? '{}') as Map);
    } catch (_) {
      return BadgeStats();
    }
  }

  static Future<void> save(BadgeStats s) async {
    if (AuthService.isGuest) return; // 게스트는 아무것도 남기지 않는다
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(s.toJson()));
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'badgeStats': s.toJson()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('BadgeStats sync failed: $e');
    }
  }

  static Future<void> mergeFromRemote(Map<String, dynamic> userDoc) async {
    final r = userDoc['badgeStats'];
    final local = await load();
    if (r is Map) {
      final remote = BadgeStats.fromJson(r);
      local
        ..runs = max(local.runs, remote.runs)
        ..playTime = max(local.playTime, remote.playTime)
        ..newBests = max(local.newBests, remote.newBests)
        ..allClearDays = max(local.allClearDays, remote.allClearDays);
    }
    await save(local);
  }

  static Future<void> clearLocal() async => (await SharedPreferences.getInstance()).remove(_key);
}
