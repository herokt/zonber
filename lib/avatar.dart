import 'package:flutter/material.dart';

import 'character_data.dart';
import 'coin_store.dart';
import 'cosmetics.dart';
import 'gear.dart';
import 'zonber_painter.dart';

// ─────────────────────────────────────────────────────────────
// 아바타 — 한 유저의 겉모습 한 벌(캐릭터 · 몸통 스킨 · 이동 잔상 · 오라 · 존별 장비).
//
// 아바타를 보여 주는 곳은 전부 이 파일을 쓴다:
//   · [AvatarView]  동그란 아바타(랭킹 줄 · 홈 · 프로필 · 상점 카드)
//   · [AvatarStage] 큰 전신 아바타 — 잔상·오라까지 움직인다(상점 미리보기 · 프로필)
//   · [Avatar.look] 게임 안(Player)이 쓰는 ZonberLook
//
// 내 것도 남의 것도 같은 클래스다 — 내 것은 [Avatar.equipped](기기에 저장된 착용),
// 남의 것은 [Avatar.fromUserDoc](users/{uid} 문서)·[Avatar.fromRecord](랭킹 기록 한 줄).
// 겉모습이 게임 판정에 주는 영향은 장비 보너스(gear.dart)뿐이다.
// ─────────────────────────────────────────────────────────────

@immutable
class Avatar {
  /// 캐릭터 id(character_data.dart) — 몸 색과 표정이 여기서 온다
  final String characterId;

  /// 몸통 스킨 · 이동 잔상 · 오라(cosmetics.dart)
  final String skinId;
  final String trailId;
  final String auraId;

  /// 존 id → 그 존에서 입은 장비 id 목록(gear.dart). 한 존만 받아 온 경우엔 그 존만 들어 있다
  final Map<String, List<String>> gearByZone;

  const Avatar({
    this.characterId = defaultCharacterId,
    this.skinId = Cosmetics.defaultSkin,
    this.trailId = Cosmetics.defaultTrail,
    this.auraId = Cosmetics.defaultAura,
    this.gearByZone = const {},
  });

  static const String defaultCharacterId = 'neon_green';

  /// 아무것도 모를 때(기록에 유저 정보가 없을 때) 보여 주는 기본 아바타
  static const Avatar fallback = Avatar();

  Character get character => CharacterData.getCharacter(characterId);
  Color get color => character.color;

  /// 그 존에서 입은 장비 — 존을 모르면 장비 없이 그린다
  List<String> gearOf(String? zone) => zone == null ? const [] : (gearByZone[zone] ?? const []);

  List<Cosmetic> get trailAndAura => [
        for (final id in [trailId, auraId])
          if (Cosmetics.byId(id) case final c?) c,
      ];

  /// 그림 한 장을 그릴 때 쓰는 값 — 게임·아바타·미리보기가 모두 이걸 거쳐 간다
  ZonberLook look({
    String? zone,
    ZonberFace face = ZonberFace.normal,
    double t = 0,
    bool moving = false,
    double squash = 0,
    Offset lookAt = Offset.zero,
  }) =>
      ZonberLook(
        color: color,
        charId: characterId,
        skin: skinId,
        gear: gearOf(zone),
        face: face,
        t: t,
        moving: moving,
        squash: squash,
        look: lookAt,
      );

  Avatar copyWith({
    String? characterId,
    String? skinId,
    String? trailId,
    String? auraId,
    Map<String, List<String>>? gearByZone,
  }) =>
      Avatar(
        characterId: characterId ?? this.characterId,
        skinId: skinId ?? this.skinId,
        trailId: trailId ?? this.trailId,
        auraId: auraId ?? this.auraId,
        gearByZone: gearByZone ?? this.gearByZone,
      );

  /// 착용 목록(슬롯 키 → 아이템 id)에서 만든다. 내 것은 `CoinStore.equipped`,
  /// 남의 것은 users/{uid}.equipped 가 그대로 이 모양이다
  factory Avatar.fromEquipped(String characterId, String Function(String key, String fallback) equipped) => Avatar(
        characterId: characterId,
        skinId: equipped(Cosmetics.kindKey(CosmeticKind.skin), Cosmetics.defaultSkin),
        trailId: equipped(Cosmetics.kindKey(CosmeticKind.trail), Cosmetics.defaultTrail),
        auraId: equipped(Cosmetics.kindKey(CosmeticKind.aura), Cosmetics.defaultAura),
        gearByZone: {
          for (final zone in Gear.zones)
            zone: [
              for (final slot in Gear.slotsOf(zone))
                if (Gear.wornId(zone, slot, equipped) != Gear.none) Gear.wornId(zone, slot, equipped),
            ],
        },
      );

  /// 내 아바타 — 기기에 저장된 착용 목록. `CoinStore.load()` 뒤에 부른다([mine] 은 알아서 불러 준다)
  factory Avatar.equipped(String characterId) => Avatar.fromEquipped(characterId, CoinStore.equipped);

