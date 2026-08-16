import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum RankingPeriod { daily, weekly, monthly, allTime }

class RankingSystem {
  FirebaseFirestore? _db;

  RankingSystem() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _db = FirebaseFirestore.instance;
      } catch (e) {
        print("Firestore init failed (or not available): $e");
      }
    }
  }

  /// 기간 시작점을 **기기 로컬 타임존** 기준으로 계산한다.
  ///
  /// UTC 기준이면 한국(UTC+9) 유저의 일간 랭킹이 오전 9시에 리셋되어
  /// "오늘의 기록"이라는 개념이 어긋난다. Timestamp 비교는 절대 시각으로
  /// 이루어지므로 로컬 DateTime을 그대로 써도 정확하다.
  DateTime _getPeriodStart(RankingPeriod period) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (period) {
      case RankingPeriod.daily:
        return todayStart;
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

  /// Get period label for display
  static String getPeriodLabel(RankingPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case RankingPeriod.daily:
        return "${now.month}/${now.day}";
      case RankingPeriod.weekly:
        return "Week ${_getWeekNumber(now)}";
      case RankingPeriod.monthly:
        return _getMonthName(now.month);
      case RankingPeriod.allTime:
        return "${now.year}"; // Display Current Year
    }
  }

  static int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }

  static String _getMonthName(int month) {
    const months = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[month];
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
            'timestamp': FieldValue.serverTimestamp(),
          });

      return docRef.id;
    } catch (e) {
      print("ERROR: Save failed - $e");
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
      print("ERROR: Delete record failed - $e");
    }
  }

  /// Batch-fetch nickname/flag from users collection and inject into records.
  /// Falls back to existing nickname/flag fields for legacy records without userId.
  Future<void> _enrichWithUserData(List<Map<String, dynamic>> records) async {
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
      }
    }
  }

  // 1.5 Get Global Play Counts
  Future<Map<String, int>> getGlobalPlayCounts() async {
    if (_db == null) return {};
    try {
      QuerySnapshot snapshot = await _db!.collection('maps').get();
      Map<String, int> counts = {};
      for (var doc in snapshot.docs) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('playCount')) {
          counts[doc.id] = data['playCount'] as int;
        }
      }
      return counts;
    } catch (e) {
      print("Error fetching play counts: $e");
      return {};
    }
  }

  // _maintainTop30 Removed as we save all records now.

  // 2. Fetch Top 30 (Read) with period filter
  Future<List<Map<String, dynamic>>> getTopRecords(
    String mapId, {
    RankingPeriod period = RankingPeriod.allTime,
  }) async {
    if (_db == null) return [];
    try {
      final periodStart = _getPeriodStart(period);

      QuerySnapshot snapshot = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .limit(500)
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

      final top30 = records.take(30).toList();
      await _enrichWithUserData(top30);
      return top30;
    } catch (e) {
      print("Load failed: $e");
      return [];
    }
  }

  // 3. Fetch National Top 30 — query by flag field (works for all records including legacy)
  Future<List<Map<String, dynamic>>> getNationalRankings(
    String mapId,
    String flag, {
    RankingPeriod period = RankingPeriod.allTime,
  }) async {
    if (_db == null) return [];
    try {
      final periodStart = _getPeriodStart(period);

      // Query by flag field — stored in every record (new + legacy)
      final snap = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('flag', isEqualTo: flag)
          .limit(500)
          .get();

      final List<Map<String, dynamic>> records = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        if (ts == null || ts.toDate().isBefore(periodStart)) continue;
        data['id'] = doc.id;
        records.add(data);
      }

      records.sort((a, b) {
        double timeA = (a['survivalTime'] as num).toDouble();
        double timeB = (b['survivalTime'] as num).toDouble();
        return timeB.compareTo(timeA);
      });

      final top30 = records.take(30).toList();
      await _enrichWithUserData(top30); // fetch live nickname from users
      return top30;
    } catch (e) {
      print("National load failed: $e");
      return [];
    }
  }

  // 4. Fetch My Best Record for period (queried by userId)
  Future<Map<String, dynamic>?> getMyRank(
    String mapId,
    String userId, {
    RankingPeriod period = RankingPeriod.allTime,
  }) async {
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

      await _enrichWithUserData([myData]);
      return myData;
    } catch (e) {
      print("My rank load failed: $e");
      return null;
    }
  }

  // 5. Get User Titles (Check Top 30 in all periods)
  Future<List<String>> getUserTitles(String mapId, String nickname) async {
    if (_db == null) return [];
    List<String> titles = [];

    // Check Daily
    var dailyTop = await getTopRecords(mapId, period: RankingPeriod.daily);
    if (dailyTop.any((r) => r['nickname'] == nickname)) {
      titles.add('Daily Ranker');
    }

    // Check Weekly
    var weeklyTop = await getTopRecords(mapId, period: RankingPeriod.weekly);
    if (weeklyTop.any((r) => r['nickname'] == nickname)) {
      titles.add('Weekly Ranker');
    }

    // Check Monthly
    var monthlyTop = await getTopRecords(mapId, period: RankingPeriod.monthly);
    if (monthlyTop.any((r) => r['nickname'] == nickname)) {
      titles.add('Monthly Ranker');
    }

    // Check Yearly (All Time in this context)
    var yearlyTop = await getTopRecords(mapId, period: RankingPeriod.allTime);
    if (yearlyTop.any((r) => r['nickname'] == nickname)) {
      titles.add('Legendary Survivor');
    }

    return titles;
  }
}
