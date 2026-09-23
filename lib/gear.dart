// ─────────────────────────────────────────────────────────────
// 존 장비 — 존마다 부위(머리·손·발·등)별로 하나씩 장착한다. docs/SHOP.md · docs/CHARACTER_CONCEPT.md
//
//   갤럭시  : 머리(헤드셋·고글·헬멧) · 손(우주 장갑) · 등(날개) · 발(로켓 부츠)
//   피구    : 머리(머리띠) · 손(손목 밴드) · 발(운동화)
//   골키퍼  : 머리(모자·털모자) · 손(장갑) · 발(축구화)
//
// 부위마다 무료 장비 · 코인 장비 · 뱃지 보상 장비가 있다. 처음에는 아무것도 안 입은 상태다(2026-09-22).
// 코인·뱃지 장비는 작은 능력치 보너스(GearBonus)가 있다(2026-09-22) — 속도 2~6% · 회복 대기 −1~2.5초 · 무적 +0.1~0.2초 ·
// 골키퍼 막는 범위 +2~4px. 무료 장비는 보너스 없음. 캐릭터 기본 능력치는 모두 같다.
// 그림은 gear_painter.dart 가 id 로 그린다(이미지 없음). 상점 카드는 GearIconPainter.
// ─────────────────────────────────────────────────────────────

enum GearSlot { head, hands, feet, back }

/// 장비 능력치 보너스 — 캐릭터 기본 능력치(CharacterStats.standard)에 더한다
class GearBonus {
  final int energy; // 에너지 칸 +
  final double speed; // 속도 배수 + (0.05 = 5%)
  final double recovery; // 에너지 회복 대기 시간 − 초
  final double iframe; // 무적 시간 + 초
  final double reach; // 골키퍼 막는 범위 + px (골키퍼는 에너지 회복·무적이 없어서 장갑은 이걸 올린다)
  final double coin; // 판이 끝날 때 받는 코인 배수 + (0.1 = 10%). 어느 존에서나 쓸모 있다
  const GearBonus({this.energy = 0, this.speed = 0, this.recovery = 0, this.iframe = 0, this.reach = 0, this.coin = 0});

  static const none = GearBonus();
  bool get isZero => energy == 0 && speed == 0 && recovery == 0 && iframe == 0 && reach == 0 && coin == 0;

  GearBonus operator +(GearBonus o) => GearBonus(
        energy: energy + o.energy,
        speed: speed + o.speed,
        recovery: recovery + o.recovery,
        iframe: iframe + o.iframe,
        reach: reach + o.reach,
        coin: coin + o.coin,
      );

  /// 상점 표시용 (번역 키, 숫자) 목록
  List<(String, String)> get labels => [
        if (speed > 0) ('bonus_speed', '${(speed * 100).round()}'),
        if (recovery > 0) ('bonus_recovery', recovery.toStringAsFixed(recovery % 1 == 0 ? 0 : 1)),
        if (iframe > 0) ('bonus_iframe', iframe.toStringAsFixed(1)),
        if (reach > 0) ('bonus_reach', '${reach.round()}'),
        if (energy > 0) ('bonus_energy', '$energy'),
        if (coin > 0) ('bonus_coin', '${(coin * 100).round()}'),
      ];
}

class GearItem {
  final String id;
  final String zone; // world id
  final GearSlot slot;
  final int price; // 0 = 무료(기본 또는 명패 보상)
  final String? needsBadge; // 이 뱃지가 있어야 쓸 수 있다(badges.dart)
  final GearBonus bonus;
  const GearItem(this.id, this.zone, this.slot, {this.price = 0, this.needsBadge, this.bonus = GearBonus.none});

  /// 번역 키
  String get nameKey => 'gear_$id';
}

