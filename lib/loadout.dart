import 'cosmetics.dart';
import 'gear.dart';

// ─────────────────────────────────────────────────────────────
// 착용 한 벌의 보너스 — 존 장비(gear.dart) + 꾸미기(스킨·잔상·오라, cosmetics.dart)를 합친다.
// 2026-10-26 전투 능력치(속도·무적·회복·에너지·막는 범위)를 전부 뺐다 — 남은 건 코인 +% 하나.
// 코인 정산(main._handleGameOver)·가방 표시가 여기를 거친다. 펫은 주위를 도는 오라의 한 종류다(2026-10-26).
// ─────────────────────────────────────────────────────────────

class Loadout {
  /// 그 존에서 지금 착용한 것의 보너스 합계(코인 +%)
  static GearBonus bonusOf(String zone, String Function(String key, String fallback) equipped) {
    var total = Gear.bonusOf(zone, equipped);
    for (final k in CosmeticKind.values) {
      final id = k == CosmeticKind.aura ? auraOf(equipped) : equipped(Cosmetics.kindKey(k), Cosmetics.defaultOf(k));
      final c = Cosmetics.byId(id);
      if (c != null) total = total + c.bonus;
    }
    return total;
  }

  /// 실제로 쓰는 오라 — 예전 'pet' 슬롯이 남아 있으면 그 펫 오라(Cosmetics.auraFrom)
  static String auraOf(String Function(String key, String fallback) equipped) => Cosmetics.auraFrom(equipped);
}
