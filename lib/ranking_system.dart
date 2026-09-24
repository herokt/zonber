import 'gear.dart';
import 'season.dart';
import 'badges.dart';
import 'store_shot.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum RankingPeriod { weekly, monthly, allTime }

class RankingSystem {
  FirebaseFirestore? _db;

  RankingSystem() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _db = FirebaseFirestore.instance;
      } catch (e) {
        debugPrint("Firestore init failed (or not available): $e");
      }
    }
  }

  /// 기간 시작점을 **기기 로컬 타임존** 기준으로 계산한다.
  ///
  /// UTC 기준이면 한국(UTC+9) 유저의 일간 랭킹이 오전 9시에 리셋되어
  /// "오늘의 기록"이라는 개념이 어긋난다. Timestamp 비교는 절대 시각으로
  /// 이루어지므로 로컬 DateTime을 그대로 써도 정확하다.
  /// 기간 안의 기록을 이만큼까지 읽어 와 시간순으로 정렬한다.
  /// (timestamp 범위 필터 + survivalTime 정렬은 Firestore 가 한 쿼리로 못 해서 앱에서 정렬한다.
  ///  500 이면 옛 기록을 옮겨 온 갤럭시(약 600건)에서 상위 기록이 빠질 수 있었다)
  static const int _scanLimit = 3000;

  /// 기간 시작 — 현재 시즌 시작보다 앞이면 시즌 시작(season.dart)
  DateTime _getPeriodStart(RankingPeriod period) {
    final start = _periodStart(period);
    return start.isBefore(Season.currentStart) ? Season.currentStart : start;
  }

  DateTime _periodStart(RankingPeriod period) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (period) {
      case RankingPeriod.weekly:
        // 주 시작 = 월요일 00:00 (로컬)
        return todayStart.subtract(Duration(days: todayStart.weekday - 1));
      case RankingPeriod.monthly:
        return DateTime(now.year, now.month, 1);
      case RankingPeriod.allTime:
        // "All Time"은 실제로는 올해 1월 1일부터
        return DateTime(now.year, 1, 1);
    }
  }

  // 1. Save Score (Write) — flag stored for national query; nickname fetched live from users
  Future<String> saveRecord(
    String mapId,
    double time, {
    String characterId = 'neon_green',
    String flag = '',
  }) async {
    if (_db == null) return 'local_id_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      DocumentReference docRef = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .add({
            'userId': userId,
            'flag': flag,
            'survivalTime': time,
            'characterId': characterId,
            'season': Season.current,
            'timestamp': FieldValue.serverTimestamp(),
          });

      return docRef.id;
    } catch (e) {
      debugPrint("ERROR: Save failed - $e");
      return '';
    }
  }

  /// 제출된 기록을 삭제한다. 광고 부활로 게임이 이어질 때 직전 기록을 지우는 용도.
  Future<void> deleteRecord(String mapId, String recordId) async {
    if (_db == null || recordId.isEmpty) return;
    try {
      await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .doc(recordId)
          .delete();
    } catch (e) {
      debugPrint("ERROR: Delete record failed - $e");
    }
  }

  /// 시간순으로 정렬된 기록에서 사람마다 첫(=가장 좋은) 기록만 남긴다.
  /// userId 가 없는 옛 기록은 닉네임+국기로 같은 사람을 가린다.
  static List<Map<String, dynamic>> _uniquePlayers(List<Map<String, dynamic>> sorted) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final r in sorted) {
      final uid = (r['userId'] as String?) ?? '';
      final key = uid.isNotEmpty ? uid : 'legacy:${r['nickname'] ?? ''}|${r['flag'] ?? ''}';
      if (seen.add(key)) out.add(r);
    }
    return out;
  }

  /// Batch-fetch nickname/flag from users collection and inject into records.
  /// Falls back to existing nickname/flag fields for legacy records without userId.
  /// [worldId] 를 주면 그 존에 장착한 장비(users.equipped)를 붙인다.
  Future<void> _enrichWithUserData(List<Map<String, dynamic>> records, {String? worldId}) async {
    if (_db == null) return;

    final userIds = records
        .map((r) => (r['userId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (userIds.isEmpty) return;

    final Map<String, Map<String, dynamic>> userMap = {};
    for (int i = 0; i < userIds.length; i += 30) {
      final batch = userIds.skip(i).take(30).toList();
      try {
        final snap = await _db!
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          userMap[doc.id] = doc.data();
        }
      } catch (_) {}
    }

    for (final r in records) {
      final uid = (r['userId'] as String?) ?? '';
      final user = userMap[uid];
      if (user != null) {
        r['nickname'] = (user['nickname'] as String?) ?? r['nickname'] ?? 'Unknown';
        final userFlag = (user['flag'] as String?) ?? '';
        r['flag'] = userFlag.isNotEmpty ? userFlag : ((r['flag'] as String?) ?? '');
        // 프로필 그림은 기록 당시가 아니라 지금 고른 캐릭터 · 그 존에서 지금 입은 장비
        final charId = user['characterId'];
        if (charId is String && charId.isNotEmpty) r['characterId'] = charId;
        final equipped = user['equipped'];
        if (equipped is Map && equipped['skin'] is String) r['skin'] = equipped['skin'];
        if (worldId != null && equipped is Map) {
          r['gear'] = <String>[
            for (final slot in Gear.slotsOf(worldId))
              if (equipped[Gear.slotKey(worldId, slot)] is String && Gear.byId(equipped[Gear.slotKey(worldId, slot)] as String) != null)
                equipped[Gear.slotKey(worldId, slot)] as String,
          ];
        }
        // 대표 뱃지(가장 높은 등급) — 랭킹 이름 옆 아이콘
        final achievements = user['achievements'];
        if (achievements is List) {
          final best = Badges.best(achievements.whereType<String>());
          if (best != null) r['badge'] = best.key;
        }
      }
    }
  }

  // _maintainTop30 Removed as we save all records now.

  // 2. Fetch Top 30 (Read) with period filter
  Future<List<Map<String, dynamic>>> getTopRecords(
    String mapId, {
    RankingPeriod period = RankingPeriod.allTime,
  }) async {
    if (kStoreShot) return StoreShot.records(mapId);
    if (_db == null) return [];
    try {
      final periodStart = _getPeriodStart(period);

      QuerySnapshot snapshot = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .limit(_scanLimit)
          .get();

      List<Map<String, dynamic>> records = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      records.sort((a, b) {
        double timeA = (a['survivalTime'] as num).toDouble();
        double timeB = (b['survivalTime'] as num).toDouble();
        return timeB.compareTo(timeA);
      });

      // 한 사람은 한 번만 — 가장 좋은 기록으로
      final top30 = _uniquePlayers(records).take(30).toList();
      await _enrichWithUserData(top30, worldId: mapId);
      return top30;
    } catch (e) {
      debugPrint("Load failed: $e");
      return [];
    }
  }

  /// 이 시간이 전체 기록 중 몇 위인지 — count 집계 2회(더 좋은 기록 수, 전체 수).
  /// 복합 인덱스를 피하려고 기간 필터 없이 **전체 기간** 기준이다.
  /// 기록 단위(유저 단위 아님)라 표기는 "N개 기록 중".
  Future<({int rank, int total})?> getGlobalRank(String mapId, double time) async {
    if (_db == null) return null;
    try {
      final col = _db!.collection('maps').doc(mapId).collection('records');
      final better = await col.where('survivalTime', isGreaterThan: time).count().get();
      final all = await col.count().get();
      return (rank: (better.count ?? 0) + 1, total: all.count ?? 0);
    } catch (e) {
      debugPrint("Rank count failed: $e");
      return null;
    }
  }

  /// 올해 상위 기록 시간 목록(내림차순, 최대 limit). 목표선·TOP N 진입선 계산용.
  Future<List<double>> getTopTimes(String mapId, {int limit = 100}) async {
    if (kStoreShot) return StoreShot.topTimes(mapId, limit: limit);
    if (_db == null) return [];
    try {
      final periodStart = _getPeriodStart(RankingPeriod.allTime);
      final snap = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .limit(_scanLimit)
          .get();
      final times = snap.docs
          .map((d) => ((d.data()['survivalTime'] as num?) ?? 0).toDouble())
          .toList()
        ..sort((a, b) => b.compareTo(a));
      return times.take(limit).toList();
    } catch (e) {
      debugPrint("Top times failed: $e");
      return [];
    }
  }

  // 3. Fetch National Top 30 — query by flag field (works for all records including legacy)
  /// 국가 랭킹 — 기간 안의 기록을 한 사람 한 번(가장 좋은 기록)으로 모은 뒤, 유저의 **현재 국가**(users.flag)로 거른다.
  /// 기록 문서의 flag 는 기록 당시 국가라서, 국가를 바꾼 유저가 빠지던 문제를 막는다(2026-09-22).
  /// 결과 화면의 국가 순위 계산([limit] 500)도 같은 목록(사람 단위)을 쓴다.
  Future<List<Map<String, dynamic>>> getNationalRankings(
    String mapId,
    String flag, {
    RankingPeriod period = RankingPeriod.allTime,
    int limit = 30,
  }) async {
    if (kStoreShot) return StoreShot.records(mapId, limit: limit);
    if (_db == null) return [];
    try {
      final periodStart = _getPeriodStart(period);
      final snap = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .limit(_scanLimit)
          .get();
      final records = [
        for (final doc in snap.docs) {...doc.data(), 'id': doc.id},
      ]..sort((a, b) => ((b['survivalTime'] as num).toDouble()).compareTo((a['survivalTime'] as num).toDouble()));
      final players = _uniquePlayers(records);
      await _enrichWithUserData(players, worldId: mapId); // flag = 유저의 현재 국가
      return players.where((r) => r['flag'] == flag).take(limit).toList();
    } catch (e) {
      debugPrint("National load failed: $e");
      return [];
    }
  }

  // 4. Fetch My Best Record for period (queried by userId)
  Future<Map<String, dynamic>?> getMyRank(
    String mapId,
    String userId, {
    RankingPeriod period = RankingPeriod.allTime,
  }) async {
    if (kStoreShot) return null;
    if (_db == null || userId.isEmpty) return null;
    try {
      final periodStart = _getPeriodStart(period);

      final snap = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('userId', isEqualTo: userId)
          .get();

      if (snap.docs.isEmpty) return null;

      var docs = snap.docs.where((doc) {
        final ts = doc.data()['timestamp'] as Timestamp?;
        if (ts == null) return false;
        return !ts.toDate().isBefore(periodStart);
      }).toList();

      if (docs.isEmpty) return null;

      docs.sort((a, b) {
        double timeA = (a.data()['survivalTime'] as num).toDouble();
        double timeB = (b.data()['survivalTime'] as num).toDouble();
        return timeB.compareTo(timeA);
      });

      final myData = docs.first.data();
      myData['id'] = docs.first.id;
      myData['rank'] = -1;

      await _enrichWithUserData([myData], worldId: mapId);
      return myData;
    } catch (e) {
      debugPrint("My rank load failed: $e");
      return null;
    }
  }

}
