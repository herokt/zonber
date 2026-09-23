import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../badges.dart';
import '../gear.dart';
import '../translations.dart';
import '../world_config.dart';

// ─────────────────────────────────────────────────────────────
// 백오피스 카탈로그 — 게임 데이터의 한글 이름(스테이지·캐릭터·아이템·뱃지)과 포맷 함수, 판(run) 한 줄 모델.
// 장비 목록은 gear.dart, 뱃지 정의는 badges.dart, 뱃지 이름은 translations.dart(ko) 에서 읽는다.
// ─────────────────────────────────────────────────────────────

// ── 스테이지 ── (WorldData.worlds 3개가 전부. 옛 존 체계 랭킹은 더 다루지 않는다)
class BoStage {
  final String id; // world id = 랭킹 mapId
  final int no;
  final String name;
  final Color color;
  final String stat; // 추가 기록 키
  const BoStage(this.id, this.no, this.name, this.color, this.stat);

  String get label => 'ZONE $no $name';
}

const Map<String, String> _kStageNamesKo = {'cyber': '갤럭시', 'dodgeball': '피구', 'keeper': '골키퍼'};
const Map<String, String> _kStageStats = {'cyber': 'graze', 'dodgeball': 'close_dodge', 'keeper': 'save_streak'};

final List<BoStage> kStages = [
  for (int i = 0; i < WorldData.worlds.length; i++)
    BoStage(
      WorldData.worlds[i].rankingMapId,
      i + 1,
      _kStageNamesKo[WorldData.worlds[i].id] ?? appTranslations['ko']?[WorldData.worlds[i].nameKey] ?? WorldData.worlds[i].displayName,
      WorldData.worlds[i].accent,
      _kStageStats[WorldData.worlds[i].id] ?? '',
    ),
];

BoStage? stageById(String? id) {
  for (final s in kStages) {
    if (s.id == id) return s;
  }
  return null;
}

BoStage? stageByNo(int? no) {
  for (final s in kStages) {
    if (s.no == no) return s;
  }
  return null;
}

String stageLabel(String? mapId) => stageById(mapId)?.label ?? (mapId ?? '-');
Color stageColor(String? mapId) => stageById(mapId)?.color ?? const Color(0xFF9CA3AF);

const Map<String, String> kStatNames = {
  'graze': '근접 회피',
  'close_dodge': '아슬 회피',
  'save_streak': '연속 선방',
};
String statName(String? k) => kStatNames[k] ?? (k ?? '');

// ── 캐릭터 ──
const Map<String, String> kCharNames = {
  'neon_green': '민트',
  'electric_blue': '잽',
  'plasma_purple': '루나',
  'cyber_red': '블레이즈',
  'solar_gold': '써니',
  'void_dark': '레이스',
};
const Map<String, Color> kCharColors = {
  'neon_green': Color(0xFF3FBF97),
  'electric_blue': Color(0xFF3B8EF0),
  'plasma_purple': Color(0xFFA66BF2),
  'cyber_red': Color(0xFFF2503D),
  'solar_gold': Color(0xFFFFC928),
  'void_dark': Color(0xFF5B6272),
};
String charName(String? id) => kCharNames[id] ?? (id == null || id.isEmpty ? '-' : id);
Color charColor(String? id) => kCharColors[id] ?? const Color(0xFFD1D5DB);

// ── 장비·꾸미기 이름 ──
const Map<String, String> kGearNames = {
  'wings_white': '천사 날개', 'wings_star': '별빛 날개', 'wings_gold': '황금 날개',
  'rocket_red': '로켓 부츠', 'rocket_plasma': '플라즈마 로켓',
  'band_red': '빨간 머리띠', 'band_blue': '파란 머리띠', 'band_flame': '불꽃 머리띠',
  'sneakers_white': '운동화', 'sneakers_neon': '형광 운동화',
  'cap_blue': '파란 모자', 'cap_red': '빨간 모자',
  'gloves_basic': '키퍼 장갑', 'gloves_pro': '프로 장갑', 'gloves_gold': '황금 장갑',
  'boots_black': '축구화', 'boots_orange': '형광 축구화',
  'antenna_basic': '우주 헤드셋', 'goggles_space': '별빛 고글', 'helmet_bubble': '버블 헬멧',
  'mitts_space': '우주 장갑', 'gauntlet_neon': '네온 건틀릿',
  'wings_bat': '박쥐 날개', 'wings_mech': '기계 날개', 'rocket_chrome': '크롬 로켓',
  'band_stripe': '줄무늬 머리띠', 'wrist_white': '손목 밴드', 'wrist_red': '빨간 손목 밴드',
  'wrist_rainbow': '무지개 손목 밴드', 'sneakers_hightop': '하이탑', 'sneakers_gold': '황금 운동화',
  'cap_black': '검은 모자', 'beanie_stripe': '줄무늬 털모자', 'gloves_fire': '불꽃 장갑',
  'boots_mint': '민트 축구화', 'boots_white': '흰 축구화',
};

