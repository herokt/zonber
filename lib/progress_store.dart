import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// 월드별 진행 데이터 — 최고 기록 · 순위 캐시 · 명패
//
// SharedPreferences(로컬) + Firestore users/{uid}(원격) 이중 저장.
// 게스트도 로컬은 쌓인다(월드 해금에 필요). 원격은 로그인 유저만.
// ─────────────────────────────────────────────────────────────

/// Hall of Fame 명패 — 한 번 도달한 최고 순위. 밀려나도 사라지지 않는다.
class PlateData {
  final String worldId;
  final int rank;
  final int total;
  final double survivalTime;
  final DateTime date;
  /// 'world' = 세계 TOP 100, 'country' = 국가 TOP 10
  final String scope;

  const PlateData({
    required this.worldId,
    required this.rank,
    required this.total,
    required this.survivalTime,
    required this.date,
    required this.scope,
  });

  Map<String, dynamic> toJson() => {
        'worldId': worldId,
        'rank': rank,
        'total': total,
        'survivalTime': survivalTime,
        'date': date.toIso8601String(),
        'scope': scope,
      };

  static PlateData? fromJson(Map<String, dynamic> j) {
    try {
      return PlateData(
        worldId: j['worldId'] as String,
        rank: (j['rank'] as num).toInt(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        survivalTime: (j['survivalTime'] as num).toDouble(),
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        scope: j['scope'] as String? ?? 'world',
      );
    } catch (_) {
      return null;
    }
  }

  String get dateLabel =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  /// 세계 명패가 국가 명패보다 우선, 같은 범위면 순위가 낮을수록 좋다.
  bool isBetterThan(PlateData other) {
    if (scope != other.scope) return scope == 'world';
    return rank < other.rank;
  }
}

class RankCacheEntry {
  final int rank;
  final int total;
  final DateTime at;
  const RankCacheEntry({required this.rank, required this.total, required this.at});
}

class ProgressStore {
  static const _keyBestTimes = 'world_best_times';
  static const _keyRankCache = 'world_rank_cache';
  static const _keyPlates = 'world_plates';

  static Future<Map<String, dynamic>> _readJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeJson(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  static Future<void> _syncRemote(Map<String, dynamic> fields) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(fields, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ProgressStore sync failed: $e');
    }
  }

  // ── 최고 기록 ───────────────────────────────────────────────

  static Future<Map<String, double>> getBestTimes() async {
    final j = await _readJson(_keyBestTimes);
    return j.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// 갱신 전 최고 기록을 돌려준다(결과 화면의 델타 표시용).
  static Future<double> updateBestTime(String worldId, double time) async {
    final best = await getBestTimes();
    final prev = best[worldId] ?? 0.0;
    if (time > prev) {
      best[worldId] = time;
      await _writeJson(_keyBestTimes, best);
      _syncRemote({'bestTimes': best});
    }
    return prev;
  }

  // ── 순위 캐시 (홈 카드·프로필 표시용, 쿼리 없이) ──────────────

  static Future<Map<String, RankCacheEntry>> getRankCache() async {
    final j = await _readJson(_keyRankCache);
    final out = <String, RankCacheEntry>{};
    j.forEach((k, v) {
      try {
        final m = Map<String, dynamic>.from(v);
        out[k] = RankCacheEntry(
          rank: (m['rank'] as num).toInt(),
          total: (m['total'] as num).toInt(),
          at: DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime.now(),
        );
      } catch (_) {}
    });
    return out;
  }

  /// 최고 기록 기준 순위만 남긴다 — 더 나쁜 판의 순위로 덮어쓰지 않는다.
  static Future<void> setRankCache(String worldId, int rank, int total, {bool force = false}) async {
    final j = await _readJson(_keyRankCache);
    final existing = j[worldId];
    if (!force && existing is Map && existing['rank'] is num && (existing['rank'] as num) < rank) {
      // 기존 캐시가 더 좋은 순위면 총 기록 수만 갱신
      j[worldId] = {...Map<String, dynamic>.from(existing), 'total': total, 'at': DateTime.now().toIso8601String()};
    } else {
      j[worldId] = {'rank': rank, 'total': total, 'at': DateTime.now().toIso8601String()};
    }
    await _writeJson(_keyRankCache, j);
  }

  // ── 명패 ────────────────────────────────────────────────────

  static Future<Map<String, PlateData>> getPlates() async {
    final j = await _readJson(_keyPlates);
    final out = <String, PlateData>{};
    j.forEach((k, v) {
      final p = PlateData.fromJson(Map<String, dynamic>.from(v));
      if (p != null) out[k] = p;
    });
    return out;
  }

  /// 더 좋은 명패일 때만 저장하고 true 를 돌려준다(= 의식 화면 진입 조건).
  static Future<bool> savePlate(PlateData plate) async {
    final plates = await getPlates();
    final existing = plates[plate.worldId];
    if (existing != null && !plate.isBetterThan(existing)) return false;
    plates[plate.worldId] = plate;
    final j = plates.map((k, v) => MapEntry(k, v.toJson()));
    await _writeJson(_keyPlates, j);
    _syncRemote({'plates': j});
    return true;
  }

  /// 로그인 시 원격 데이터를 로컬과 합친다(최고 기록·명패는 더 좋은 쪽 유지).
  static Future<void> mergeFromRemote(Map<String, dynamic> userDoc) async {
    try {
      final remoteBest = userDoc['bestTimes'];
      if (remoteBest is Map) {
        final best = await getBestTimes();
        remoteBest.forEach((k, v) {
          final t = (v as num).toDouble();
          if (t > (best[k] ?? 0)) best[k] = t;
        });
        await _writeJson(_keyBestTimes, best);
      }
      final remotePlates = userDoc['plates'];
      if (remotePlates is Map) {
        final plates = await getPlates();
        remotePlates.forEach((k, v) {
          final p = PlateData.fromJson(Map<String, dynamic>.from(v));
          if (p == null) return;
          final e = plates[k];
          if (e == null || p.isBetterThan(e)) plates[k] = p;
        });
        await _writeJson(_keyPlates, plates.map((k, v) => MapEntry(k, v.toJson())));
      }
    } catch (e) {
      debugPrint('ProgressStore merge failed: $e');
    }
  }

  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBestTimes);
    await prefs.remove(_keyRankCache);
    await prefs.remove(_keyPlates);
  }
}
