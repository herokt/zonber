import 'package:cloud_firestore/cloud_firestore.dart';

class RankingSystem {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. 점수 저장하기 (Write) - 모든 기록 저장 (랭킹 필터링은 Read 시 수행)
  Future<String> saveRecord(
    String mapId,
    String nickname,
    String flag,
    double time,
  ) async {
    try {
      DocumentReference docRef = await _db
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
      print("점수 저장 실패: $e");
      return '';
    }
  }

  // _maintainTop30 Removed as we save all records now.

  // 2. 랭킹 10등까지 불러오기 (Read) - ID도 포함해서 반환
  Future<List<Map<String, dynamic>>> getTopRecords(String mapId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .orderBy('survivalTime', descending: true)
          .limit(30) // Limit to 30
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // 문서 ID 포함
        return data;
      }).toList();
    } catch (e) {
      print("랭킹 로드 실패: $e");
      return [];
    }
  }

  // 3. 국가별 랭킹 30등 불러오기
  // Note: To avoid requiring a composite index (flag + survivalTime) in Firestore,
  // we will fetch records by flag and sort them in memory.
  // Ideally, create an index and use orderBy in the query for scalability.
  Future<List<Map<String, dynamic>>> getNationalRankings(
    String mapId,
    String flag,
  ) async {
    try {
      QuerySnapshot snapshot = await _db
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
      print("국가별 랭킹 로드 실패: $e");
      return [];
    }
  }

  // 4. 내 등수 및 기록 가져오기 (Aggregation Query)
  Future<Map<String, dynamic>?> getMyRank(
    String mapId,
    String nickname, {
    String? flag,
  }) async {
    try {
      // 1. 내 기록 찾기
      var query = _db
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('nickname', isEqualTo: nickname);

      if (flag != null) {
        query = query.where('flag', isEqualTo: flag);
      }

      QuerySnapshot myRecordSnapshot = await query
          .orderBy('survivalTime', descending: true) // 최고 기록 우선
          .limit(1)
          .get();

      if (myRecordSnapshot.docs.isEmpty) return null;

      var myDoc = myRecordSnapshot.docs.first;
      var myData = myDoc.data() as Map<String, dynamic>;
      myData['id'] = myDoc.id;
      double myScore = myData['survivalTime'];

      // 2. 나보다 점수 높은 사람 수 세기 (Count Aggregation)
      var countQuery = _db
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .where('survivalTime', isGreaterThan: myScore);

      if (flag != null) {
        countQuery = countQuery.where('flag', isEqualTo: flag);
      }

      AggregateQuerySnapshot countSnapshot = await countQuery.count().get();

      int rank = countSnapshot.count! + 1;
      myData['rank'] = rank;

      return myData;
    } catch (e) {
      print("내 랭킹 조회 실패: $e");
      return null;
    }
  }
}
