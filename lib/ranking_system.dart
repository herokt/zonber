import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Get the start of period in UTC
  DateTime _getPeriodStart(RankingPeriod period) {
    final now = DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);

    switch (period) {
      case RankingPeriod.daily:
        return todayStart;
      case RankingPeriod.weekly:
        // Monday as start of week (UTC 0:00)
        final weekday = todayStart.weekday;
        return todayStart.subtract(Duration(days: weekday - 1));
      case RankingPeriod.monthly:
        return DateTime.utc(now.year, now.month, 1);
      case RankingPeriod.allTime:
        // Changed "All Time" to "Current Year" as requested
        return DateTime.utc(now.year, 1, 1);
    }
  }

  /// Get period label for display
  static String getPeriodLabel(RankingPeriod period) {
    final now = DateTime.now().toUtc();
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
    final firstDayOfYear = DateTime.utc(date.year, 1, 1);
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

  // 1. Save Score (Write) - Save all records (Filtering done on Read)
  Future<String> saveRecord(
    String mapId,
    String nickname,
    String flag,
    double time,
  ) async {
    print('=== SAVE RECORD START ===');
    print('Map ID: $mapId');
    print('Nickname: $nickname');
    print('Flag: $flag');
    print('Survival Time: $time');
    print('Firestore available: ${_db != null}');

    if (_db == null) {
      print(
        "ERROR: Firestore not initialized. Check Firebase initialization in main.dart",
      );
      return 'local_id_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      print('Attempting to save to Firestore...');
      DocumentReference docRef = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .add({
            'nickname': nickname,
            'flag': flag,
            'survivalTime': time,
            'timestamp': FieldValue.serverTimestamp(),
          });
      print('SUCCESS: Record saved with ID: ${docRef.id}');

      // Increment Global Play Count for this Map
      await _db!.collection('maps').doc(mapId).set({
        'playCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      print('=== SAVE RECORD END ===');
      return docRef.id;
    } catch (e) {
      print("ERROR: Save failed - $e");
      print('Stack trace: ${StackTrace.current}');
      print('=== SAVE RECORD END ===');
      return '';
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

      Query query = _db!.collection('maps').doc(mapId).collection('records');

      if (period != RankingPeriod.allTime) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart),
        );
      }

      // Fetch more records and sort in memory to avoid composite index
      QuerySnapshot snapshot = await query.limit(200).get();

      List<Map<String, dynamic>> records = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by survivalTime descending
      records.sort((a, b) {
        double timeA = (a['survivalTime'] as num).toDouble();
        double timeB = (b['survivalTime'] as num).toDouble();
        return timeB.compareTo(timeA);
      });

      return records.take(30).toList();
    } catch (e) {
      print("Load failed: $e");
      return [];
    }
  }

  // 3. Fetch National Top 30 with period filter
  Future<List<Map<String, dynamic>>> getNationalRankings(
    String mapId,
    String flag, {
    RankingPeriod period = RankingPeriod.allTime,
  }) async {
    if (_db == null) return [];
    try {
      final periodStart = _getPeriodStart(period);

      Query query = _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('flag', isEqualTo: flag);

      // REMOVED TIMESTAMP FILTER TO AVOID COMPOSITE INDEX ISSUE
      // Filtering will be done in memory below.
      /*
      if (period != RankingPeriod.allTime) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart));
      }
      */

      QuerySnapshot snapshot = await query.limit(200).get();

      List<Map<String, dynamic>> records = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // IN-MEMORY FILTER
        if (period != RankingPeriod.allTime) {
          Timestamp? ts = data['timestamp'] as Timestamp?;
          if (ts != null && ts.toDate().isBefore(periodStart)) {
            continue;
          }
        }
        records.add(data);
      }

      // Sort in memory
      records.sort((a, b) {
        double timeA = (a['survivalTime'] as num).toDouble();
        double timeB = (b['survivalTime'] as num).toDouble();
        return timeB.compareTo(timeA);
      });

      return records.take(30).toList();
    } catch (e) {
      print("National load failed: $e");
      return [];
    }
  }

  // 4. Fetch My Rank and Record (Aggregation Query)
  Future<Map<String, dynamic>?> getMyRank(
    String mapId,
    String nickname, {
    String? flag,
    RankingPeriod period = RankingPeriod.allTime,
  }) async {
    if (_db == null) return null;
    try {
      final periodStart = _getPeriodStart(period);

      // 1. Find my records
      Query query = _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('nickname', isEqualTo: nickname);

      if (flag != null) {
        query = query.where('flag', isEqualTo: flag);
      }

      if (period != RankingPeriod.allTime) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart),
        );
      }

      QuerySnapshot myRecordSnapshot = await query.get();

      if (myRecordSnapshot.docs.isEmpty) return null;

      // In-memory sort to find best record
      var docs = myRecordSnapshot.docs.toList();
      print("Found ${docs.length} records for $nickname");

      docs.sort((a, b) {
        var dataA = a.data() as Map<String, dynamic>;
        var dataB = b.data() as Map<String, dynamic>;
        double timeA = (dataA['survivalTime'] as num).toDouble();
        double timeB = (dataB['survivalTime'] as num).toDouble();
        return timeB.compareTo(timeA); // Descending
      });

      var myDoc = docs.first;
      var myData = myDoc.data() as Map<String, dynamic>;
      myData['id'] = myDoc.id;

      // 2. Rank calculation skipped (Cost and Efficiency)
      // If not in Top 30, we return -1.
      myData['rank'] = -1;

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
