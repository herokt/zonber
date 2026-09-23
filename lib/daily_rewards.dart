import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'badges.dart';
import 'coin_store.dart';
import 'services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 일일 미션 · 출석 보상 — 코인을 모을 반복 목표. docs/SHOP.md
//  - 미션: 매일(기기 자정 기준) 풀에서 3개. 날짜로 고정 난수라 하루 동안 같은 미션. 다 깨면 보너스.
//  - 출석: 하루 한 번 받기. 이어서 받으면 1→7일차로 보상이 커지고, 하루라도 빠지면 1일차부터.
//  - 진행은 이 기기에 저장하고, 회원이면 users/{uid}.daily 에도 올린다 — 다른 기기·재설치 후 로그인하면 이어진다(mergeFromRemote).
// ─────────────────────────────────────────────────────────────

enum MissionKind { runs, totalTime, stageTime, stat, allStages }

class DailyMission {
  final String id;
  final MissionKind kind;
  final int target;
  /// 스테이지 번호(1~3) — stageTime · stat 만
  final int stage;
  final int reward;
  const DailyMission(this.id, this.kind, this.target, this.reward, {this.stage = 0});
}

class MissionState {
  final DailyMission mission;
  final int progress;
  final bool claimed;
  const MissionState(this.mission, this.progress, this.claimed);
  bool get done => progress >= mission.target;
  bool get claimable => done && !claimed;
}

class DailyRewards {
  static const List<DailyMission> pool = [
    DailyMission('runs3', MissionKind.runs, 3, 20),
    DailyMission('runs5', MissionKind.runs, 5, 30),
    DailyMission('time180', MissionKind.totalTime, 180, 30),
    DailyMission('s1_30', MissionKind.stageTime, 30, 25, stage: 1),
    DailyMission('s2_25', MissionKind.stageTime, 25, 25, stage: 2),
    DailyMission('s3_20', MissionKind.stageTime, 20, 25, stage: 3),
    DailyMission('stat1', MissionKind.stat, 8, 30, stage: 1),
    DailyMission('stat2', MissionKind.stat, 5, 30, stage: 2),
    DailyMission('stat3', MissionKind.stat, 3, 30, stage: 3),
    DailyMission('all3', MissionKind.allStages, 3, 30),
  ];
  static const int allClearBonus = 30;
  static const List<int> attendanceRewards = [10, 15, 20, 25, 30, 40, 60];

  static const _kDate = 'daily_date', _kProgress = 'daily_progress', _kClaimed = 'daily_claimed', _kBonus = 'daily_bonus';
  static const _kAttLast = 'att_last', _kAttStreak = 'att_streak';

  /// 받을 수 있는 보상 개수(미션·보너스·출석) — 홈 카드의 빨간 점
  static final ValueNotifier<int> claimable = ValueNotifier(0);

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String get _today => _day(DateTime.now());
  static String get _yesterday => _day(DateTime.now().subtract(const Duration(days: 1)));

  /// 오늘의 미션 3개 — 날짜로 고정 난수. 같은 종류·같은 스테이지는 하루에 하나씩
  static List<DailyMission> todays() {
    final seed = int.parse(_today.replaceAll('-', ''));
    final list = [...pool]..shuffle(Random(seed));
    final out = <DailyMission>[];
    for (final m in list) {
      if (out.any((o) => o.kind == m.kind || (m.stage != 0 && o.stage == m.stage))) continue;
      out.add(m);
      if (out.length == 3) break;
    }
    return out;
  }

  static Future<SharedPreferences> _prefs() async {
    final p = await SharedPreferences.getInstance();
    // 날짜가 바뀌면 미션 진행을 새로 시작
    if (p.getString(_kDate) != _today) {
      await p.setString(_kDate, _today);
      await p.remove(_kProgress);
      await p.remove(_kClaimed);
      await p.remove(_kBonus);
    }
    return p;
  }

