// ─────────────────────────────────────────────────────────────
// 존 장비 — 존마다 부위(머리·손·발·등)별로 하나씩 장착한다. docs/SHOP.md · docs/CHARACTER_CONCEPT.md
//
//   갤럭시  : 머리(헤드셋·고글·헬멧) · 손(우주 장갑) · 등(날개) · 발(로켓 부츠)
//   피구    : 머리(머리띠) · 손(손목 밴드) · 발(운동화)
//   골키퍼  : 머리(모자·털모자) · 손(장갑) · 발(축구화)
//
// 부위마다 무료 장비 · 코인 장비 · 뱃지 보상 장비가 있다. 처음에는 아무것도 안 입은 상태다(2026-09-22).
// 코인 보너스는 가격 구간으로 정해진다(GearBonus.forPrice, 2026-10-28) — 목록에 수치를 따로 적지 않는다.
// **장비는 외형이다(2026-10-26).** 속도·무적·회복·에너지·막는 범위 같은 전투 능력치는 전부 뺐다 — 캐릭터 능력치를
// 통일한 이유(랭킹은 순수 실력 경쟁)와 어긋났기 때문. 남은 보너스는 판이 끝날 때 받는 코인 +% 하나(GearBonus.coin)뿐이다.
// 같은 날 카탈로그를 63 → 39종으로 줄였다 — 뺀 것은 [GearItem.retired] 로 상점에서 숨기고(이미 가진 사람에게만 보인다) 그림은 그대로 둔다.
// 꾸미기(cosmetics.dart)도 같은 GearBonus 를 쓰고, 착용 한 벌의 합계는 loadout.dart 가 구한다.
// 그림은 gear_painter.dart 가 id 로 그린다(이미지 없음). 상점 카드는 GearIconPainter.
// ─────────────────────────────────────────────────────────────

enum GearSlot { head, hands, feet, back }

/// 장비·꾸미기 보너스 — 코인 +% 뿐이다(전투 능력치 없음, 2026-10-26).
/// 2026-10-28 아이템마다 제각각이던 수치를 **가격 구간 규칙 하나**로 통일했다([forPrice]) — 카드에서 가격만 보면 보너스를 안다.
class GearBonus {
  final double coin; // 판이 끝날 때 받는 코인 배수 + (0.1 = 10%)
  const GearBonus({this.coin = 0});

  static const none = GearBonus();
  bool get isZero => coin == 0;

  /// 가격 구간 → 보너스. 600 코인부터 +5%, 1000 코인부터 +10%. 그 아래(기본 포함)는 없음
  static GearBonus forPrice(int price) => price >= 1000
      ? const GearBonus(coin: 0.10)
      : price >= 600
          ? const GearBonus(coin: 0.05)
          : none;

  /// 뱃지 보상 장비(값을 치르지 않는 가장 어려운 장비) — 최고 구간과 같은 +10%
  static const badge = GearBonus(coin: 0.10);

  GearBonus operator +(GearBonus o) => GearBonus(coin: coin + o.coin);

  /// 상점 표시용 (번역 키, 숫자) 목록
  List<(String, String)> get labels => [
        if (coin > 0) ('bonus_coin', '${(coin * 100).round()}'),
      ];
}

class GearItem {
  final String id;
  final String zone; // world id
  final GearSlot slot;
  final int price; // 0 = 무료(기본 또는 명패 보상)
  final String? needsBadge; // 이 뱃지가 있어야 쓸 수 있다(badges.dart)
  /// 판매 종료(2026-10-26 카탈로그 축소) — 상점에서 숨긴다. 가진 사람은 그대로 입고 본다
  final bool retired;
  const GearItem(this.id, this.zone, this.slot, {this.price = 0, this.needsBadge, this.retired = false});

  /// 코인 보너스 — 가격 구간 규칙(GearBonus.forPrice). 뱃지 보상은 GearBonus.badge
  GearBonus get bonus => needsBadge != null ? GearBonus.badge : GearBonus.forPrice(price);

  /// 번역 키
  String get nameKey => 'gear_$id';
}