  static Future<Avatar> mine(String characterId) async {
    await CoinStore.load();
    return Avatar.equipped(characterId);
  }

  /// 남의 아바타 — users/{uid} 문서(랭킹·프로필에서 읽는다)
  factory Avatar.fromUserDoc(Map<String, dynamic> doc) {
    final equipped = doc['equipped'];
    final map = equipped is Map ? equipped : const {};
    return Avatar.fromEquipped(
      (doc['characterId'] as String?)?.trim().isNotEmpty == true ? doc['characterId'] as String : defaultCharacterId,
      (key, fallback) => map[key] is String ? map[key] as String : fallback,
    );
  }

  /// 랭킹 기록 한 줄 — RankingSystem 이 유저 문서를 보고 채워 둔 값(그 존 장비만 들어 있다)
  factory Avatar.fromRecord(Map<String, dynamic> record, {String? zone}) => Avatar(
        characterId: (record['characterId'] as String?) ?? defaultCharacterId,
        skinId: (record['skin'] as String?) ?? Cosmetics.defaultSkin,
        trailId: (record['trail'] as String?) ?? Cosmetics.defaultTrail,
        auraId: (record['aura'] as String?) ?? Cosmetics.defaultAura,
        gearByZone: zone == null
            ? const {}
            : {zone: (record['gear'] as List?)?.whereType<String>().toList() ?? const []},
      );

  @override
  bool operator ==(Object other) =>
      other is Avatar &&
      other.characterId == characterId &&
      other.skinId == skinId &&
      other.trailId == trailId &&
      other.auraId == auraId &&
      _sameGear(other.gearByZone, gearByZone);

  @override
  int get hashCode => Object.hash(characterId, skinId, trailId, auraId, _wornCount);

  int get _wornCount => gearByZone.values.fold(0, (n, list) => n + list.length);

  /// 입은 게 같으면 같은 아바타다 — 비어 있는 존은 아예 없는 것과 같게 본다
  static bool _sameGear(Map<String, List<String>> a, Map<String, List<String>> b) {
    for (final zone in {...a.keys, ...b.keys}) {
      final x = a[zone] ?? const [], y = b[zone] ?? const [];
      if (x.length != y.length) return false;
      for (int i = 0; i < x.length; i++) {
        if (x[i] != y[i]) return false;
      }
    }
    return true;
  }
}

/// 동그란 아바타 — 랭킹 줄 · 홈 · 프로필 · 상점 카드. 사진 업로드는 없다(코드로 그린다).
class AvatarView extends StatelessWidget {
  final Avatar avatar;
  final double size;

  /// 이 존에서 입은 장비까지 보여 준다(없으면 맨몸)
  final String? zone;
  final Color? borderColor;
  final ZonberFace face;

  const AvatarView({
    super.key,
    required this.avatar,
    this.size = 32,
    this.zone,
    this.borderColor,
    this.face = ZonberFace.normal,
  });

  /// 캐릭터만 보여 주면 되는 자리(캐릭터 고르기 등)
  AvatarView.character(String characterId, {super.key, this.size = 32, this.borderColor, String? skin})
      : avatar = Avatar(characterId: characterId, skinId: skin ?? Cosmetics.defaultSkin),
        zone = null,
        face = ZonberFace.normal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatar.color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor!, width: 2) : null,
      ),
      child: ClipOval(child: CustomPaint(painter: ZonberPainter(avatar.look(zone: zone, face: face)))),
    );
  }
}

/// 큰 전신 아바타 — 제자리에서 걷고, 잔상·오라·날개가 함께 움직인다.
/// 상점 미리보기와 프로필이 같이 쓴다.
class AvatarStage extends StatefulWidget {
  final Avatar avatar;
  final double size;

  /// 이 존 장비를 입혀서 보여 준다
  final String? zone;

  /// 잔상·오라까지 그린다(작은 자리에서는 꺼 둔다)
  final bool cosmetics;

  const AvatarStage({super.key, required this.avatar, required this.size, this.zone, this.cosmetics = true});

  @override
  State<AvatarStage> createState() => _AvatarStageState();
}

class _AvatarStageState extends State<AvatarStage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  // 그림 시간은 되감지 않고 계속 흐른다 — 컨트롤러는 다시 그리는 신호로만 쓴다(무지개 등이 6초마다 뚝 끊기지 않게)
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _clock.elapsedMicroseconds / 1e6;
        // 3초마다 한 번 신난 표정
        final face = (t % 3) > 2.5 ? ZonberFace.happy : ZonberFace.normal;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: ZonberPainter(widget.avatar.look(zone: widget.zone, t: t, moving: true, face: face)),
        );
      },
    );
    if (!widget.cosmetics) return body;
    return CosmeticStage(
      items: widget.avatar.trailAndAura,
      base: widget.avatar.color,
      charRadius: widget.size * 0.3, // ZonberPainter 가 쓰는 몸 반지름
      child: body,
    );
  }
}
