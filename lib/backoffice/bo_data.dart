import 'package:flutter/foundation.dart';

import '../promotions.dart';
import '../push.dart';
import 'bo_catalog.dart';

// ─────────────────────────────────────────────────────────────
// 백오피스 데이터 계층 — 화면은 Firestore 를 직접 부르지 않고 BoData.src(BoSource) 를 쓴다.
//  - 실제: FirestoreSource(bo_firestore.dart) — 기존 쿼리·관리 액션 그대로.
//  - 미리보기: MockSource(bo_mock.dart) — --dart-define=BO_PREVIEW=true 일 때만. 로그인·Firebase 없이 화면 확인용.
// users 전체는 한 번 읽어 캐시하고 여러 화면이 같이 쓴다. 전역 새로고침(BoData.refreshAll)은 epoch 를 올려
// 열려 있는 화면이 모두 다시 읽게 한다.
// ─────────────────────────────────────────────────────────────

/// 컴파일 시점 미리보기 플래그 — 켜면 Firebase·관리자 로그인 없이 가짜 데이터로 뜬다
const bool kBoPreview = bool.fromEnvironment('BO_PREVIEW');

/// users/{uid} 한 건
class BoUser {
  final String id;
  final Map<String, dynamic> data;
  const BoUser(this.id, this.data);
}

/// maps/{mapId}/records/{id} 한 건
class BoRec {
  final String id;
  final String mapId;
  final Map<String, dynamic> data;
  const BoRec(this.id, this.mapId, this.data);

  String get userId => (data['userId'] as String? ?? '').trim();
  double get time => dblOf(data['survivalTime']);
  DateTime? get at => tsOf(data['timestamp']);
}

/// 이벤트 한 건 — 정의 + 받은 사람 수(promos/{id}.claims)
class BoPromo {
  final Promotion promo;
  final int claims;
  const BoPromo(this.promo, this.claims);
}

/// 친구 한 명 — users/{uid}/friends/{친구uid} (docs/FRIENDS.md)
class BoFriend {
  final String uid;
  final DateTime? since;
  final String via; // code | request
  const BoFriend(this.uid, this.since, this.via);
}

/// 유저 ID 없는 랭킹 기록 한 사람분 — userId 가 없거나(옛 기록) 유저 문서가 없는(탈퇴 등) 기록을 묶는다.
/// 묶는 기준: 유저 문서가 없는 uid 가 있으면 그 uid, 없으면 닉네임(대소문자·앞뒤 공백 무시)
class BoLegacy {
  final String key;
  final String oldUid; // 유저 문서가 없는 uid('' = userId 없음)
  final List<BoRec> records;
  const BoLegacy(this.key, this.oldUid, this.records);

  String get nickname {
    for (final r in records) {
      final n = (r.data['nickname'] as String? ?? '').trim();
      if (n.isNotEmpty) return n;
    }
    return '(닉네임 없음)';
  }

