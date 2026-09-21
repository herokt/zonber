import 'package:flutter/material.dart';

import 'character_data.dart';
import 'coin_store.dart';
import 'cosmetics.dart';
import 'gear.dart';
import 'zonber_painter.dart';
import 'design_system.dart';
import 'language_manager.dart';
import 'user_profile.dart';
import 'progress_store.dart';
import 'world_config.dart';

/// 상점 — 코인으로 외형(캐릭터)과 변경권을 산다. 능력치를 파는 물건은 없다. (docs/SHOP.md)
///   캐릭터 · 꾸미기(잔상·오라) · 기타(닉네임/국가 변경권, 광고 제거)
/// 인앱 결제(IAPService)는 앱에서 아직 초기화하지 않으므로 광고 제거는 "준비 중"으로 둔다.
class ShopPage extends StatefulWidget {
  final VoidCallback onBack;
  final Future<void> Function()? onPurchaseReset;
  /// 하단 탭으로 열리면 false — 상단 뒤로 가기 버튼을 숨긴다
  final bool showBack;

  const ShopPage({
    super.key,
    required this.onBack,
    this.onPurchaseReset,
    this.showBack = true,
  });

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  /// 변경권 가격(코인)
  static const int ticketPrice = 150;

  int _tab = 0;
  String _selectedCharId = 'neon_green';
  int _nicknameTickets = 0;
  int _countryTickets = 0;
  bool _busy = false;
  /// 존별 명패 — 황금 복장 해금 조건
  Map<String, PlateData> _plates = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await CoinStore.load();
    final profile = await UserProfileManager.getProfile();
    final nick = await UserProfileManager.getNicknameTickets();
    final country = await UserProfileManager.getCountryTickets();
    final plates = await ProgressStore.getPlates();
    if (!mounted) return;
    setState(() {
      _plates = plates;
      _selectedCharId = profile['characterId'] ?? 'neon_green';
      _nicknameTickets = nick;
      _countryTickets = country;
    });
  }

  bool _ownsChar(Character c) =>
      c.price == 0 || CharacterData.allUnlocked || CoinStore.owns('char_${c.id}');

  Future<void> _useChar(Character c) async {
    setState(() => _selectedCharId = c.id);
    final profile = await UserProfileManager.getProfile();
    await UserProfileManager.saveProfile(
      profile['nickname'] ?? '',
      profile['flag'] ?? '',
      profile['countryName'] ?? '',
      characterId: c.id,
    );
  }

  /// 구매 확인 → 코인 차감. 성공하면 true
  Future<bool> _confirmBuy(String itemName, int price, Future<bool> Function() buy) async {
    final lm = LanguageManager.of(context, listen: false);
    if (CoinStore.balance.value < price) {
      _toast(lm.translate('shop_not_enough'));
      return false;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => NeonDialog(
        title: lm.translate('shop_buy_title').replaceAll('{item}', itemName),
        message: lm.translate('shop_buy_message').replaceAll('{n}', formatCount(price)),
        actions: [
          NeonButton(text: lm.translate('cancel'), isPrimary: false, isCompact: true, onPressed: () => Navigator.pop(ctx, false)),
          NeonButton(text: lm.translate('shop_buy'), isCompact: true, color: AppColors.coin, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok != true || _busy) return false;
    setState(() => _busy = true);
    final done = await buy();
    if (mounted) setState(() => _busy = false);
    _toast(lm.translate(done ? 'shop_bought' : 'shop_not_enough'));
    return done;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return NeonScaffold(
      title: lm.translate('shop_title'),
      showBackButton: widget.showBack,
      onBack: widget.onBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 잔액 카드
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.coin.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const CoinIcon(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: CoinStore.balance,
                          builder: (context, b, _) => Text(formatCount(b), style: AppTextStyles.display(26, color: AppColors.coin)),
                        ),
                        const SizedBox(height: 4),
                        OneLineText(lm.translate('shop_earn_hint'),
                            style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppSegmented(
              items: [lm.translate('shop_tab_characters'), lm.translate('shop_tab_gear'), lm.translate('shop_tab_style'), lm.translate('shop_tab_extras')],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: CoinStore.balance, // 잔액이 바뀌면 "구매 가능" 표시도 다시 그린다
              builder: (context, _, __) => switch (_tab) {
                0 => _characters(lm),
                1 => _gear(lm),
                2 => _style(lm),
                _ => _extras(lm),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 캐릭터 ──
  Widget _characters(LanguageManager lm) {
    final sel = CharacterData.getCharacter(_selectedCharId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        if (CharacterData.allUnlocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(lm.translate('shop_free_now'),
                textAlign: TextAlign.center, style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w700)),
          ),
        // 세로로 긴 카드 — 좌우로 넘긴다
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: CharacterData.availableCharacters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SizedBox(width: 116, child: _charCard(lm, CharacterData.availableCharacters[i])),
          ),
        ),
        const SizedBox(height: 16),
        // 고른 캐릭터 소개
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CharacterAvatar(characterId: sel.id, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lm.translate('char_${sel.id}'), style: AppTextStyles.text(15, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(sel.description, style: AppTextStyles.text(12, color: AppColors.textDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(lm.translate('char_same_stats'),
            textAlign: TextAlign.center, style: AppTextStyles.text(11, color: AppColors.textDim)),
      ],
    );
  }

  Widget _charCard(LanguageManager lm, Character c) {
    final owned = _ownsChar(c);
    final inUse = c.id == _selectedCharId;
    final affordable = CoinStore.balance.value >= c.price;
    Widget action;
    if (inUse) {
      action = _pill(lm.translate('shop_in_use'), c.color, filled: true);
    } else if (owned) {
      action = _pill(lm.translate('shop_use'), c.color);
    } else {
      action = _pricePill(c.price, affordable);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (inUse) return;
        if (owned) {
          await _useChar(c);
        } else {
          final name = lm.translate('char_${c.id}');
          final bought = await _confirmBuy(name, c.price, () => CoinStore.buy('char_${c.id}', c.price));
          if (bought) await _useChar(c);
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.color.withValues(alpha: inUse ? 0.28 : 0.14), AppColors.surface],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: inUse ? c.color : AppColors.line, width: inUse ? 2 : 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: Opacity(
                opacity: owned ? 1 : 0.6,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CharacterAvatar(characterId: c.id, size: 96),
                    if (!owned)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(Icons.lock_rounded, size: 18, color: AppColors.textDim),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(lm.translate('char_${c.id}'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(13, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            action,
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color, {bool filled = false}) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(text, style: AppTextStyles.text(12, color: filled ? Colors.white : color, weight: FontWeight.w800)),
      );

  Widget _pricePill(int price, bool affordable) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: affordable ? AppColors.coin : AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 15),
            const SizedBox(width: 5),
            Text(formatCount(price),
                style: AppTextStyles.display(13, color: affordable ? Colors.white : AppColors.textDim)),
          ],
        ),
      );

  // ── 장비: 존별 · 부위별 ──
  String _gearZone = 'cyber';

  /// 존에서 지금 장착한 장비(부위마다 하나, 없으면 기본)
  List<String> _equippedGear(String zone) => [
        for (final slot in Gear.slotsOf(zone))
          CoinStore.equipped(Gear.slotKey(zone, slot), Gear.defaultOf(zone, slot).id),
      ];

  Widget _gear(LanguageManager lm) {
    final zone = _gearZone;
    final world = WorldData.getWorld(zone);
    final base = CharacterData.getCharacter(_selectedCharId).color;
    final equipped = _equippedGear(zone);
    final darkFloor = world.floor.computeLuminance() < 0.4;
    final ink = darkFloor ? Colors.white : const Color(0xFF0F172A);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppSegmented(
            items: [for (final w in WorldData.worlds) lm.translate(w.nameKey)],
            index: WorldData.worlds.indexWhere((w) => w.id == zone),
            onChanged: (i) => setState(() => _gearZone = WorldData.worlds[i].id),
          ),
        ),
        const SizedBox(height: 12),
        // 착용 미리보기 — 그 존의 바닥 위에 선 캐릭터 + 지금 입은 장비 목록
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 176,
              color: world.floor,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset('assets/images/worlds/${zone}_bg.png',
                        fit: BoxFit.cover, alignment: Alignment.bottomCenter, errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                  Positioned.fill(child: ColoredBox(color: world.floor.withValues(alpha: 0.35))),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(999)),
                      child: Text(lm.translate('gear_preview'), style: AppTextStyles.text(11, color: Colors.white, weight: FontWeight.w800)),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: Center(child: _ZonberStage(color: base, body: _selectedCharId, gear: equipped, size: 150))),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final id in equipped)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(lm.translate(Gear.slotLabelKey(Gear.byId(id)!.slot)),
                                        style: AppTextStyles.text(11, color: ink.withValues(alpha: 0.7), weight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    Text(lm.translate('gear_$id'), style: AppTextStyles.text(12, color: ink, weight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(lm.translate('gear_hint'),
              textAlign: TextAlign.center, style: AppTextStyles.text(11, color: AppColors.textDim)),
        ),
        // 부위별 아이템 — 아이템 그림만 크게, 가로로 넘긴다
        for (final slot in Gear.slotsOf(zone)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(lm.translate(Gear.slotLabelKey(slot)), style: AppTextStyles.label()),
          ),
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: Gear.itemsOf(zone, slot).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => SizedBox(width: 100, child: _gearCard(lm, Gear.itemsOf(zone, slot)[i], base, equipped)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _gearCard(LanguageManager lm, GearItem g, Color base, List<String> equipped) {
    final slotKey = Gear.slotKey(g.zone, g.slot);
    final plateLocked = g.needsPlate && _plates[g.zone] == null;
    final owned = !plateLocked && (g.price == 0 || CoinStore.owns(g.id));
    final inUse = CoinStore.equipped(slotKey, Gear.defaultOf(g.zone, g.slot).id) == g.id;
    final accent = WorldData.getWorld(g.zone).accent;
    Widget action;
    if (inUse) {
      action = _pill(lm.translate('shop_equipped'), accent, filled: true);
    } else if (plateLocked) {
      action = _pill(lm.translate('shop_need_plate'), AppColors.gold);
    } else if (owned) {
      action = _pill(lm.translate('shop_equip'), accent);
    } else {
      action = _pricePill(g.price, CoinStore.balance.value >= g.price);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (inUse) return;
        if (plateLocked) {
          _toast(lm.translate('shop_need_plate_msg').replaceAll('{world}', lm.translate(WorldData.getWorld(g.zone).nameKey)));
          return;
        }
        if (!owned) {
          final bought = await _confirmBuy(lm.translate(g.nameKey), g.price, () => CoinStore.buy(g.id, g.price));
          if (!bought) return;
        }
        await CoinStore.equip(slotKey, g.id);
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: inUse ? accent : AppColors.line, width: inUse ? 2 : 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // 아이템 그림만(캐릭터 없이) — 미리보기와 한눈에 구분되게
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(8),
                      child: Opacity(
                        opacity: plateLocked ? 0.4 : 1,
                        child: Image.asset(
                          'assets/images/game/gear_${g.id}.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => CustomPaint(
                            painter: ZonberPainter(ZonberLook(color: base, body: _selectedCharId, gear: [g.id])),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (plateLocked)
                    Positioned(right: 4, top: 4, child: Icon(Icons.lock_rounded, size: 14, color: AppColors.gold)),
                  if (inUse)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(lm.translate(g.nameKey),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(11.5, weight: FontWeight.w800)),
            const SizedBox(height: 5),
            FittedBox(child: action),
          ],
        ),
      ),
    );
  }

  // ── 꾸미기: 잔상 · 오라 ──
  Widget _style(LanguageManager lm) {
    final base = CharacterData.getCharacter(_selectedCharId).color;
    Widget section(CosmeticKind kind, String titleKey) {
      final items = Cosmetics.ofKind(kind);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(lm.translate(titleKey), style: AppTextStyles.label()),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [for (final c in items) _cosmeticCard(lm, c, base)],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        section(CosmeticKind.trail, 'shop_sec_trail'),
        const SizedBox(height: 12),
        section(CosmeticKind.aura, 'shop_sec_aura'),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        Text(lm.translate('shop_style_note'),
            textAlign: TextAlign.center, style: AppTextStyles.text(11, color: AppColors.textDim)),
      ],
    );
  }

  Widget _cosmeticCard(LanguageManager lm, Cosmetic c, Color base) {
    final kindKey = Cosmetics.kindKey(c.kind);
    final owned = c.price == 0 || CoinStore.owns(c.id);
    final inUse = CoinStore.equipped(kindKey, Cosmetics.defaultOf(c.kind)) == c.id;
    final accent = AppColors.coin;
    Widget action;
    if (inUse) {
      action = _pill(lm.translate('shop_equipped'), accent, filled: true);
    } else if (owned) {
      action = _pill(lm.translate('shop_equip'), accent);
    } else {
      action = _pricePill(c.price, CoinStore.balance.value >= c.price);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (inUse) return;
        if (!owned) {
          final bought = await _confirmBuy(lm.translate(c.nameKey), c.price, () => CoinStore.buy(c.id, c.price));
          if (!bought) return;
        }
        await CoinStore.equip(kindKey, c.id);
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: inUse ? accent.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: inUse ? accent : AppColors.line, width: inUse ? 2 : 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: FittedBox(
                child: CosmeticPreview(
                  item: c,
                  base: base,
                  size: 64,
                  character: CharacterAvatar(characterId: _selectedCharId, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(lm.translate(c.nameKey),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(13, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            action,
          ],
        ),
      ),
    );
  }

  // ── 기타: 변경권 · 광고 제거 ──
  Widget _extras(LanguageManager lm) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _extraRow(
          icon: Icons.badge_rounded,
          title: lm.translate('shop_nickname_ticket'),
          desc: lm.translate('shop_ticket_desc').replaceAll('{n}', '$_nicknameTickets'),
          trailing: _pricePill(ticketPrice, CoinStore.balance.value >= ticketPrice),
          onTap: () async {
            final ok = await _confirmBuy(lm.translate('shop_nickname_ticket'), ticketPrice, () => CoinStore.spend(ticketPrice));
            if (ok) {
              await UserProfileManager.setNicknameTickets(_nicknameTickets + 1);
              await _load();
            }
          },
        ),
        const SizedBox(height: 10),
        _extraRow(
          icon: Icons.flag_rounded,
          title: lm.translate('shop_country_ticket'),
          desc: lm.translate('shop_ticket_desc').replaceAll('{n}', '$_countryTickets'),
          trailing: _pricePill(ticketPrice, CoinStore.balance.value >= ticketPrice),
          onTap: () async {
            final ok = await _confirmBuy(lm.translate('shop_country_ticket'), ticketPrice, () => CoinStore.spend(ticketPrice));
            if (ok) {
              await UserProfileManager.setCountryTickets(_countryTickets + 1);
              await _load();
            }
          },
        ),
        const SizedBox(height: 10),
        _extraRow(
          icon: Icons.block_rounded,
          title: lm.translate('shop_remove_ads'),
          desc: lm.translate('shop_remove_ads_desc'),
          trailing: _pill(lm.translate('shop_preparing'), AppColors.textDim),
          onTap: null,
        ),
      ],
    );
  }

  Widget _extraRow({
    required IconData icon,
    required String title,
    required String desc,
    required Widget trailing,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.textDim, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.text(14, weight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(desc, style: AppTextStyles.text(11, color: AppColors.textDim)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// 장비 미리보기 — 존버가 제자리에서 걷고 날개·불꽃이 움직인다
class _ZonberStage extends StatefulWidget {
  final Color color;
  final String body;
  final List<String> gear;
  final double size;
  const _ZonberStage({required this.color, required this.body, required this.gear, required this.size});

  @override
  State<_ZonberStage> createState() => _ZonberStageState();
}

class _ZonberStageState extends State<_ZonberStage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 6;
        // 3초마다 한 번 신난 표정
        final face = (t % 3) > 2.5 ? ZonberFace.happy : ZonberFace.normal;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: ZonberPainter(ZonberLook(color: widget.color, body: widget.body, gear: widget.gear, t: t, moving: true, face: face)),
        );
      },
    );
  }
}