  static Map<String, int> _progress(SharedPreferences p) {
    try {
      return (jsonDecode(p.getString(_kProgress) ?? '{}') as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<List<MissionState>> missions() async {
    final p = await _prefs();
    final prog = _progress(p);
    final claimed = p.getStringList(_kClaimed) ?? const [];
    return [
      for (final m in todays())
        MissionState(m, min(prog[m.id] ?? 0, m.target), claimed.contains(m.id)),
    ];
  }

  static Future<bool> bonusClaimed() async => (await _prefs()).getBool(_kBonus) ?? false;

  /// 한 판이 끝났다. 부활로 이어진 판은 [continued] — 판 수·스테이지 도장은 세지 않고 늘어난 시간·기록만 더한다
  static Future<void> recordRun({required int stage, required double time, required double addedTime, required int addedStat, required bool continued}) async {
    if (AuthService.isGuest) return; // 게스트는 미션을 하지 않는다
    final p = await _prefs();
    final prog = _progress(p);
    void bump(String id, int v) => prog[id] = (prog[id] ?? 0) + v;
    void best(String id, int v) => prog[id] = max(prog[id] ?? 0, v);
    for (final m in todays()) {
      switch (m.kind) {
        case MissionKind.runs:
          if (!continued) bump(m.id, 1);
        case MissionKind.totalTime:
          bump(m.id, addedTime.floor());
        case MissionKind.stageTime:
          if (m.stage == stage) best(m.id, time.floor());
        case MissionKind.stat:
          if (m.stage == stage) bump(m.id, addedStat);
        case MissionKind.allStages:
          // 스테이지 도장 — 비트로 모은다(1·2·3 → 1·2·4), 진행은 찍은 개수
          final bits = (prog['${m.id}_bits'] ?? 0) | (1 << (stage - 1));
          prog['${m.id}_bits'] = bits;
          prog[m.id] = [1, 2, 4].where((b) => bits & b != 0).length;
      }
    }
    await p.setString(_kProgress, jsonEncode(prog));
    await refresh();
    await _syncRemote();
  }

  static Future<int> claimMission(String id) async {
    if (AuthService.isGuest) return 0;
    final p = await _prefs();
    final st = (await missions()).firstWhere((s) => s.mission.id == id);
    if (!st.claimable) return 0;
    await p.setStringList(_kClaimed, [...(p.getStringList(_kClaimed) ?? const []), id]);
    await CoinStore.add(st.mission.reward);
    await refresh();
    await _syncRemote();
    return st.mission.reward;
  }

  static Future<int> claimBonus() async {
    if (AuthService.isGuest) return 0;
    final p = await _prefs();
    final ms = await missions();
    if ((p.getBool(_kBonus) ?? false) || !ms.every((s) => s.claimed)) return 0;
    await p.setBool(_kBonus, true);
    await CoinStore.add(allClearBonus);
    final stats = await BadgeStatsStore.load();
    stats.allClearDays++;
    await BadgeStatsStore.save(stats);
    await Badges.evaluate(BadgeContext(stats: stats));
    await refresh();
    await _syncRemote();
    return allClearBonus;
  }

  // ── 출석 ──

  /// (오늘 받을 차례의 일차 1~7, 오늘 이미 받았는지, 지금까지 이어진 일수)
  static Future<({int day, bool claimedToday, int streak})> attendance() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getString(_kAttLast);
    final streak = p.getInt(_kAttStreak) ?? 0;
    if (last == _today) return (day: ((streak - 1) % 7) + 1, claimedToday: true, streak: streak);
    final continues = last == _yesterday;
    final next = continues ? streak + 1 : 1;
    return (day: ((next - 1) % 7) + 1, claimedToday: false, streak: continues ? streak : 0);
  }

  static Future<int> claimAttendance() async {
    if (AuthService.isGuest) return 0;
    final a = await attendance();
    if (a.claimedToday) return 0;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAttLast, _today);
    await p.setInt(_kAttStreak, a.streak + 1);
    final reward = attendanceRewards[a.day - 1];
    await CoinStore.add(reward);
    await Badges.evaluate(BadgeContext(stats: await BadgeStatsStore.load(), attendanceStreak: a.streak + 1));
    await refresh();
    await _syncRemote();
    return reward;
  }

  // ── 계정 동기화(회원만) ──

  static Future<void> _syncRemote() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      final p = await _prefs();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'daily': {
          'date': p.getString(_kDate),
          'progress': _progress(p),
          'claimed': p.getStringList(_kClaimed) ?? const <String>[],
          'bonus': p.getBool(_kBonus) ?? false,
          'attLast': p.getString(_kAttLast),
          'attStreak': p.getInt(_kAttStreak) ?? 0,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DailyRewards sync failed: $e');
    }
  }

  /// 로그인 시 — 계정에 저장된 진행과 이 기기 진행을 합친다(오늘 것만, 큰 값 · 합집합). 출석은 더 최근 것
  static Future<void> mergeFromRemote(Map<String, dynamic> userDoc) async {
    final d = userDoc['daily'];
    if (d is! Map) {
      await _syncRemote();
      return;
    }
    final p = await _prefs();
    if (d['date'] == _today) {
      final prog = _progress(p);
      final rp = d['progress'];
      if (rp is Map) {
        rp.forEach((k, v) {
          if (k is String && v is num) prog[k] = max(prog[k] ?? 0, v.toInt());
        });
      }
      await p.setString(_kProgress, jsonEncode(prog));
      final claimed = {...(p.getStringList(_kClaimed) ?? const <String>[]), ...((d['claimed'] as List?)?.whereType<String>() ?? const <String>[])};
      await p.setStringList(_kClaimed, claimed.toList());
      if (d['bonus'] == true) await p.setBool(_kBonus, true);
    }
    final rLast = d['attLast'] as String?, lLast = p.getString(_kAttLast);
    final rStreak = (d['attStreak'] as num?)?.toInt() ?? 0, lStreak = p.getInt(_kAttStreak) ?? 0;
    if (rLast != null && (lLast == null || rLast.compareTo(lLast) > 0 || (rLast == lLast && rStreak > lStreak))) {
      await p.setString(_kAttLast, rLast);
      await p.setInt(_kAttStreak, rStreak);
    }
    await _syncRemote();
    await refresh();
  }

  /// 로그아웃·게스트 진입 — 이 기기의 미션·출석 진행을 지운다
  static Future<void> clearLocal() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [_kDate, _kProgress, _kClaimed, _kBonus, _kAttLast, _kAttStreak]) {
      await p.remove(k);
    }
    claimable.value = 0;
  }

  /// 받을 수 있는 보상 개수를 다시 센다(홈 진입·판 종료·받기 뒤)
  static Future<void> refresh() async {
    if (AuthService.isGuest) {
      claimable.value = 0;
      return;
    }
    final ms = await missions();
    int n = ms.where((s) => s.claimable).length;
    if (ms.every((s) => s.claimed) && !await bonusClaimed()) n++;
    if (!(await attendance()).claimedToday) n++;
    claimable.value = n;
  }
}
