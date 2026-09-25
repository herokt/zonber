import 'package:flutter/foundation.dart';

import '../promotions.dart';
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

  // ── 이벤트(프로모션) ──
  /// promos 컬렉션 전체(앱 기본 이벤트는 여기 없을 수 있다 — promotions.dart 의 builtIn)
  Future<List<BoPromo>> promos();
  Future<void> savePromo(Promotion p);
  Future<void> deletePromo(String id);

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
enum BoSection { dashboard, users, ranking, runs, promos, economy }

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