/// 꾸미기(cosmetics.dart 의 id 순서·가격)
class BoCosmetic {
  final String id;
  final String kind; // skin | trail | aura
  final String name;
  final int price;
  const BoCosmetic(this.id, this.kind, this.name, this.price);
}

const List<BoCosmetic> kCosmetics = [
  BoCosmetic('skin_none', 'skin', '기본', 0),
  BoCosmetic('skin_silver', 'skin', '실버', 400),
  BoCosmetic('skin_candy', 'skin', '사탕', 450),
  BoCosmetic('skin_ice', 'skin', '얼음', 500),
  BoCosmetic('skin_gold', 'skin', '골드', 650),
  BoCosmetic('skin_lava', 'skin', '용암', 700),
  BoCosmetic('skin_galaxy', 'skin', '은하', 750),
  BoCosmetic('skin_rainbow', 'skin', '무지개', 900),
  BoCosmetic('trail_basic', 'trail', '기본', 0),
  BoCosmetic('trail_sparkle', 'trail', '별가루', 200),
  BoCosmetic('trail_bubble', 'trail', '비눗방울', 250),
  BoCosmetic('trail_heart', 'trail', '하트', 300),
  BoCosmetic('trail_flame', 'trail', '불꽃', 350),
  BoCosmetic('trail_rainbow', 'trail', '무지개', 500),
  BoCosmetic('aura_none', 'aura', '없음', 0),
  BoCosmetic('aura_ring', 'aura', '네온 링', 200),
  BoCosmetic('aura_orbit', 'aura', '궤도 위성', 350),
  BoCosmetic('aura_electric', 'aura', '번개', 450),
  BoCosmetic('aura_halo', 'aura', '천사 고리', 500),
  BoCosmetic('aura_crown', 'aura', '왕관', 700),
];

const Map<String, String> kCosmeticKindNames = {'skin': '몸통 스킨', 'trail': '트레일', 'aura': '오라'};

const Map<GearSlot, String> kSlotNames = {
  GearSlot.head: '머리',
  GearSlot.hands: '손',
  GearSlot.feet: '발',
  GearSlot.back: '등',
};

BoCosmetic? cosmeticById(String id) {
  for (final c in kCosmetics) {
    if (c.id == id) return c;
  }
  return null;
}

/// 아이템 id → 한글 이름 (모르면 id 그대로)
String itemName(String id) {
  if (id.startsWith('char_')) return '캐릭터 ${charName(id.substring(5))}';
  final g = Gear.byId(id);
  if (g != null) return kGearNames[id] ?? id;
  final c = cosmeticById(id);
  if (c != null) return c.name;
  return id;
}

/// 아이템 분류 — 'char' | 'gear:{zone}' | 'skin' | 'trail' | 'aura' | 'etc'
String itemGroup(String id) {
  if (id.startsWith('char_')) return 'char';
  final g = Gear.byId(id);
  if (g != null) return 'gear:${g.zone}';
  final c = cosmeticById(id);
  if (c != null) return c.kind;
  return 'etc';
}

String itemGroupLabel(String group) {
  if (group == 'char') return '캐릭터';
  if (group.startsWith('gear:')) return '장비 · ${stageLabel(group.substring(5))}';
  return kCosmeticKindNames[group] ?? '기타';
}

/// 지급 가능한 전체 아이템(분류 순서대로)
List<String> allGrantableItems() => [
      for (final c in kCharNames.keys) 'char_$c',
      for (final g in Gear.all) g.id,
      for (final c in kCosmetics) c.id,
    ];

// ── 뱃지 ──
const Map<BadgeCategory, String> kBadgeCategoryNames = {
  BadgeCategory.survival: '생존',
  BadgeCategory.stage: '스테이지',
  BadgeCategory.skill: '기술',
  BadgeCategory.career: '경력',
  BadgeCategory.ranking: '랭킹',
  BadgeCategory.collection: '수집',
  BadgeCategory.daily: '출석·미션',
  BadgeCategory.special: '특별',
};

const List<String> kTierNames = ['', '브론즈', '실버', '골드', '레전드'];
String tierName(int t) => t >= 1 && t < kTierNames.length ? kTierNames[t] : '-';

/// 뱃지 한글 이름 — 번역이 없으면 키
String badgeName(String key) {
  final n = appTranslations['ko']?[key];
  return (n == null || n.isEmpty) ? key : n;
}

/// 뱃지 한글 설명 — 없으면 ''
String badgeDesc(String key) => appTranslations['ko']?['${key}_desc'] ?? '';

/// users.achievements → 뱃지 키 목록
List<String> badgeKeysOf(Map<String, dynamic>? d) {
  final a = d?['achievements'];
  if (a is! List) return const [];
  return a.map((e) => '$e').toSet().toList();
}

/// 정의된 뱃지 중 보유한 수
int badgeCountOf(Map<String, dynamic>? d) {
  final keys = badgeKeysOf(d).toSet();
  return Badges.all.where((b) => keys.contains(b.key)).length;
}

