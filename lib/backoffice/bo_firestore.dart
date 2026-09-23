import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'bo_catalog.dart';
import 'bo_data.dart';

// ─────────────────────────────────────────────────────────────
// 실제 데이터 — Firestore. (기존 화면들의 쿼리를 그대로 옮겼다)
// runs 는 collection group 'runs' 의 timestamp 단일 필드 색인이 필요하다(firestore.indexes.json).
// ─────────────────────────────────────────────────────────────
class FirestoreSource implements BoSource {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> _records(String mapId) =>
      _db.collection('maps').doc(mapId).collection('records');

  static RunRow _run(DocumentSnapshot<Map<String, dynamic>> d) =>
      RunRow.fromMap(d.id, d.reference.parent.parent?.id ?? '', d.data() ?? const {});

  @override
  bool get isPreview => false;

  @override
  String get adminEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();

  // ── 유저 ──
  @override
  Future<List<BoUser>> users() async {
    final snap = await _users.get();
    return [for (final d in snap.docs) BoUser(d.id, d.data())];
  }

  @override
  Future<Map<String, dynamic>?> user(String uid) async => (await _users.doc(uid).get()).data();

  @override
  Future<String> privateEmail(String uid) async {
    try {
      final d = await _users.doc(uid).collection('private').doc('account').get();
      return (d.data()?['email'] as String? ?? '').trim();
    } catch (e) {
      debugPrint('private/account: $e');
      return '';
    }
  }

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> fields) => _users.doc(uid).update(fields);

  @override
  Future<void> grantItem(String uid, String itemId) => _users.doc(uid).update({
        'ownedItems': FieldValue.arrayUnion([itemId]),
      });

  @override
  Future<void> grantCoins(String uid, int amount) => _users.doc(uid).update({
        'coins': FieldValue.increment(amount),
      });

  @override
  Future<void> deleteUser(String uid) => _users.doc(uid).delete();

  // ── runs ──
  Query<Map<String, dynamic>> _since(DateTime since) => _db
      .collectionGroup('runs')
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .orderBy('timestamp', descending: true);

  @override
  Future<List<RunRow>> runsSince(DateTime since, int limit) async =>
      (await _since(since).limit(limit).get()).docs.map(_run).toList();

  @override
  Future<List<RunRow>> latestRuns(int limit) async =>
      (await _db.collectionGroup('runs').orderBy('timestamp', descending: true).limit(limit).get())
          .docs
          .map(_run)
          .toList();

  @override
  Future<BoChunk<RunRow>> runsPage(DateTime since, Object? cursor, int limit) async {
    Query<Map<String, dynamic>> q = _since(since).limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return BoChunk(snap.docs.map(_run).toList(), snap.docs.isEmpty ? cursor : snap.docs.last, snap.docs.length == limit);
  }

  @override
  Future<int?> runsCount(DateTime since) async => (await _since(since).count().get()).count;

  @override
  Future<BoChunk<RunRow>> userRunsPage(String uid, Object? cursor, int limit) async {
    Query<Map<String, dynamic>> q = _users.doc(uid).collection('runs').orderBy('timestamp', descending: true).limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return BoChunk(snap.docs.map(_run).toList(), snap.docs.isEmpty ? cursor : snap.docs.last, snap.docs.length == limit);
  }

  @override
  Future<List<RunRow>> userRunsSince(String uid, DateTime since, int limit) async => (await _users
          .doc(uid)
          .collection('runs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get())
      .docs
      .map(_run)
      .toList();

  @override
  Future<Map<String, int>> mapPlayCounts() async {
    final snap = await _db.collection('maps').get();
    return {for (final d in snap.docs) d.id: intOf(d.data()['playCount'])};
  }

  // ── 랭킹 기록 ──
  @override
  Future<List<BoRec>> records(String mapId, DateTime? since, int limit) async {
    final col = _records(mapId);
    final snap = since == null
        ? await col.orderBy('survivalTime', descending: true).limit(limit).get()
        : await col.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since)).limit(limit).get();
    return [for (final d in snap.docs) BoRec(d.id, mapId, d.data())];
  }

  @override
  Future<List<BoRec>> userRecords(String mapId, String uid, int limit) async {
    final snap = await _records(mapId).where('userId', isEqualTo: uid).limit(limit).get();
    return [for (final d in snap.docs) BoRec(d.id, mapId, d.data())];
  }

  @override
  Future<void> deleteRecord(BoRec r) => _records(r.mapId).doc(r.id).delete();

  // ── 관리 도구 ──
  @override
  Future<int> fillDefaultCountry() async {
    final snapshot = await _users.get();
    int updated = 0;
    WriteBatch batch = _db.batch();
    for (final doc in snapshot.docs) {
      final flag = (doc.data()['flag'] as String? ?? '').trim();
      if (flag.isNotEmpty) continue;
      batch.update(doc.reference, {'flag': '🇰🇷', 'countryName': 'South Korea'});
      updated++;
      if (updated % 400 == 0) {
        await batch.commit();
        batch = _db.batch();
      }
    }
    if (updated % 400 != 0) await batch.commit();
    return updated;
  }
}
