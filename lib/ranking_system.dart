import 'package:cloud_firestore/cloud_firestore.dart';

class RankingSystem {
  // 지금은 맵이 하나니까 ID를 고정합니다. (나중에 map_2, map_3로 확장 가능)
  final String mapId = 'zone_1_classic';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. 점수 저장하기 (Write)
  Future<void> saveRecord(String nickname, double time) async {
    try {
      await _db.collection('maps').doc(mapId).collection('records').add({
        'nickname': nickname,
        'survivalTime': time,
        'timestamp': FieldValue.serverTimestamp(), // 서버 시간 자동 저장
      });
    } catch (e) {
      print("점수 저장 실패: $e");
    }
  }

  // 2. 랭킹 10등까지 불러오기 (Read)
  Future<List<Map<String, dynamic>>> getTopRecords() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .orderBy('survivalTime', descending: true) // 오래 버틴 순서
          .limit(10) // 10명만
          .get();

      return snapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      print("랭킹 로드 실패: $e");
      return [];
    }
  }
}
