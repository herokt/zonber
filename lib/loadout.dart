import 'cosmetics.dart';
import 'gear.dart';
import 'pets.dart';
import 'world_config.dart';

// ─────────────────────────────────────────────────────────────
// 착용 한 벌의 능력치 — 존 장비(gear.dart) + 꾸미기(스킨·잔상·오라, cosmetics.dart)를 합쳐 그 존에 맞춘다(2026-10-12).
// 게임(Player)·코인 정산(main._handleGameOver)·가방 표시가 모두 여기를 거친다 — 보이는 숫자 = 게임에 들어가는 숫자.
// 펫(pets.dart)은 능력치가 아니라 직접 돕는다(lib/game/pet.dart).
// ─────────────────────────────────────────────────────────────

class Loadout {
  /// 그 존에서 지금 착용한 것의 능력치 합계(존에 맞춘 값)
  static GearBonus bonusOf(String zone, String Function(String key, String fallback) equipped) {
    var total = Gear.bonusOf(zone, equipped);
    for (final k in CosmeticKind.values) {
      final id = k == CosmeticKind.aura ? auraOf(equipped) : equipped(Cosmetics.kindKey(k), Cosmetics.defaultOf(k));
      final c = Cosmetics.byId(id);
      if (c != null) total = total + c.bonus;
    }
    return total.adapt(keeper: isKeeper(zone));
  }

  /// 꾸미기 하나의 능력치를 그 존에 맞춰(가방 카드 표시용)
  static GearBonus cosmeticFor(String zone, Cosmetic c) => c.bonus.adapt(keeper: isKeeper(zone));

  static bool isKeeper(String zone) => WorldData.getWorld(zone).mode == WorldMode.keeper;

  /// 실제로 쓰는 오라 — 펫을 데리고 있으면 주위를 도는 오라는 없는 셈 친다(가방이 막지만, 예전 착용이 남아 있을 수 있다)
  static String auraOf(String Function(String key, String fallback) equipped) {
    final aura = equipped(Cosmetics.kindKey(CosmeticKind.aura), Cosmetics.defaultAura);
    if (Pets.worn(equipped) != null && Cosmetics.orbits(aura)) return Cosmetics.defaultAura;
    return aura;
  }
}
