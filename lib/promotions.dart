import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coin_store.dart';
import 'services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// 프로모션(이벤트) — 신규 유입·복귀를 노리는 가벼운 보상 이벤트 한 벌.
//
// 새 이벤트를 여는 방법은 둘이다.
//   1) 앱 업데이트 없이 — 백오피스에서 promos/{id} 문서 추가 (운영자가 바로 켜고 끈다)
//   2) 코드로 — [Promotions.builtIn] 에 한 줄 추가 (기본으로 늘 켜 두는 것)
// 둘 다 같은 [Promotion] 이고, 같은 화면(pages/promo_page.dart)에서 같은 방식으로 받는다.
//
// 받은 기록: 기기(SharedPreferences) + 계정(users/{uid}/promos/{promoId}).
//   기기를 바꾸거나 다시 깔아도 계정 기록을 먼저 읽어 두 번 받지 못하게 한다.
// 보상은 코인·아이템뿐이라 랭킹에 영향이 없다(docs/SHOP.md 의 코인 정책과 같은 자리).
//
// 이벤트 코드는 따로 논다 — [PromoCode] · promo_codes/{코드}. 코드마다 보상·캠페인·한도·기간이 있고,
// 코드를 아는 사람만 그 문서 한 건을 읽을 수 있다(목록 읽기는 관리자만 → 앱을 뜯어도 코드가 새지 않는다).
// 사용은 트랜잭션 한 번(내 사용 기록 생성 + 사용 수 +1)이고, 1인 1회·한도·기간은 firestore.rules 가 검사한다.
// ─────────────────────────────────────────────────────────────

/// 이벤트 종류 — 받는 방법이 다를 뿐, 보상 주는 길은 하나다
enum PromoKind {
  /// 처음 한 번 받는 환영 보상(신규 유입자용)
  welcome,

  /// 기간 중 한 번 받는 보상(공지·홍보용). cooldownHours 를 주면 주기마다(예: 168 = 매주)
  bonus,

  /// 코드 안내 카드 — 보상은 코드마다 따로(promo_codes). 카드는 "코드 입력"으로 안내만 한다
  code,

  /// 친구에게 자랑(SNS 공유)하면 받는 보상 — 하루 한 번
  share,
}

PromoKind _kindOf(String? s) => switch (s) {
      'welcome' => PromoKind.welcome,
      'code' => PromoKind.code,
      'share' => PromoKind.share,
      _ => PromoKind.bonus,
    };

DateTime? _time(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      String s => DateTime.tryParse(s),
      _ => null,
    };

List<String> _strings(Object? v) => (v as List?)?.whereType<String>().toList() ?? const [];

@immutable
class Promotion {
  final String id;
  final PromoKind kind;
  final bool enabled;
  final DateTime? startAt;
  final DateTime? endAt;

  /// 보상 — 코인과 아이템(꾸미기·장비·`char_{id}`)
  final int coins;
  final List<String> items;

  /// 다시 받기까지 기다리는 시간 — 0 이면 평생 한 번
  final int cooldownHours;

  /// 언어별 문구(ko 는 반드시, 나머지는 없으면 ko)
  final Map<String, String> title;
  final Map<String, String> desc;

  const Promotion({
    required this.id,
    required this.kind,
    this.enabled = true,
    this.startAt,
    this.endAt,
    this.coins = 0,
    this.items = const [],
    this.cooldownHours = 0,
    this.title = const {},
    this.desc = const {},
  });

