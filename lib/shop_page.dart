import 'package:flutter/material.dart';

import 'character_data.dart';
import 'coin_store.dart';
import 'cosmetics.dart';
import 'gear.dart';
import 'gear_painter.dart';
import 'zonber_painter.dart';
import 'game_art.dart';
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
    final skinned = _skinId != Cosmetics.defaultSkin;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        // 고른 캐릭터 — 크게, 움직이며(지금 입은 스킨 그대로)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [sel.color.withValues(alpha: 0.30), sel.color.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 6,
                  bottom: 44,
                  child: Center(child: _ZonberStage(color: sel.color, body: sel.id, gear: const [], size: 140, skin: _skinId)),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    children: [
                      Text(lm.translate('char_${sel.id}'), style: AppTextStyles.text(16, weight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(skinned ? lm.translate('char_skin_on') : lm.translate('char_desc_${sel.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.text(12, color: AppColors.textDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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

  /// 지금 입은 몸통 스킨
  String get _skinId => CoinStore.equipped(Cosmetics.kindKey(CosmeticKind.skin), Cosmetics.defaultSkin);

  // ── 장비: 존별 · 부위별 ──
  String _gearZone = 'cyber';

  /// 미리 입어 보기 — 슬롯 키 → 아이템 id(Gear.none = 벗기). 사지 않은 것·명패 장비도 입어 볼 수 있다
  final Map<String, String> _tryOn = {};

  String _wornId(String zone, GearSlot slot) => Gear.wornId(zone, slot, CoinStore.equipped);

  /// 미리보기에 보이는 것 — 입어 보는 중이면 그것, 아니면 착용 중인 것
  String _previewId(String zone, GearSlot slot) => _tryOn[Gear.slotKey(zone, slot)] ?? _wornId(zone, slot);

  List<String> _previewGear(String zone) => [
        for (final slot in Gear.slotsOf(zone))
          if (_previewId(zone, slot) != Gear.none) _previewId(zone, slot),
      ];

  bool _isTrying(String zone) => Gear.slotsOf(zone).any((s) => _previewId(zone, s) != _wornId(zone, s));

  Widget _gear(LanguageManager lm) {
    final zone = _gearZone;
    final world = WorldData.getWorld(zone);
    final base = CharacterData.getCharacter(_selectedCharId).color;
    final preview = _previewGear(zone);
    final trying = _isTrying(zone);
    return Column(
      children: [
        // 스테이지 필터 — 스크롤해도 늘 위에 있다
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: StageFilter(selectedId: zone, onChanged: (id) => setState(() => _gearZone = id)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 24),
            children: [
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
                  // 캐릭터 — 항상 가운데
                  Center(child: _ZonberStage(color: base, body: _selectedCharId, gear: preview, size: 150, skin: _skinId)),
                  if (trying)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _tryOn.removeWhere((k, _) => k.startsWith('gear_${zone}_'))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.undo_rounded, size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(lm.translate('gear_reset'), style: AppTextStyles.text(11, color: Colors.white, weight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // 부위 램프 — 입었으면 켜지고(아이템 그림), 비었으면 꺼진다
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final slot in Gear.slotsOf(zone))
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: _SlotLamp(
                              slot: slot,
                              itemId: _previewId(zone, slot),
                              trying: _previewId(zone, slot) != _wornId(zone, slot),
                              accent: world.accent,
                              base: base,
                            ),
                          ),
                      ],
                    ),
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
              itemCount: Gear.itemsOf(zone, slot).length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => SizedBox(
                  width: 100, child: i == 0 ? _noneCard(lm, zone, slot) : _gearCard(lm, Gear.itemsOf(zone, slot)[i - 1], base)),
            ),
          ),
        ],
            ],
          ),
        ),
      ],
    );
  }

  /// 장비 카드 한 장 — 카드를 누르면 미리 입어 보고, 아래 버튼으로 구매·착용한다
  Widget _gearTile({
    required Color accent,
    required bool inUse,
    required bool previewing,
    required bool locked,
    required Widget art,
    required String label,
    required Widget action,
    required VoidCallback onTap,
    required VoidCallback onAction,
  }) {
    final border = inUse ? accent : (previewing ? accent.withValues(alpha: 0.55) : AppColors.line);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: inUse || previewing ? 2 : 1),
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
                      child: Opacity(opacity: locked ? 0.45 : 1, child: art),
                    ),
                  ),
                  if (locked) Positioned(left: 4, top: 4, child: Icon(Icons.lock_rounded, size: 14, color: AppColors.gold)),
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
                    )
                  else if (previewing)
                    Positioned(right: 4, top: 4, child: Icon(Icons.visibility_rounded, size: 16, color: accent)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(11.5, weight: FontWeight.w800)),
            const SizedBox(height: 5),
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: onAction, child: FittedBox(child: action)),
          ],
        ),
      ),
    );
  }

  /// 부위 비우기 카드(맨 앞) — 기본 상태
  Widget _noneCard(LanguageManager lm, String zone, GearSlot slot) {
    final slotKey = Gear.slotKey(zone, slot);
    final accent = WorldData.getWorld(zone).accent;
    final inUse = _wornId(zone, slot) == Gear.none;
    return _gearTile(
      accent: accent,
      inUse: inUse,
      previewing: _previewId(zone, slot) == Gear.none,
      locked: false,
      art: Icon(Icons.do_not_disturb_alt_rounded, size: 30, color: AppColors.textDim.withValues(alpha: 0.6)),
      label: lm.translate('gear_none'),
      action: inUse ? _pill(lm.translate('shop_equipped'), accent, filled: true) : _pill(lm.translate('shop_take_off'), accent),
      onTap: () => setState(() => _tryOn[slotKey] = Gear.none),
      onAction: () async {
        if (inUse) return;
        await CoinStore.equip(slotKey, Gear.none);
        _tryOn.remove(slotKey);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _gearCard(LanguageManager lm, GearItem g, Color base) {
    final slotKey = Gear.slotKey(g.zone, g.slot);
    final plateLocked = g.needsPlate && _plates[g.zone] == null;
    final owned = !plateLocked && (g.price == 0 || CoinStore.owns(g.id));
    final inUse = _wornId(g.zone, g.slot) == g.id;
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
    return _gearTile(
      accent: accent,
      inUse: inUse,
      previewing: _previewId(g.zone, g.slot) == g.id,
      locked: plateLocked,
      art: GameArt.image('gear_${g.id}', fallback: () => CustomPaint(painter: GearIconPainter(g.id, base))),
      label: lm.translate(g.nameKey),
      action: action,
      // 카드 — 누구나 미리 입어 본다
      onTap: () => setState(() => _tryOn[slotKey] = g.id),
      // 버튼 — 구매·착용
      onAction: () async {
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
        _tryOn.remove(slotKey);
        if (mounted) setState(() {});
      },
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
        section(CosmeticKind.skin, 'shop_sec_skin'),
        const SizedBox(height: 12),
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
                child: c.kind == CosmeticKind.skin
                    // 스킨 — 입은 모습 그대로(움직이며 반짝임·흐름이 보인다)
                    ? _ZonberStage(color: base, body: _selectedCharId, gear: const [], size: 64, skin: c.id)
                    : CosmeticPreview(
                        item: c,
                        base: base,
                        size: 64,
                        character: CharacterAvatar(characterId: _selectedCharId, size: 32, skin: _skinId),
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
  final String? skin;
  const _ZonberStage({required this.color, required this.body, required this.gear, required this.size, this.skin});

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
          painter: ZonberPainter(ZonberLook(color: widget.color, body: widget.body, skin: widget.skin, gear: widget.gear, t: t, moving: true, face: face)),
        );
      },
    );
  }
}

/// 장비 미리보기의 부위 램프 — 입었으면 아이템 그림으로 켜지고, 비었으면 부위 아이콘만 흐리게.
/// 입어 보는 중(아직 착용 안 함)이면 오른쪽 위에 작은 점.
class _SlotLamp extends StatelessWidget {
  final GearSlot slot;
  final String itemId;
  final bool trying;
  final Color accent;
  final Color base;
  const _SlotLamp({required this.slot, required this.itemId, required this.trying, required this.accent, required this.base});

  static IconData _icon(GearSlot s) => switch (s) {
        GearSlot.head => Icons.face_rounded,
        GearSlot.hands => Icons.back_hand_rounded,
        GearSlot.back => Icons.flight_rounded,
        GearSlot.feet => Icons.directions_walk_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final on = itemId != Gear.none;
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: on ? Colors.white.withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: on ? accent : Colors.white.withValues(alpha: 0.25), width: on ? 2 : 1),
            ),
            child: on
                ? CustomPaint(painter: GearIconPainter(itemId, base))
                : Icon(_icon(slot), size: 15, color: Colors.white.withValues(alpha: 0.45)),
          ),
          if (trying)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: AppColors.coin, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
              ),
            ),
        ],
      ),
    );
  }
}