BadgeDef? bestBadgeOf(Map<String, dynamic>? d) => Badges.best(badgeKeysOf(d).toSet());

// ── 포맷 ──
String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime? d) => d == null ? '-' : '${d.year}-${two(d.month)}-${two(d.day)}';
String fmtDateTime(DateTime? d) =>
    d == null ? '-' : '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
String fmtDateTimeSec(DateTime? d) => d == null ? '-' : '${fmtDateTime(d)}:${two(d.second)}';
String fmtMd(DateTime d) => '${d.month}/${d.day}';

String fmtNum(num? n) {
  if (n == null) return '-';
  final neg = n < 0;
  final s = n.abs().round().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return neg ? '-$b' : b.toString();
}

String fmtSec(num? s, {int digits = 3}) => s == null ? '-' : '${s.toDouble().toStringAsFixed(digits)}초';

String fmtPct(num part, num whole, {int digits = 1}) =>
    whole <= 0 ? '0%' : '${(part / whole * 100).toStringAsFixed(digits)}%';

/// 초 → "3시간 12분" 식
String fmtDuration(num? sec) {
  if (sec == null) return '-';
  final s = sec.round();
  if (s < 60) return '$s초';
  final m = s ~/ 60;
  if (m < 60) return '$m분 ${s % 60}초';
  final h = m ~/ 60;
  return '$h시간 ${m % 60}분';
}

String timeAgo(DateTime? d) {
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 30) return '${diff.inDays}일 전';
  return fmtDate(d);
}

DateTime? tsOf(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

int intOf(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
double dblOf(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

DateTime startOfToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

// ── 유저 ──
String nickOf(Map<String, dynamic>? d) {
  final n = (d?['nickname'] as String? ?? '').trim();
  return n.isEmpty ? '(닉네임 없음)' : n;
}

String flagOf(Map<String, dynamic>? d) => (d?['flag'] as String? ?? '').trim();

String providerLabel(String p) => p.isEmpty ? '-' : p;

// ── 플레이 기록(runs) 한 줄 ──
class RunRow {
  final String id;
  final String uid;
  final int stage;
  final String mapId;
  final double time;
  final int level;
  final String stat;
  final int statCount;
  final int coins;
  final int bonus;
  final int revive;
  final String character;
  final List<String> gear;
  final String skin;
  final bool best;
  final String platform;
  final DateTime? at;

  RunRow._(this.id, this.uid, this.stage, this.mapId, this.time, this.level, this.stat, this.statCount, this.coins,
      this.bonus, this.revive, this.character, this.gear, this.skin, this.best, this.platform, this.at);

  /// users/{uid}/runs/{id} 문서 값으로 만든다
  factory RunRow.fromMap(String id, String uid, Map<String, dynamic> d) {
    final stage = intOf(d['stage']);
    final mapId = (d['mapId'] as String?) ?? stageByNo(stage)?.id ?? '';
    return RunRow._(
      id,
      uid,
      stage == 0 ? (stageById(mapId)?.no ?? 0) : stage,
      mapId,
      dblOf(d['time']),
      intOf(d['level']),
      (d['stat'] as String?) ?? '',
      intOf(d['statCount']),
      intOf(d['coins']),
      intOf(d['bonus']),
      intOf(d['revive']),
      (d['character'] as String?) ?? '',
      (d['gear'] is List) ? (d['gear'] as List).map((e) => '$e').toList() : const [],
      (d['skin'] as String?) ?? '',
      d['best'] == true,
      (d['platform'] as String?) ?? '',
      tsOf(d['timestamp']),
    );
  }

  String get statText => stat.isEmpty ? '-' : '${statName(stat)} $statCount';
  String get coinText => bonus > 0 ? '${fmtNum(coins)} (+$bonus)' : fmtNum(coins);
  String get gearText {
    final parts = [...gear.map(itemName), if (skin.isNotEmpty && skin != 'skin_none') '스킨 ${itemName(skin)}'];
    return parts.isEmpty ? '-' : parts.join(', ');
  }
}

/// 스테이지별 요약(판 수·평균·최고·총 시간)
class StageAgg {
  int runs = 0;
  double total = 0;
  double best = 0;
  final Set<String> users = {};
  void add(RunRow r) {
    runs++;
    total += r.time;
    if (r.time > best) best = r.time;
    users.add(r.uid);
  }

  double get avg => runs == 0 ? 0 : total / runs;
}

/// 일별 개수(오래된 날 → 오늘). [days] 칸
List<double> dailyCounts(Iterable<DateTime?> times, int days, {DateTime? until}) {
  final today = until ?? startOfToday();
  final out = List<double>.filled(days, 0);
  for (final t in times) {
    if (t == null) continue;
    final i = days - 1 - today.difference(dayOf(t)).inDays;
    if (i >= 0 && i < days) out[i]++;
  }
  return out;
}

List<String> dayLabels(int days) {
  final today = startOfToday();
  return [for (int i = days - 1; i >= 0; i--) fmtMd(today.subtract(Duration(days: i)))];
}
