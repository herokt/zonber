import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────
// 유저별 플레이 기록 — 판이 끝날 때마다 users/{uid}/runs/{자동 id} 에 한 줄.
// 회원만 남긴다(게스트 판은 저장하지 않는다 — 2026-09-22). 읽기는 본인·관리자만(firestore.rules). 백오피스가 쓴다.
// 랭킹 기록(maps/*/records)과 달리 모든 판(짧은 판·부활 포함)을 남긴다.
// ─────────────────────────────────────────────────────────────
class RunHistory {
  static Future<void> save(Map<String, Object?> run) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || kIsWeb) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('runs').add({
        ...run,
        'platform': defaultTargetPlatform.name,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RunHistory save failed: $e');
    }
  }
}
