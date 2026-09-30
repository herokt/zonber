import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'player_profile.dart';
import 'services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 친구 — docs/FRIENDS.md. 읽기는 앱이 직접, 쓰기(맺기·요청·답·끊기)는 서버 함수(functions/friends.js).
//   users/{me}/friends/{uid}          내 친구 목록(본인만 읽는다)
//   friend_requests/{from_to}         요청(보낸 사람·받는 사람만 읽는다)
// 게스트는 친구가 없다(로그인 안내만).
// ─────────────────────────────────────────────────────────────

/// 서버 함수 결과 — functions/friends.js 가 돌려주는 코드와 같다
enum FriendResult {
  added,
  already,
  requested,
  declined,
  removed,
  notFound,
  self,
  myLimit,
  theirLimit,
  tooMany,
  cooldown,
  expired,
  guest,
  error,
}

/// 서버 결과 코드 → [FriendResult] (모르는 코드는 error)
FriendResult friendResultOf(String? s) => switch (s) {
      'added' => FriendResult.added,
      'already' => FriendResult.already,
      'requested' => FriendResult.requested,
      'declined' => FriendResult.declined,
      'removed' => FriendResult.removed,
      'not_found' => FriendResult.notFound,
      'self' => FriendResult.self,
      'my_limit' => FriendResult.myLimit,
      'their_limit' => FriendResult.theirLimit,
      'too_many' => FriendResult.tooMany,
      'cooldown' => FriendResult.cooldown,
      'expired' => FriendResult.expired,
      _ => FriendResult.error,
    };

/// 결과 안내 문구 키(translations.dart)
String friendResultKey(FriendResult r) => switch (r) {
      FriendResult.added => 'friend_added_toast',
      FriendResult.already => 'friend_already',
      FriendResult.requested => 'friend_requested_toast',
      FriendResult.declined => 'friend_declined_toast',
      FriendResult.removed => 'friend_removed_toast',
      FriendResult.notFound => 'friend_not_found',
      FriendResult.self => 'friend_code_self',
      FriendResult.myLimit => 'friend_my_limit',
      FriendResult.theirLimit => 'friend_their_limit',
      FriendResult.tooMany => 'friend_too_many',
      FriendResult.cooldown => 'friend_cooldown',
      FriendResult.expired => 'friend_expired',
      FriendResult.guest => 'guest_login_to_save',
      FriendResult.error => 'friend_error',
    };

/// 이 사람과 나 사이
enum FriendState { self, none, friend, requested, incoming }

/// 받은 친구 요청 한 건
@immutable
class FriendRequest {
  final String from;
  final DateTime? at;
  const FriendRequest(this.from, this.at);
}

class Friends {
  /// 제한 — functions/logic.js 와 같게
  static const int maxFriends = 100;
  static const int maxPending = 50;
  static const int requestDays = 7;

  /// 내 친구 uid — 화면들이 같이 본다(친구 화면 · 랭킹 친구 탭 · 프로필 카드). [refresh] 로 다시 읽는다
  static final ValueNotifier<Set<String>> ids = ValueNotifier(const {});
  static String? _idsOf;