  /// 지금 진행 중인가(켜짐 + 기간 안)
  bool get isLive {
    if (!enabled) return false;
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  /// 남은 날(기간이 없으면 null)
  int? get daysLeft => endAt == null ? null : endAt!.difference(DateTime.now()).inHours ~/ 24;

  String textOf(Map<String, String> m, String lang) =>
      (m[lang]?.trim().isNotEmpty == true) ? m[lang]! : (m['en'] ?? m['ko'] ?? '');

  String titleOf(String lang) => textOf(title, lang);
  String descOf(String lang) => textOf(desc, lang);

  bool get isEmptyReward => coins <= 0 && items.isEmpty;

  factory Promotion.fromDoc(String id, Map<String, dynamic> d) => Promotion(
        id: id,
        kind: _kindOf(d['kind'] as String?),
        enabled: d['enabled'] != false,
        startAt: _time(d['startAt']),
        endAt: _time(d['endAt']),
        coins: (d['coins'] as num?)?.toInt() ?? 0,
        items: _strings(d['items']),
        cooldownHours: (d['cooldownHours'] as num?)?.toInt() ?? 0,
        title: _texts(d['title']),
        desc: _texts(d['desc']),
      );

  Map<String, dynamic> toDoc() => {
        'kind': kind.name,
        'enabled': enabled,
        'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
        'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
        'coins': coins,
        'items': items,
        'cooldownHours': cooldownHours,
        'title': title,
        'desc': desc,
      };

  static Map<String, String> _texts(Object? v) => {
        if (v is Map)
          for (final e in v.entries)
            if (e.value is String) '${e.key}': e.value as String,
        if (v is String) 'ko': v,
      };
}

class Promotions {
  /// 앱에 기본으로 들어 있는 이벤트 — 서버가 없어도 돈다(기간이 있는 건 그 기간에만 보인다).
  /// 같은 id 가 promos 컬렉션에 있으면 그쪽(운영자가 고친 값)이 이긴다.
  /// 기간은 UTC — 어느 나라에서나 같은 순간에 열리고 닫힌다.
  /// 설명은 한 줄에 다 보이게 짧게(이벤트 화면이 제목 + 설명 한 줄 + 버튼). 4개 언어(ko·en·ja·zh) 모두 채운다
  static final List<Promotion> builtIn = [
    const Promotion(
      id: 'welcome_pack',
      kind: PromoKind.welcome,
      coins: 300,
      items: ['skin_cloud'],
      title: {'ko': '환영 선물', 'en': 'Welcome gift', 'zh': '欢迎礼包', 'ja': 'ようこそギフト'},
      desc: {'ko': '코인 300 + 구름 스킨', 'en': '300 coins + Cloud skin', 'zh': '300 金币 + 云朵皮肤', 'ja': 'コイン300 + くもスキン'},
    ),
    // 글로벌 출시 기념 — 출시 첫 달
    Promotion(
      id: 'global_launch_2026',
      kind: PromoKind.bonus,
      coins: 500,
      startAt: DateTime.utc(2026, 9, 25),
      endAt: DateTime.utc(2026, 10, 31, 23, 59, 59),
      title: {'ko': '글로벌 출시 기념', 'en': 'Global launch party', 'zh': '全球上线庆典', 'ja': 'グローバルリリース記念'},
      desc: {'ko': '출시 기념 코인 500', 'en': '500 coins to celebrate', 'zh': '上线纪念 500 金币', 'ja': 'リリース記念 コイン500'},
    ),
    // 주간 선물 — 매주 돌아오게(복귀 동기)
    const Promotion(
      id: 'weekly_gift',
      kind: PromoKind.bonus,
      coins: 100,
      cooldownHours: 24 * 7,
      title: {'ko': '주간 선물', 'en': 'Weekly gift', 'zh': '每周礼物', 'ja': '週間ギフト'},
      desc: {'ko': '매주 한 번 코인 100', 'en': '100 coins every week', 'zh': '每周一次 100 金币', 'ja': '毎週1回 コイン100'},
    ),
    // 할로윈 — 세계 공통 시즌
    Promotion(
      id: 'halloween_2026',
      kind: PromoKind.bonus,
      coins: 300,
      items: ['trail_flame'],
      startAt: DateTime.utc(2026, 10, 24),
      endAt: DateTime.utc(2026, 11, 2, 23, 59, 59),
      title: {'ko': '할로윈 파티', 'en': 'Halloween party', 'zh': '万圣节派对', 'ja': 'ハロウィンパーティー'},
      desc: {'ko': '코인 300 + 불꽃 잔상', 'en': '300 coins + Flame trail', 'zh': '300 金币 + 火焰拖尾', 'ja': 'コイン300 + 炎の軌跡'},
    ),
    // 연말 — 크리스마스 ~ 새해
    Promotion(
      id: 'holiday_2026',
      kind: PromoKind.bonus,
      coins: 500,
      items: ['trail_snow'],
      startAt: DateTime.utc(2026, 12, 20),
      endAt: DateTime.utc(2027, 1, 4, 23, 59, 59),
      title: {'ko': '연말 선물', 'en': 'Holiday gift', 'zh': '节日礼物', 'ja': 'ホリデーギフト'},
      desc: {'ko': '코인 500 + 눈송이 잔상', 'en': '500 coins + Snow trail', 'zh': '500 金币 + 雪花拖尾', 'ja': 'コイン500 + 雪の軌跡'},
    ),
    // 공식 SNS 코드 안내 — 보상은 코드마다(백오피스 > 이벤트 코드)
    const Promotion(
      id: 'sns_codes',
      kind: PromoKind.code,
      title: {'ko': '공식 SNS 코드', 'en': 'Official SNS codes', 'zh': '官方社媒兑换码', 'ja': '公式SNSコード'},
      desc: {'ko': 'SNS에서 코드 찾아 입력', 'en': 'Find codes on our socials', 'zh': '在社媒找兑换码', 'ja': 'SNSのコードを入力'},
    ),
    const Promotion(
      id: 'share_daily',
      kind: PromoKind.share,
      coins: 50,
      cooldownHours: 24,
      title: {'ko': '친구에게 자랑하기', 'en': 'Brag to a friend', 'zh': '向朋友炫耀', 'ja': '友だちに自慢'},
      desc: {'ko': '기록 공유하면 매일 코인 50', 'en': 'Share your record — 50 coins daily', 'zh': '分享纪录 每天 50 金币', 'ja': '記録をシェアで毎日コイン50'},
    ),
  ];

