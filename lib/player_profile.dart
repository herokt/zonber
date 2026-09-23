import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'avatar.dart';
import 'badges.dart';

// ─────────────────────────────────────────────────────────────
// 플레이어 프로필 — 누구나 볼 수 있는 한 사람의 공개 정보 한 벌.
// 내 프로필과 남의 프로필이 같은 클래스다(랭킹에서 이름을 누르면 남의 것을 연다).
//
// 출처는 users/{uid} 문서 하나다(firestore.rules — 읽기는 공개, 쓰기는 본인만).
//   아바타 equipped·characterId · 닉네임 · 국가 · 가입일 createdAt · 최근 접속 lastUpdated ·
//   보유 뱃지 achievements · 스테이지별 최고 기록 bestTimes · 누적 판 수·시간
// 비공개(이메일 등)는 users/{uid}/private/account 에 따로 있고 여기 들어오지 않는다.
// ─────────────────────────────────────────────────────────────

@immutable
class PlayerProfile {
  final String uid;
  final String nickname;

  /// 국가 코드(예: KR) — 국기는 CountryChip 이 그린다
  final String flag;
  final String countryName;
  final Avatar avatar;

  /// 가입일 · 최근 접속(기록을 올리거나 프로필을 저장할 때 갱신된다)
  final DateTime? joinedAt;
  final DateTime? lastSeenAt;

  /// 보유 뱃지 키(badges.dart) — 순서는 저장된 그대로
  final List<String> badgeKeys;

  /// 존 id → 그 존 최고 기록(초)
  final Map<String, double> bestTimes;

  final int totalGames;
  final double totalPlayTime;

  const PlayerProfile({
    required this.uid,
    this.nickname = '',
    this.flag = '',
    this.countryName = '',
    this.avatar = Avatar.fallback,
    this.joinedAt,
    this.lastSeenAt,
    this.badgeKeys = const [],
    this.bestTimes = const {},
    this.totalGames = 0,
    this.totalPlayTime = 0,
  });

  /// 보유 뱃지 — 지금 정의에 없는 옛 키는 버린다
  List<BadgeDef> get badges => [
        for (final k in badgeKeys)
          if (Badges.byKey(k) case final b?) b,
      ];

  /// 대표 뱃지(가장 높은 등급) — 이름 옆·아바타 테두리에 쓴다
  BadgeDef? get topBadge => Badges.best(badgeKeys);

  double? bestOf(String worldId) => bestTimes[worldId];

  bool get isEmpty => nickname.isEmpty && badgeKeys.isEmpty && bestTimes.isEmpty;

  factory PlayerProfile.fromUserDoc(String uid, Map<String, dynamic> d) => PlayerProfile(
        uid: uid,
        nickname: (d['nickname'] as String?) ?? '',
        flag: (d['flag'] as String?) ?? '',
        countryName: (d['countryName'] as String?) ?? '',
        avatar: Avatar.fromUserDoc(d),
        joinedAt: _time(d['createdAt']),
        lastSeenAt: _time(d['lastUpdated']),
        badgeKeys: (d['achievements'] as List?)?.whereType<String>().toList() ?? const [],
        bestTimes: {
          if (d['bestTimes'] is Map)
            for (final e in (d['bestTimes'] as Map).entries)
              if (e.key is String && e.value is num) e.key as String: (e.value as num).toDouble(),
        },
        totalGames: (d['totalGamesPlayed'] as num?)?.toInt() ?? 0,
        totalPlayTime: (d['totalPlayTime'] as num?)?.toDouble() ?? 0,
      );

  static DateTime? _time(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => null,
      };
}

/// 남의 프로필 읽기 — users/{uid} 는 누구나 읽을 수 있다(firestore.rules).
/// 랭킹에서 여러 번 눌러도 다시 읽지 않게 잠깐 담아 둔다.
class PlayerProfileService {
  static final Map<String, _Cached> _cache = {};
  static const Duration _ttl = Duration(minutes: 5);

  static Future<PlayerProfile?> fetch(String uid, {bool refresh = false}) async {
    if (uid.isEmpty) return null;
    final hit = _cache[uid];
    if (!refresh && hit != null && DateTime.now().difference(hit.at) < _ttl) return hit.profile;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final profile = PlayerProfile.fromUserDoc(uid, doc.data() ?? const {});
      _cache[uid] = _Cached(profile, DateTime.now());
      return profile;
    } catch (e) {
      debugPrint('player profile fetch failed: $e');
      return null;
    }
  }

  static void clearCache() => _cache.clear();
}

class _Cached {
  final PlayerProfile profile;
  final DateTime at;
  const _Cached(this.profile, this.at);
}
