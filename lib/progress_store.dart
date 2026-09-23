import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'badges.dart';
import 'services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 월드별 진행 데이터 — 최고 기록 · 순위 캐시 (옛 명패는 뱃지로 옮겨졌다 — badges.dart)
//
// SharedPreferences(로컬) + Firestore users/{uid}(원격) 이중 저장.
// 게스트도 로컬은 쌓인다(월드 해금에 필요). 원격은 로그인 유저만.
// ─────────────────────────────────────────────────────────────

/// 존별 마지막으로 확인한 순위(순위 캐시)
class RankCacheEntry {
  final int rank;
  final int total;
  final DateTime at;
  const RankCacheEntry({required this.rank, required this.total, required this.at});
}

class ProgressStore {
  static const _keyBestTimes = 'world_best_times';
  static const _keyRankCache = 'world_rank_cache';
  static const _keyPlates = 'world_plates'; // 옛 명패 — 뱃지로 옮길 때만 읽는다

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
    if (AuthService.isGuest) return; // 게스트 기록은 남기지 않는다
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

  /// 로그인 시 원격 데이터를 로컬과 합친다(최고 기록은 더 좋은 쪽 유지).
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
      // 옛 명패 → 랭킹 뱃지(명패는 2026-09-22 제거)
      await Badges.migratePlates(userDoc['plates']);
      await Badges.migratePlates(await _readJson(_keyPlates));
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
