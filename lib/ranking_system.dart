import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // 1. Save Score (Write) - Save all records (Filtering done on Read)
  Future<String> saveRecord(
    String mapId,
    String nickname,
    String flag,
    double time,
  ) async {
    if (_db == null) {
      print("Saving locally/mocking (No Firestore)");
      return 'local_id_${DateTime.now().millisecondsSinceEpoch}';
    }
    try {
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
      return docRef.id;
    } catch (e) {
      print("Save failed: $e");
      return '';
    }
  }

  // _maintainTop30 Removed as we save all records now.

  // 2. Fetch Top 30 (Read)
  Future<List<Map<String, dynamic>>> getTopRecords(String mapId) async {
    if (_db == null) return [];
    try {
      QuerySnapshot snapshot = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .orderBy('survivalTime', descending: true)
          .limit(30) // Limit to 30
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("Load failed: $e");
      return [];
    }
  }

  // 3. Fetch National Top 30
  // Note: To avoid requiring a composite index (flag + survivalTime) in Firestore,
  // we will fetch records by flag and sort them in memory.
  // Ideally, create an index and use orderBy in the query for scalability.
  Future<List<Map<String, dynamic>>> getNationalRankings(
    String mapId,
    String flag,
  ) async {
    if (_db == null) return [];
    try {
      QuerySnapshot snapshot = await _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('flag', isEqualTo: flag)
          .limit(100) // Fetch up to 100 records for this country
          .get();

      List<Map<String, dynamic>> records = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort in memory
      records.sort((a, b) {
        double timeA = a['survivalTime'] as double;
        double timeB = b['survivalTime'] as double;
        return timeB.compareTo(timeA); // Descending
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
  }) async {
    if (_db == null) return null;
    try {
      // 1. Find my record
      var query = _db!
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('nickname', isEqualTo: nickname);

      if (flag != null) {
        query = query.where('flag', isEqualTo: flag);
      }

      QuerySnapshot myRecordSnapshot = await query.get();

      if (myRecordSnapshot.docs.isEmpty) return null;

      // In-memory sort to find best record
      var docs = myRecordSnapshot.docs;
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
}