class Gear {
  static const List<GearItem> all = [
    // ── 갤럭시 ── 머리 · 손 · 등 · 발
    GearItem('antenna_basic', 'cyber', GearSlot.head),
    GearItem('goggles_space', 'cyber', GearSlot.head, price: 300, bonus: GearBonus(recovery: 1)),
    GearItem('goggles_night', 'cyber', GearSlot.head, price: 400, bonus: GearBonus(recovery: 1, coin: 0.05)),
    GearItem('helmet_bubble', 'cyber', GearSlot.head, price: 450, bonus: GearBonus(recovery: 2)),
    GearItem('helmet_visor', 'cyber', GearSlot.head, price: 600, bonus: GearBonus(recovery: 2, iframe: 0.1)),
    GearItem('mitts_space', 'cyber', GearSlot.hands),
    GearItem('mitts_astro', 'cyber', GearSlot.hands, price: 250, bonus: GearBonus(iframe: 0.1)),
    GearItem('gauntlet_neon', 'cyber', GearSlot.hands, price: 350, bonus: GearBonus(iframe: 0.2)),
    GearItem('gauntlet_ion', 'cyber', GearSlot.hands, price: 550, bonus: GearBonus(iframe: 0.25, speed: 0.02)),
    GearItem('wings_white', 'cyber', GearSlot.back),
    GearItem('wings_star', 'cyber', GearSlot.back, price: 400, bonus: GearBonus(speed: 0.02)),
    GearItem('wings_bat', 'cyber', GearSlot.back, price: 450, bonus: GearBonus(speed: 0.03)),
    GearItem('wings_mech', 'cyber', GearSlot.back, price: 550, bonus: GearBonus(speed: 0.04)),
    GearItem('wings_comet', 'cyber', GearSlot.back, price: 650, bonus: GearBonus(speed: 0.03, coin: 0.1)),
    GearItem('wings_gold', 'cyber', GearSlot.back, needsBadge: 'b_s1_180', bonus: GearBonus(speed: 0.05, energy: 1)),
    GearItem('rocket_red', 'cyber', GearSlot.feet),
    GearItem('rocket_plasma', 'cyber', GearSlot.feet, price: 350, bonus: GearBonus(speed: 0.03)),
    GearItem('rocket_chrome', 'cyber', GearSlot.feet, price: 500, bonus: GearBonus(speed: 0.05)),
    GearItem('rocket_void', 'cyber', GearSlot.feet, price: 700, bonus: GearBonus(speed: 0.04, recovery: 1.5)),
    // ── 피구 ── 머리 · 손 · 발
    GearItem('band_red', 'dodgeball', GearSlot.head),
    GearItem('band_blue', 'dodgeball', GearSlot.head, price: 250, bonus: GearBonus(recovery: 1)),
    GearItem('band_stripe', 'dodgeball', GearSlot.head, price: 300, bonus: GearBonus(recovery: 1.5)),
    GearItem('band_mint', 'dodgeball', GearSlot.head, price: 400, bonus: GearBonus(recovery: 1, iframe: 0.1)),
    GearItem('band_flame', 'dodgeball', GearSlot.head, needsBadge: 'b_s2_150', bonus: GearBonus(recovery: 2.5, coin: 0.1)),
    GearItem('wrist_white', 'dodgeball', GearSlot.hands),
    GearItem('wrist_red', 'dodgeball', GearSlot.hands, price: 200, bonus: GearBonus(iframe: 0.1)),
    GearItem('wrist_black', 'dodgeball', GearSlot.hands, price: 300, bonus: GearBonus(iframe: 0.15, speed: 0.01)),
    GearItem('wrist_rainbow', 'dodgeball', GearSlot.hands, price: 350, bonus: GearBonus(iframe: 0.2)),
    GearItem('wrist_gold', 'dodgeball', GearSlot.hands, price: 600, bonus: GearBonus(iframe: 0.2, coin: 0.15)),
    GearItem('sneakers_white', 'dodgeball', GearSlot.feet),
    GearItem('sneakers_sky', 'dodgeball', GearSlot.feet, price: 300, bonus: GearBonus(speed: 0.02, recovery: 1)),
    GearItem('sneakers_neon', 'dodgeball', GearSlot.feet, price: 400, bonus: GearBonus(speed: 0.03)),
    GearItem('sneakers_hightop', 'dodgeball', GearSlot.feet, price: 450, bonus: GearBonus(speed: 0.04)),
    GearItem('sneakers_gold', 'dodgeball', GearSlot.feet, price: 600, bonus: GearBonus(speed: 0.06)),
    GearItem('sneakers_violet', 'dodgeball', GearSlot.feet, price: 700, bonus: GearBonus(speed: 0.05, energy: 1)),
    // ── 골키퍼 ── 머리 · 손 · 발 (회복·무적은 골키퍼에서 쓰이지 않아 속도·막는 범위·코인으로 준다)
    GearItem('cap_blue', 'keeper', GearSlot.head),
    GearItem('cap_red', 'keeper', GearSlot.head, price: 250, bonus: GearBonus(speed: 0.02)),
    GearItem('cap_black', 'keeper', GearSlot.head, price: 300, bonus: GearBonus(speed: 0.02)),
    GearItem('cap_mint', 'keeper', GearSlot.head, price: 350, bonus: GearBonus(speed: 0.02, reach: 1)),
    GearItem('beanie_stripe', 'keeper', GearSlot.head, price: 400, bonus: GearBonus(speed: 0.03)),
    GearItem('beanie_pom', 'keeper', GearSlot.head, price: 550, bonus: GearBonus(speed: 0.03, coin: 0.1)),
    GearItem('gloves_basic', 'keeper', GearSlot.hands),
    GearItem('gloves_pro', 'keeper', GearSlot.hands, price: 400, bonus: GearBonus(reach: 2)),
    GearItem('gloves_ice', 'keeper', GearSlot.hands, price: 450, bonus: GearBonus(reach: 2, speed: 0.02)),
    GearItem('gloves_fire', 'keeper', GearSlot.hands, price: 500, bonus: GearBonus(reach: 3)),
    GearItem('gloves_violet', 'keeper', GearSlot.hands, price: 650, bonus: GearBonus(reach: 3, coin: 0.1)),
    GearItem('gloves_gold', 'keeper', GearSlot.hands, needsBadge: 'b_s3_150', bonus: GearBonus(reach: 4)),
    GearItem('boots_black', 'keeper', GearSlot.feet),
    GearItem('boots_orange', 'keeper', GearSlot.feet, price: 350, bonus: GearBonus(speed: 0.03)),
    GearItem('boots_mint', 'keeper', GearSlot.feet, price: 400, bonus: GearBonus(speed: 0.04)),
    GearItem('boots_white', 'keeper', GearSlot.feet, price: 450, bonus: GearBonus(speed: 0.05)),
    GearItem('boots_violet', 'keeper', GearSlot.feet, price: 600, bonus: GearBonus(speed: 0.04, reach: 1)),
    GearItem('boots_carbon', 'keeper', GearSlot.feet, price: 700, bonus: GearBonus(speed: 0.06, reach: 1)),
  ];

