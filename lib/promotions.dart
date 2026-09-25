import 'dart:convert';

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
// 둘 다 같은 [Promotion] 이고, 같은 화면(pages/promo_sheet.dart)에서 같은 방식으로 받는다.
//
// 받은 기록: 기기(SharedPreferences) + 계정(users/{uid}/promos/{promoId}).
//   기기를 바꾸거나 다시 깔아도 계정 기록을 먼저 읽어 두 번 받지 못하게 한다.
// 보상은 코인·아이템뿐이라 랭킹에 영향이 없다(docs/SHOP.md 의 코인 정책과 같은 자리).
// ─────────────────────────────────────────────────────────────

/// 이벤트 종류 — 받는 방법이 다를 뿐, 보상 주는 길은 하나다
enum PromoKind {
  /// 처음 한 번 받는 환영 보상(신규 유입자용)
  welcome,

  /// 기간 중 한 번 받는 보상(공지·홍보용)
  bonus,

  /// 코드를 입력해야 받는 보상(SNS·커뮤니티에 코드를 뿌린다)
  code,

  /// 친구에게 자랑(문구 복사)하면 받는 보상 — 하루 한 번
  share,
}

PromoKind _kindOf(String? s) => switch (s) {
      'welcome' => PromoKind.welcome,
      'code' => PromoKind.code,
      'share' => PromoKind.share,
      _ => PromoKind.bonus,
    };

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

  /// kind == code 일 때 입력해야 하는 코드(대소문자·앞뒤 공백 무시)
  final String code;

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
    this.code = '',
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
      (m[lang]?.trim().isNotEmpty == true) ? m[lang]! : (m['ko'] ?? m['en'] ?? '');

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
        items: (d['items'] as List?)?.whereType<String>().toList() ?? const [],
        code: (d['code'] as String? ?? '').trim(),
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
        'code': code,
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

  static DateTime? _time(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}

class Promotions {
  /// 앱에 기본으로 들어 있는 이벤트 — 서버가 없어도 돈다.
  /// 같은 id 가 promos 컬렉션에 있으면 그쪽(운영자가 고친 값)이 이긴다.
  static const List<Promotion> builtIn = [
    Promotion(
      id: 'welcome_pack',
      kind: PromoKind.welcome,
      coins: 300,
      items: ['skin_cloud'],
      title: {'ko': '환영 선물', 'en': 'Welcome gift', 'zh': '欢迎礼包', 'ja': 'ようこそギフト'},
      desc: {
        'ko': '처음 온 존버에게 — 코인 300 + 구름 스킨',
        'en': 'For your first zone — 300 coins + Cloud skin',
        'zh': '首次登录礼 — 300 金币 + 云朵皮肤',
        'ja': 'はじめての方へ — コイン300 + くもスキン',
      },
    ),
    Promotion(
      id: 'share_daily',
      kind: PromoKind.share,
      coins: 50,
      cooldownHours: 24,
      title: {'ko': '친구에게 자랑하기', 'en': 'Brag to a friend', 'zh': '向朋友炫耀', 'ja': '友だちに自慢'},
      desc: {
        'ko': '내 기록을 복사해서 공유하면 코인 50 (하루 한 번)',
        'en': 'Copy your record and share it — 50 coins once a day',
        'zh': '复制你的纪录分享 — 每天 50 金币',
        'ja': '記録をコピーしてシェア — 1日1回 コイン50',
      },
    ),
  ];

  /// 진행 중인 것만(켜짐 + 기간 안)
  static List<Promotion> live(List<Promotion> all) => all.where((p) => p.isLive).toList();
}

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
        byId[d.id] = Promotion.fromDoc(d.id, d.data());
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
        final at = Promotion._time(d.data()['at'])?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
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
  /// **화면 표시용**이라 게스트도 true 다 — 게스트는 눌렀을 때 로그인 안내를 받는다(코인·상점과 같은 방식)
  static Future<bool> isFresh(Promotion promo) async {
    if (!promo.isLive) return false;
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

    if (promo.coins > 0) await CoinStore.add(promo.coins);
    for (final id in promo.items) {
      await CoinStore.grant(id);
    }
    await _record(promo, now);
    return true;
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

  /// 코드로 찾기 — 맞는 코드가 없으면 null
  static Future<Promotion?> byCode(String input) async {
    final code = input.trim().toUpperCase();
    if (code.isEmpty) return null;
    for (final p in await load()) {
      if (p.kind == PromoKind.code && p.code.trim().toUpperCase() == code) return p;
    }
    return null;
  }
}