  /// 서버 문서 → 이벤트. 받은 수 카운터(`claims`)만 든 문서는 앱 기본 이벤트를 그대로 쓴다 —
  /// 기본 이벤트를 누가 받으면 claims 만 있는 문서가 생기는데, 그걸 그대로 읽으면 제목·보상이 빈 이벤트가
  /// 기본값을 덮어 버린다. 운영자가 백오피스에서 저장한 문서(kind 가 있다)만 정의로 친다. 해당 없으면 null
  static Promotion? fromServer(String id, Map<String, dynamic> d) {
    if (d['kind'] != null) return Promotion.fromDoc(id, d);
    for (final p in builtIn) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 진행 중인 것만(켜짐 + 기간 안)
  static List<Promotion> live(List<Promotion> all) => all.where((p) => p.isLive).toList();
}

// ── 이벤트 코드 ──────────────────────────────────────────────

/// 코드 상태 — 쓸 수 있나, 못 쓰면 왜
enum PromoCodeStatus { open, disabled, notStarted, expired, exhausted }

/// 이벤트 코드 한 개 — promo_codes/{code}. 코드마다 보상이 따로다
@immutable
class PromoCode {
  /// 문서 id — 대문자·숫자 4~20자([PromoCodes.normalize])
  final String code;

  /// 어디에 뿌린 코드인가(insta_launch, youtube_abc …) — 채널별 유입을 가르는 이름
  final String campaign;

  /// 운영 메모(앱에는 안 보인다)
  final String note;

  final int coins;
  final List<String> items;
  final bool enabled;
  final DateTime? startAt;
  final DateTime? endAt;

  /// 전체 사용 한도(선착순) — 0 = 무제한. 한 사람은 늘 한 번
  final int maxUses;

  /// 지금까지 쓴 사람 수(사용할 때 +1)
  final int uses;
  final DateTime? createdAt;

  const PromoCode({
    required this.code,
    this.campaign = '',
    this.note = '',
    this.coins = 0,
    this.items = const [],
    this.enabled = true,
    this.startAt,
    this.endAt,
    this.maxUses = 0,
    this.uses = 0,
    this.createdAt,
  });