  static String? get _uid {
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || AuthService.isGuest) ? null : u.uid;
    } catch (_) {
      return null;
    }
  }

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static Future<FriendResult> _call(String name, Map<String, dynamic> data) async {
    if (_uid == null) return FriendResult.guest;
    try {
      final r = await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(name).call<Map<String, dynamic>>(data);
      final result = friendResultOf(r.data['result'] as String?);
      if (result == FriendResult.added || result == FriendResult.removed) await refresh();
      return result;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('friends $name: ${e.code} ${e.message}');
      return e.code == 'unauthenticated' ? FriendResult.guest : FriendResult.error;
    } catch (e) {
      debugPrint('friends $name: $e');
      return FriendResult.error;
    }
  }

  /// 친구 코드로 바로 친구
  static Future<FriendResult> addByCode(String code) => _call('addFriendByCode', {'code': code.trim().toUpperCase()});

  /// 친구 요청(상대가 먼저 보냈으면 바로 친구)
  static Future<FriendResult> request(String uid) => _call('sendFriendRequest', {'uid': uid});

  /// 받은 요청에 답하기
  static Future<FriendResult> answer(String uid, {required bool accept}) async {
    final r = await _call('answerFriendRequest', {'uid': uid, 'accept': accept});
    incomingCount.value = (incomingCount.value - 1).clamp(0, 999);
    return r;
  }

  /// 친구 끊기(양쪽)
  static Future<FriendResult> remove(String uid) => _call('removeFriend', {'uid': uid});

  /// 내 친구 uid 다시 읽기 — 로그아웃·게스트면 비운다
  static Future<Set<String>> refresh() async {
    final me = _uid;
    if (me == null) {
      ids.value = const {};
      _idsOf = null;
      return const {};
    }
    try {
      final snap = await _db.collection('users').doc(me).collection('friends').get();
      ids.value = {for (final d in snap.docs) d.id};
      _idsOf = me;
    } catch (e) {
      debugPrint('friends refresh: $e');
    }
    return ids.value;
  }

  /// 처음 한 번(또는 계정이 바뀌었으면) 읽고, 아니면 들고 있던 것
  static Future<Set<String>> load() async => (_idsOf != null && _idsOf == _uid) ? ids.value : refresh();

  /// 받은 요청 수 — 프로필 탭의 친구 줄에 점으로
  static final ValueNotifier<int> incomingCount = ValueNotifier(0);

  /// 받은 요청(기한 안) — 최근 순
  static Future<List<FriendRequest>> incoming() async {
    final me = _uid;
    if (me == null) return const [];
    try {
      final snap = await _db.collection('friend_requests').where('to', isEqualTo: me).where('status', isEqualTo: 'pending').get();
      final now = DateTime.now();
      final list = [
        for (final d in snap.docs)
          if (((d.data()['expiresAt'] as Timestamp?)?.toDate().isAfter(now)) ?? false)
            FriendRequest(d.data()['from'] as String? ?? '', (d.data()['at'] as Timestamp?)?.toDate()),
      ]..sort((a, b) => (b.at ?? now).compareTo(a.at ?? now));
      incomingCount.value = list.length;
      return list;
    } catch (e) {
      debugPrint('friends incoming: $e');
      return const [];
    }
  }

  /// 내가 보낸 요청(기한 안)의 받는 사람
  static Future<Set<String>> outgoing() async {
    final me = _uid;
    if (me == null) return const {};
    try {
      final snap = await _db.collection('friend_requests').where('from', isEqualTo: me).where('status', isEqualTo: 'pending').get();
      final now = DateTime.now();
      return {
        for (final d in snap.docs)
          if (((d.data()['expiresAt'] as Timestamp?)?.toDate().isAfter(now)) ?? false) d.data()['to'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('friends outgoing: $e');
      return const {};
    }
  }

  /// 이 사람과 나 사이(프로필 카드 버튼)
  static Future<FriendState> stateOf(String uid) async {
    final me = _uid;
    if (me == null || uid.isEmpty) return FriendState.none;
    if (uid == me) return FriendState.self;
    if ((await load()).contains(uid)) return FriendState.friend;
    try {
      final mine = await _db.collection('friend_requests').doc('${me}_$uid').get();
      if (_pending(mine)) return FriendState.requested;
      final theirs = await _db.collection('friend_requests').doc('${uid}_$me').get();
      if (_pending(theirs)) return FriendState.incoming;
    } catch (e) {
      debugPrint('friends state: $e');
    }
    return FriendState.none;
  }

  static bool _pending(DocumentSnapshot<Map<String, dynamic>> d) =>
      d.exists &&
      d.data()?['status'] == 'pending' &&
      (((d.data()?['expiresAt'] as Timestamp?)?.toDate().isAfter(DateTime.now())) ?? false);

  /// 여러 사람 프로필을 한꺼번에(30명씩) — 친구 목록 · 받은 요청 줄
  static Future<Map<String, PlayerProfile>> profiles(Iterable<String> uids) async {
    final list = uids.where((u) => u.isNotEmpty).toSet().toList();
    final out = <String, PlayerProfile>{};
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.skip(i).take(30).toList();
      try {
        final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final d in snap.docs) {
          out[d.id] = PlayerProfile.fromUserDoc(d.id, d.data());
        }
      } catch (e) {
        debugPrint('friends profiles: $e');
      }
    }
    return out;
  }

  /// 로그아웃 — 들고 있던 것을 비운다
  static void clear() {
    ids.value = const {};
    _idsOf = null;
    incomingCount.value = 0;
  }
}