class Gear {
  static const List<GearItem> all = [
    // ── 갤럭시 ── 머리 · 손 · 등 · 발
    GearItem('antenna_basic', 'cyber', GearSlot.head),
    GearItem('goggles_space', 'cyber', GearSlot.head, price: 300),
    GearItem('goggles_night', 'cyber', GearSlot.head, price: 400, retired: true),
    GearItem('helmet_bubble', 'cyber', GearSlot.head, price: 450, retired: true),
    GearItem('helmet_visor', 'cyber', GearSlot.head, price: 600),
    GearItem('goggles_aurora', 'cyber', GearSlot.head, price: 800),
    GearItem('mitts_space', 'cyber', GearSlot.hands),
    GearItem('mitts_astro', 'cyber', GearSlot.hands, price: 250),
    GearItem('gauntlet_neon', 'cyber', GearSlot.hands, price: 350, retired: true),
    GearItem('gauntlet_ion', 'cyber', GearSlot.hands, price: 550),
    GearItem('gauntlet_plasma', 'cyber', GearSlot.hands, price: 750),
    GearItem('wings_white', 'cyber', GearSlot.back),
    GearItem('wings_star', 'cyber', GearSlot.back, price: 400),
    GearItem('wings_bat', 'cyber', GearSlot.back, price: 450, retired: true),
    GearItem('wings_mech', 'cyber', GearSlot.back, price: 550, retired: true),
    GearItem('wings_comet', 'cyber', GearSlot.back, price: 650),
    GearItem('wings_crystal', 'cyber', GearSlot.back, price: 850, retired: true),
    GearItem('wings_gold', 'cyber', GearSlot.back, needsBadge: 'b_s1_180'),
    GearItem('rocket_red', 'cyber', GearSlot.feet),
    GearItem('rocket_plasma', 'cyber', GearSlot.feet, price: 350),
    GearItem('rocket_chrome', 'cyber', GearSlot.feet, price: 500),
    GearItem('rocket_void', 'cyber', GearSlot.feet, price: 700, retired: true),
    GearItem('rocket_aurora', 'cyber', GearSlot.feet, price: 900),
    // ── 피구 ── 머리 · 손 · 발
    GearItem('band_red', 'dodgeball', GearSlot.head),
    GearItem('band_blue', 'dodgeball', GearSlot.head, price: 250),
    GearItem('band_stripe', 'dodgeball', GearSlot.head, price: 300, retired: true),
    GearItem('band_mint', 'dodgeball', GearSlot.head, price: 400, retired: true),
    GearItem('band_galaxy', 'dodgeball', GearSlot.head, price: 650),
    GearItem('band_flame', 'dodgeball', GearSlot.head, needsBadge: 'b_s2_150'),
    GearItem('wrist_white', 'dodgeball', GearSlot.hands),
    GearItem('wrist_red', 'dodgeball', GearSlot.hands, price: 200),
    GearItem('wrist_black', 'dodgeball', GearSlot.hands, price: 300, retired: true),
    GearItem('wrist_rainbow', 'dodgeball', GearSlot.hands, price: 350, retired: true),
    GearItem('wrist_gold', 'dodgeball', GearSlot.hands, price: 600),
    GearItem('wrist_neon', 'dodgeball', GearSlot.hands, price: 750),
    GearItem('sneakers_white', 'dodgeball', GearSlot.feet),
    GearItem('sneakers_sky', 'dodgeball', GearSlot.feet, price: 300),
    GearItem('sneakers_neon', 'dodgeball', GearSlot.feet, price: 400, retired: true),
    GearItem('sneakers_hightop', 'dodgeball', GearSlot.feet, price: 450, retired: true),
    GearItem('sneakers_gold', 'dodgeball', GearSlot.feet, price: 600),
    GearItem('sneakers_violet', 'dodgeball', GearSlot.feet, price: 700, retired: true),
    GearItem('sneakers_aurora', 'dodgeball', GearSlot.feet, price: 900),
    // ── 골키퍼 ── 머리 · 손 · 발
    GearItem('cap_blue', 'keeper', GearSlot.head),
    GearItem('cap_red', 'keeper', GearSlot.head, price: 250),
    GearItem('cap_black', 'keeper', GearSlot.head, price: 300, retired: true),
    GearItem('cap_mint', 'keeper', GearSlot.head, price: 350, retired: true),
    GearItem('beanie_stripe', 'keeper', GearSlot.head, price: 400, retired: true),
    GearItem('beanie_pom', 'keeper', GearSlot.head, price: 550),
    GearItem('cap_gold', 'keeper', GearSlot.head, price: 750),
    GearItem('gloves_basic', 'keeper', GearSlot.hands),
    GearItem('gloves_pro', 'keeper', GearSlot.hands, price: 400),
    GearItem('gloves_ice', 'keeper', GearSlot.hands, price: 450, retired: true),
    GearItem('gloves_fire', 'keeper', GearSlot.hands, price: 500, retired: true),
    GearItem('gloves_violet', 'keeper', GearSlot.hands, price: 650),
    GearItem('gloves_gold', 'keeper', GearSlot.hands, needsBadge: 'b_s3_150'),
    GearItem('gloves_neon', 'keeper', GearSlot.hands, price: 850, retired: true),
    GearItem('boots_black', 'keeper', GearSlot.feet),
    GearItem('boots_orange', 'keeper', GearSlot.feet, price: 350),
    GearItem('boots_mint', 'keeper', GearSlot.feet, price: 400, retired: true),
    GearItem('boots_white', 'keeper', GearSlot.feet, price: 450),
    GearItem('boots_violet', 'keeper', GearSlot.feet, price: 600, retired: true),
    GearItem('boots_carbon', 'keeper', GearSlot.feet, price: 700, retired: true),
    GearItem('boots_gold', 'keeper', GearSlot.feet, price: 900),
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

  /// 그 존에서 지금 착용 중인 장비의 보너스 합계 — 코인 정산(main)이 쓴다
  static GearBonus bonusOf(String zone, String Function(String key, String fallback) equipped) {
    var total = GearBonus.none;
    for (final slot in slotsOf(zone)) {
      final item = byId(wornId(zone, slot, equipped));
      if (item != null) total = total + item.bonus;
    }
    return total;
  }

  /// 그 존·부위의 장비 전부(판매 종료 포함)
  static List<GearItem> itemsOf(String zone, GearSlot slot) =>
      all.where((g) => g.zone == zone && g.slot == slot).toList();

  /// 상점에 보이는 장비 — 판매 종료된 것은 [owns] 가 true 일 때만
  static List<GearItem> shopItemsOf(String zone, GearSlot slot, bool Function(String id) owns) =>
      itemsOf(zone, slot).where((g) => !g.retired || owns(g.id)).toList();

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