  bool get isEmptyReward => coins <= 0 && items.isEmpty;

  /// 남은 수(무제한이면 null)
  int? get remaining => maxUses <= 0 ? null : max(0, maxUses - uses);

  PromoCodeStatus status([DateTime? now]) {
    final t = now ?? DateTime.now();
    if (!enabled) return PromoCodeStatus.disabled;
    if (startAt != null && t.isBefore(startAt!)) return PromoCodeStatus.notStarted;
    if (endAt != null && t.isAfter(endAt!)) return PromoCodeStatus.expired;
    if (maxUses > 0 && uses >= maxUses) return PromoCodeStatus.exhausted;
    return PromoCodeStatus.open;
  }

  factory PromoCode.fromDoc(String code, Map<String, dynamic> d) => PromoCode(
        code: code,
        campaign: (d['campaign'] as String? ?? '').trim(),
        note: (d['note'] as String? ?? '').trim(),
        coins: (d['coins'] as num?)?.toInt() ?? 0,
        items: _strings(d['items']),
        enabled: d['enabled'] != false,
        startAt: _time(d['startAt']),
        endAt: _time(d['endAt']),
        maxUses: (d['maxUses'] as num?)?.toInt() ?? 0,
        uses: (d['uses'] as num?)?.toInt() ?? 0,
        createdAt: _time(d['createdAt']),
      );

  /// 저장용(uses·createdAt 은 빼고 — 새로 만들 때만 [PromoCodes.createDoc] 가 넣는다)
  Map<String, dynamic> toDoc() => {
        'campaign': campaign,
        'note': note,
        'coins': coins,
        'items': items,
        'enabled': enabled,
        'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
        'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
        'maxUses': maxUses,
      };

  PromoCode copyWith({bool? enabled}) => PromoCode(
        code: code,
        campaign: campaign,
        note: note,
        coins: coins,
        items: items,
        enabled: enabled ?? this.enabled,
        startAt: startAt,
        endAt: endAt,
        maxUses: maxUses,
        uses: uses,
        createdAt: createdAt,
      );
}

class PromoCodes {
  /// 코드 정의(관리자가 만든다) — promo_codes/{code}
  static const String collection = 'promo_codes';

  /// 내가 쓴 코드 — users/{uid}/codes/{code}
  static const String usedCollection = 'codes';

  static const int minLength = 4;
  static const int maxLength = 20;
  static final RegExp _format = RegExp('^[A-Z0-9]{$minLength,$maxLength}\$');

  /// 헷갈리는 글자(0·O·1·I·L)를 뺀 글자 — 자동 생성용
  static const String alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// 입력 정리 — 대문자로, 공백·하이픈 제거("zon-ber 7" → "ZONBER7")
  static String normalize(String input) => input.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');

  static bool isValidFormat(String code) => _format.hasMatch(code);

  /// 무작위 코드 — [prefix](대문자·숫자만 남긴다) + [length] 글자
  static String generate({String prefix = '', int length = 6, Random? random}) {
    final r = random ?? Random.secure();
    final head = normalize(prefix).replaceAll(RegExp('[^A-Z0-9]'), '');
    final body = List.generate(length, (_) => alphabet[r.nextInt(alphabet.length)]).join();
    return head + body;
  }

  /// 새 코드 문서 — 사용 수 0, 서버 시각
  static Map<String, dynamic> createDoc(PromoCode c) => {
        ...c.toDoc(),
        'uses': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// 코드 입력 결과
enum RedeemResult { ok, guest, invalid, already, disabled, notStarted, expired, exhausted, error }

RedeemResult _resultOf(PromoCodeStatus s) => switch (s) {
      PromoCodeStatus.open => RedeemResult.ok,
      PromoCodeStatus.disabled => RedeemResult.disabled,
      PromoCodeStatus.notStarted => RedeemResult.notStarted,
      PromoCodeStatus.expired => RedeemResult.expired,
      PromoCodeStatus.exhausted => RedeemResult.exhausted,
    };

// ── 받은 기록 ────────────────────────────────────────────────

class PromoService {
  static const String collection = 'promos';
  static const _kClaims = 'promo_claims'; // {promoId: epochMillis}
  static const _kSynced = 'promo_synced';

  static List<Promotion> _cache = const [];
  static DateTime? _cacheAt;

  /// 지금 로그인한 회원의 uid — 게스트·로그아웃·Firebase 없음이면 null
  static String? get _uid {
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || AuthService.isGuest) ? null : u.uid;
    } catch (_) {
      return null; // Firebase 가 없는 환경(테스트 등)
    }
  }