  static GearItem? byId(String id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// 장비가 있는 존(표시 순서)
  static List<String> get zones {
    final seen = <String>[];
    for (final g in all) {
      if (!seen.contains(g.zone)) seen.add(g.zone);
    }
    return seen;
  }

  /// 존이 쓰는 부위(표시 순서)
  static List<GearSlot> slotsOf(String zone) {
    final seen = <GearSlot>[];
    for (final g in all) {
      if (g.zone == zone && !seen.contains(g.slot)) seen.add(g.slot);
    }
    return seen;
  }

  /// 그 존에서 지금 착용 중인 장비의 보너스 합계 — 게임(Player)과 코인 정산(main)이 같이 쓴다
  static GearBonus bonusOf(String zone, String Function(String key, String fallback) equipped) {
    var total = GearBonus.none;
    for (final slot in slotsOf(zone)) {
      final item = byId(wornId(zone, slot, equipped));
      if (item != null) total = total + item.bonus;
    }
    return total;
  }

  static List<GearItem> itemsOf(String zone, GearSlot slot) =>
      all.where((g) => g.zone == zone && g.slot == slot).toList();

  /// 아무것도 안 입은 상태(기본). 착용 슬롯 값이 '' 이면 그 부위는 비어 있다
  static const String none = '';

  /// 그 부위에 지금 착용한 장비 id — 기본은 [none]
  static String wornId(String zone, GearSlot slot, String Function(String key, String fallback) equipped) {
    final id = equipped(slotKey(zone, slot), none);
    return byId(id) == null ? none : id;
  }

  /// 착용 슬롯 키(CoinStore.equipped)
  static String slotKey(String zone, GearSlot slot) => 'gear_${zone}_${slot.name}';

  static String slotLabelKey(GearSlot s) => 'gear_slot_${s.name}';
}