  /// 가장 많이 나온 국기
  String get flag {
    final m = <String, int>{};
    for (final r in records) {
      final f = (r.data['flag'] as String? ?? '').trim();
      if (f.isNotEmpty) m[f] = (m[f] ?? 0) + 1;
    }
    if (m.isEmpty) return '';
    return (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  /// 존 최고 기록(없으면 null)
  double? best(String mapId) {
    double? b;
    for (final r in records) {
      if (r.mapId == mapId && (b == null || r.time > b)) b = r.time;
    }
    return b;
  }

  DateTime? get last {
    DateTime? l;
    for (final r in records) {
      final a = r.at;
      if (a != null && (l == null || a.isAfter(l))) l = a;
    }
    return l;
  }

  static String normNick(String? s) => (s ?? '').trim().toLowerCase();

  /// 기록 전부 + 있는 유저 uid → 사람별 묶음(최근 기록 순)
  static List<BoLegacy> group(Iterable<BoRec> records, Set<String> userIds) {
    final m = <String, List<BoRec>>{};
    final old = <String, String>{};
    for (final r in records) {
      final uid = r.userId;
      if (uid.isNotEmpty && userIds.contains(uid)) continue;
      final key = uid.isNotEmpty ? 'uid:$uid' : 'nick:${normNick(r.data['nickname'] as String?)}';
      (m[key] ??= []).add(r);
      if (uid.isNotEmpty) old[key] = uid;
    }
    final out = [for (final e in m.entries) BoLegacy(e.key, old[e.key] ?? '', e.value)];
    out.sort((a, b) => (b.last?.millisecondsSinceEpoch ?? 0).compareTo(a.last?.millisecondsSinceEpoch ?? 0));
    return out;
  }
}

/// 코드 사용 한 건 — 누가 언제
class BoCodeUse {
  final String uid;
  final DateTime? at;
  const BoCodeUse(this.uid, this.at);
}

/// 커서 기반 페이지(더 보기)
class BoChunk<T> {
  final List<T> items;
  final Object? cursor;
  final bool hasMore;
  const BoChunk(this.items, this.cursor, this.hasMore);
}

abstract class BoSource {
  bool get isPreview;
  String get adminEmail;
  Future<void> signOut();

  // ── 유저 ──
  Future<List<BoUser>> users();
  Future<Map<String, dynamic>?> user(String uid);

  /// users/{uid}/private/account 의 email — 없거나 못 읽으면 ''
  Future<String> privateEmail(String uid);
  Future<void> updateUser(String uid, Map<String, dynamic> fields);

  /// ownedItems 에 추가(arrayUnion)
  Future<void> grantItem(String uid, String itemId);

  /// coins 를 [amount] 만큼 더한다(음수면 회수)
  Future<void> grantCoins(String uid, int amount);
  Future<void> deleteUser(String uid);

  /// [field] 정수 값을 [amount] 만큼 더한다(닉네임·국가 변경권 등)
  Future<void> incrementField(String uid, String field, int amount);

  /// 계정을 통째로 지운다(서버 함수 adminDeleteUsers — 로그인 계정 · 랭킹 기록 · 하위 문서 · 친구 · 코드).
  /// uid → 'ok' | 'error: …'
  Future<Map<String, String>> deleteUsersFully(List<String> uids);

  /// 한 존의 랭킹 기록 전부(유저 ID 없는 기록 찾기용)
  Future<List<BoRec>> allRecords(String mapId);

  /// 랭킹 기록을 회원 [uid] 에게 붙인다(userId). 붙인 기록이 그 회원의 존 최고 기록(users.bestTimes)보다 좋으면 올린다
  Future<void> linkRecords(List<BoRec> recs, String uid);

  /// 랭킹 기록 여러 건 지우기
  Future<void> deleteRecords(List<BoRec> recs);

  // ── 플레이 기록(runs, collection group) ──
  /// since 이후 전체 유저 판(최신순, limit 까지)
  Future<List<RunRow>> runsSince(DateTime since, int limit);
  Future<List<RunRow>> latestRuns(int limit);
  Future<BoChunk<RunRow>> runsPage(DateTime since, Object? cursor, int limit);
  Future<int?> runsCount(DateTime since);

  // ── 한 유저의 runs ──
  Future<BoChunk<RunRow>> userRunsPage(String uid, Object? cursor, int limit);
  Future<List<RunRow>> userRunsSince(String uid, DateTime since, int limit);

  /// maps/{id}.playCount
  Future<Map<String, int>> mapPlayCounts();

  // ── 랭킹 기록 ──
  /// since == null: survivalTime 내림차순 limit. 아니면 timestamp >= since 범위를 limit 까지(정렬 안 됨)
  Future<List<BoRec>> records(String mapId, DateTime? since, int limit);
  Future<List<BoRec>> userRecords(String mapId, String uid, int limit);
  Future<void> deleteRecord(BoRec r);

  /// 이 유저의 친구 — 맺은 순서(최근 먼저)
  Future<List<BoFriend>> userFriends(String uid);

  // ── 이벤트(프로모션) ──
  /// promos 컬렉션 전체(앱 기본 이벤트는 여기 없을 수 있다 — promotions.dart 의 builtIn)
  Future<List<BoPromo>> promos();
  Future<void> savePromo(Promotion p);
  Future<void> deletePromo(String id);

  // ── 이벤트 코드(promo_codes) ──
  Future<List<PromoCode>> promoCodes();
  Future<PromoCode?> promoCode(String code);

  /// 새 코드 — 같은 코드가 이미 있거나 유저 친구 코드와 같으면 false(덮어쓰지 않는다)
  Future<bool> createPromoCode(PromoCode c);

  /// 보상·캠페인·메모·한도·기간·켜짐만 바꾼다(사용 수는 그대로)
  Future<void> updatePromoCode(PromoCode c);
  Future<void> deletePromoCode(String code);

  /// 이 코드를 쓴 사람(users/{uid}/codes/{code}) — 최근 순
  Future<List<BoCodeUse>> promoCodeUses(String code, int limit);

  // ── 푸시(push_campaigns) ──
  /// 최근 보낸 것부터
  Future<List<PushCampaign>> pushCampaigns(int limit);

  /// 보내기 — 문서를 pending 으로 만들면 서버 함수가 보낸다. 만든 문서 id
  Future<String> sendPush(PushCampaign c);

  // ── 관리 도구 ──
  /// flag 없는 유저 → 대한민국. 바꾼 수
  Future<int> fillDefaultCountry();

}

class BoData {
  static late BoSource src;

  static List<BoUser>? _users;
  static Future<List<BoUser>>? _loading;
  static final Map<String, Map<String, dynamic>> _byId = {};
  static DateTime? loadedAt;

  /// 전역 새로고침 번호 — 화면들이 듣고 다시 읽는다
  static final ValueNotifier<int> epoch = ValueNotifier(0);

  /// 마지막으로 데이터를 읽은 시각(상단바 "마지막 갱신")
  static final ValueNotifier<DateTime?> lastLoaded = ValueNotifier(null);
  static void markLoaded() => lastLoaded.value = DateTime.now();

  static Future<List<BoUser>> users() {
    if (_users != null) return Future.value(_users!);
    if (_loading != null) return _loading!;
    final f = src.users().then((list) {
      _users = list;
      _byId
        ..clear()
        ..addEntries(list.map((u) => MapEntry(u.id, u.data)));
      loadedAt = DateTime.now();
      markLoaded();
      _loading = null;
      return list;
    }, onError: (Object e) {
      _loading = null;
      throw e;
    });
    _loading = f;
    return f;
  }

  static Map<String, dynamic>? cached(String uid) => _byId[uid];

  /// 캐시에 없으면 한 건씩 읽는다(새로 가입한 유저 등)
  static Future<Map<String, Map<String, dynamic>?>> lookup(Iterable<String> uids) async {
    final out = <String, Map<String, dynamic>?>{};
    final missing = <String>[];
    for (final u in uids.toSet()) {
      if (u.isEmpty) continue;
      if (_byId.containsKey(u)) {
        out[u] = _byId[u];
      } else {
        missing.add(u);
      }
    }
    await Future.wait(missing.map((u) async {
      try {
        final data = await src.user(u);
        if (data != null) _byId[u] = data;
        out[u] = data;
      } catch (e) {
        debugPrint('BoData.lookup $u: $e');
        out[u] = null;
      }
    }));
    return out;
  }

  static void invalidate() {
    _users = null;
  }

  /// 캐시를 비우고 열린 화면을 모두 다시 읽게 한다
  static void refreshAll() {
    invalidate();
    epoch.value++;
  }
}

// ─────────────────────────────────────────────────────────────
// 화면 이동 — 왼쪽 메뉴 섹션 + (있으면) 그 위에 유저 상세
// ─────────────────────────────────────────────────────────────
enum BoSection { dashboard, users, ranking, runs, promos, codes, push, economy }

class BoNav {
  static final ValueNotifier<BoSection> section = ValueNotifier(BoSection.dashboard);
  static final ValueNotifier<String?> userUid = ValueNotifier(null);

  /// 유저 상세를 열 때 처음 보여 줄 탭(미리보기 ?tab= 용). 한 번 쓰면 0 으로 돌아간다
  static int initialUserTab = 0;
  static int takeUserTab() {
    final t = initialUserTab;
    initialUserTab = 0;
    return t;
  }

  static void go(BoSection s) {
    userUid.value = null;
    section.value = s;
  }

  static void openUser(String uid) {
    if (uid.isEmpty) return;
    userUid.value = uid;
  }

  static void closeUser() => userUid.value = null;
}