  /// 진행 중인 이벤트 — 서버 목록 + 앱 기본 목록(같은 id 는 서버가 이긴다).
  /// 10분 캐시. 서버를 못 읽으면 기본 목록만 돌려준다.
  static Future<List<Promotion>> load({bool refresh = false}) async {
    if (!refresh && _cacheAt != null && DateTime.now().difference(_cacheAt!) < const Duration(minutes: 10)) {
      return _cache;
    }
    final byId = {for (final p in Promotions.builtIn) p.id: p};
    try {
      final snap = await FirebaseFirestore.instance.collection(collection).get();
      for (final d in snap.docs) {
        final p = Promotions.fromServer(d.id, d.data());
        if (p != null) byId[d.id] = p;
      }
    } catch (e) {
      debugPrint('promos load failed: $e');
    }
    _cache = Promotions.live(byId.values.toList())
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    _cacheAt = DateTime.now();
    return _cache;
  }

  static void invalidate() => _cacheAt = null;

  // ── 받은 기록(기기 + 계정) ──

  static Future<Map<String, int>> _claims() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kClaims);
    if (raw == null) return {};
    try {
      return {for (final e in (jsonDecode(raw) as Map).entries) '${e.key}': (e.value as num).toInt()};
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setClaims(Map<String, int> m) async =>
      (await SharedPreferences.getInstance()).setString(_kClaims, jsonEncode(m));

  /// 로그인한 계정이 이미 받은 것을 기기로 가져온다 — 다시 깔아도 두 번 받지 못하게.
  /// 계정당 한 번만 읽는다(로그인 직후 UserProfileManager.syncProfile 에서 부른다)
  static Future<void> syncFromRemote() async {
    final uid = _uid;
    if (uid == null) return;
    final p = await SharedPreferences.getInstance();
    if (p.getString(_kSynced) == uid) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).collection(collection).get();
      final claims = await _claims();
      for (final d in snap.docs) {
        final at = _time(d.data()['at'])?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
        claims[d.id] = at > (claims[d.id] ?? 0) ? at : claims[d.id]!;
      }
      await _setClaims(claims);
      await p.setString(_kSynced, uid);
    } catch (e) {
      debugPrint('promo sync failed: $e');
    }
  }

