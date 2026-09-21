// ─────────────────────────────────────────────────────────────
// 존 장비 — 존마다 부위(머리·손·발·등)별로 하나씩 장착한다. docs/SHOP.md · docs/CHARACTER_CONCEPT.md
//
//   갤럭시  : 등(날개) · 발(로켓 부츠)
//   피구    : 머리(머리띠) · 발(운동화)
//   골키퍼  : 머리(모자) · 손(장갑) · 발(축구화)
//
// 부위마다 기본 장비(무료, 자동 장착) · 코인 장비 · 명패 보상 장비가 있다.
// 장비는 능력치 보너스(GearBonus)를 가질 수 있다 — 지금은 전부 0(구조만). 캐릭터 기본 능력치는 모두 같다.
// 그림은 zonber_painter.dart 가 부위·스타일 id 로 그린다(이미지 없음).
// ─────────────────────────────────────────────────────────────

enum GearSlot { head, hands, feet, back }

/// 장비 능력치 보너스 — 캐릭터 기본 능력치(CharacterStats.standard)에 더한다
class GearBonus {
  final int energy; // 에너지 칸 +
  final double speed; // 속도 배수 + (0.05 = 5%)
  final double recovery; // 에너지 회복 대기 시간 − 초
  final double iframe; // 무적 시간 + 초
  const GearBonus({this.energy = 0, this.speed = 0, this.recovery = 0, this.iframe = 0});

  static const none = GearBonus();
  bool get isZero => energy == 0 && speed == 0 && recovery == 0 && iframe == 0;

  GearBonus operator +(GearBonus o) => GearBonus(
        energy: energy + o.energy,
        speed: speed + o.speed,
        recovery: recovery + o.recovery,
        iframe: iframe + o.iframe,
      );
}

class GearItem {
  final String id;
  final String zone; // world id
  final GearSlot slot;
  final int price; // 0 = 무료(기본 또는 명패 보상)
  final bool needsPlate; // 그 존 명패가 있어야 쓸 수 있다
  final GearBonus bonus;
  const GearItem(this.id, this.zone, this.slot, {this.price = 0, this.needsPlate = false, this.bonus = GearBonus.none});

  /// 번역 키
  String get nameKey => 'gear_$id';
}

class Gear {
  static const List<GearItem> all = [
    // ── 갤럭시 ──
    GearItem('wings_white', 'cyber', GearSlot.back),
    GearItem('wings_star', 'cyber', GearSlot.back, price: 400),
    GearItem('wings_gold', 'cyber', GearSlot.back, needsPlate: true),
    GearItem('rocket_red', 'cyber', GearSlot.feet),
    GearItem('rocket_plasma', 'cyber', GearSlot.feet, price: 350),
    // ── 피구 ──
    GearItem('band_red', 'dodgeball', GearSlot.head),
    GearItem('band_blue', 'dodgeball', GearSlot.head, price: 250),
    GearItem('band_flame', 'dodgeball', GearSlot.head, needsPlate: true),
    GearItem('sneakers_white', 'dodgeball', GearSlot.feet),
    GearItem('sneakers_neon', 'dodgeball', GearSlot.feet, price: 400),
    // ── 골키퍼 ──
    GearItem('cap_blue', 'keeper', GearSlot.head),
    GearItem('cap_red', 'keeper', GearSlot.head, price: 250),
    GearItem('gloves_basic', 'keeper', GearSlot.hands),
    GearItem('gloves_pro', 'keeper', GearSlot.hands, price: 400),
    GearItem('gloves_gold', 'keeper', GearSlot.hands, needsPlate: true),
    GearItem('boots_black', 'keeper', GearSlot.feet),
    GearItem('boots_orange', 'keeper', GearSlot.feet, price: 350),
  ];

  static GearItem? byId(String id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// 존이 쓰는 부위(표시 순서)
  static List<GearSlot> slotsOf(String zone) {
    final seen = <GearSlot>[];
    for (final g in all) {
      if (g.zone == zone && !seen.contains(g.slot)) seen.add(g.slot);
    }
    return seen;
  }

  static List<GearItem> itemsOf(String zone, GearSlot slot) =>
      all.where((g) => g.zone == zone && g.slot == slot).toList();

  /// 부위의 기본(무료·자동) 장비 — 목록의 첫 번째
  static GearItem defaultOf(String zone, GearSlot slot) => itemsOf(zone, slot).first;

  /// 착용 슬롯 키(CoinStore.equipped)
  static String slotKey(String zone, GearSlot slot) => 'gear_${zone}_${slot.name}';

  static String slotLabelKey(GearSlot s) => 'gear_slot_${s.name}';
}
