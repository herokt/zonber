import 'package:cloud_firestore/cloud_firestore.dart';

class RankingSystem {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. 점수 저장하기 (Write) - 저장된 문서 ID 반환
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

  // 2. 랭킹 10등까지 불러오기 (Read) - ID도 포함해서 반환
  Future<List<Map<String, dynamic>>> getTopRecords(String mapId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('maps')
          .doc(mapId)
          .collection('records')
          .orderBy('survivalTime', descending: true)
          .limit(10)
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
}