  /// 기기에서 받은 기록을 지운다(로그아웃·탈퇴)
  static Future<void> clearLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kClaims);
    await p.remove(_kSynced);
    invalidate();
  }

  /// 마지막으로 받은 때(못 받았으면 null)
  static Future<DateTime?> claimedAt(Promotion promo) async {
    final at = (await _claims())[promo.id];
    return at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
  }

  /// 아직 안 받은 상태인가 — 진행 중 + (평생 한 번이면 아직 안 받음 / 쿨다운이면 시간이 지남).
  /// **화면 표시용**이라 게스트도 true 다 — 게스트는 눌렀을 때 로그인 안내를 받는다(코인·상점과 같은 방식).
  /// 코드 안내 카드는 받을 게 없어서 늘 false
  static Future<bool> isFresh(Promotion promo) async {
    if (!promo.isLive || promo.kind == PromoKind.code) return false;
    final at = await claimedAt(promo);
    if (at == null) return true;
    if (promo.cooldownHours <= 0) return false;
    return DateTime.now().difference(at).inHours >= promo.cooldownHours;
  }

  /// 지금 진짜로 받을 수 있나(게스트는 못 받는다)
  static Future<bool> canClaim(Promotion promo) async => !AuthService.isGuest && await isFresh(promo);

  /// 보상 지급 — 받았으면 true. 코인·아이템을 주고 기기·계정에 기록한다
  static Future<bool> claim(Promotion promo) async {
    if (!await canClaim(promo)) return false;
    final now = DateTime.now();
    final claims = await _claims();
    claims[promo.id] = now.millisecondsSinceEpoch;
    await _setClaims(claims); // 먼저 막고 준다(두 번 눌러도 한 번)

    await _grant(promo.coins, promo.items);
    await _record(promo, now);
    return true;
  }

  static Future<void> _grant(int coins, List<String> items) async {
    if (coins > 0) await CoinStore.add(coins);
    for (final id in items) {
      await CoinStore.grant(id);
    }
  }

  /// 계정에 남기기 — 백오피스가 수령 수를 본다(promos/{id}.claims 는 +1)
  static Future<void> _record(Promotion promo, DateTime at) async {
    final uid = _uid;
    if (uid == null) return;
    late final FirebaseFirestore db;
    try {
      db = FirebaseFirestore.instance;
      await db.collection('users').doc(uid).collection(collection).doc(promo.id).set({
        'at': Timestamp.fromDate(at),
        'coins': promo.coins,
        'items': promo.items,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('promo record failed: $e');
    }
    try {
      await db.collection(collection).doc(promo.id).set({'claims': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('promo counter failed: $e'); // 앱 기본 이벤트는 문서가 없을 수 있다
    }
  }

  /// 이벤트 코드 사용 — 성공하면 (ok, 그 코드) 이고 보상은 이미 들어가 있다.
  /// 트랜잭션: 코드 읽기 → 상태 검사 → 내 사용 기록 생성 + 사용 수 +1. 규칙이 같은 조건을 서버에서 다시 본다
  static Future<(RedeemResult, PromoCode?)> redeem(String input) async {
    final code = PromoCodes.normalize(input);
    if (!PromoCodes.isValidFormat(code)) return (RedeemResult.invalid, null);
    if (AuthService.isGuest) return (RedeemResult.guest, null);
    final uid = _uid;
    if (uid == null) return (RedeemResult.guest, null);

    final db = FirebaseFirestore.instance;
    final ref = db.collection(PromoCodes.collection).doc(code);
    final mine = db.collection('users').doc(uid).collection(PromoCodes.usedCollection).doc(code);
    try {
      final (result, pc) = await db.runTransaction<(RedeemResult, PromoCode?)>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return (RedeemResult.invalid, null);
        final pc = PromoCode.fromDoc(code, snap.data()!);
        final st = pc.status();
        if (st != PromoCodeStatus.open) return (_resultOf(st), pc);
        if ((await tx.get(mine)).exists) return (RedeemResult.already, pc);
        tx.set(mine, {
          'code': code,
          'campaign': pc.campaign,
          'coins': pc.coins,
          'items': pc.items,
          'at': FieldValue.serverTimestamp(),
        });
        tx.update(ref, {'uses': FieldValue.increment(1)});
        return (RedeemResult.ok, pc);
      });
      if (result == RedeemResult.ok && pc != null) await _grant(pc.coins, pc.items);
      return (result, pc);
    } on FirebaseException catch (e) {
      // 규칙이 막음 = 그 사이 한도가 찼거나 이미 썼다 — 한 번 더 읽어 이유를 가린다
      debugPrint('redeem failed: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        try {
          if ((await mine.get()).exists) return (RedeemResult.already, null);
          final snap = await ref.get();
          if (snap.exists) {
            final pc = PromoCode.fromDoc(code, snap.data()!);
            final st = pc.status();
            if (st != PromoCodeStatus.open) return (_resultOf(st), pc);
          }
        } catch (_) {}
      }
      return (RedeemResult.error, null);
    } catch (e) {
      debugPrint('redeem failed: $e');
      return (RedeemResult.error, null);
    }
  }
}
