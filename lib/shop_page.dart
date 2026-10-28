import 'package:flutter/material.dart';

import 'achievement_manager.dart';
import 'audio_manager.dart';
import 'avatar.dart';
import 'badges.dart';
import 'character_data.dart';
import 'coin_store.dart';
import 'cosmetics.dart';
import 'design_system.dart';
import 'gear.dart';
import 'gear_painter.dart';
import 'haptics.dart';
import 'language_manager.dart';
import 'pets.dart';
import 'services/auth_service.dart';
import 'user_profile.dart';
import 'world_config.dart';

/// 내 가방 — 가진 것을 입어 보고 바로 장착한다. 아직 없는 것은 미리보기만 되고, 코인으로 산다. (docs/SHOP.md §상점 화면)
///
/// 2026-10-28 구조를 다시 짰다 — **위에서 아래로 셋뿐**:
///   1. 미리보기(내 아바타 — 지금 존 바닥 위)
///   2. 탭 한 줄: 캐릭터 · 스킨 · 잔상 · 오라 · 장비 (장비 탭에만 존 고르기가 있다 — 장비만 존마다 다르다)
///   3. 그 탭의 그리드(싼 것부터, 자리가 바뀌지 않는다) — 가진 것을 누르면 바로 장착, 없는 것을 누르면 입어 보기 + 아래 구매 바
/// 카드 상태는 둘만 표시한다 — **장착 중**(존 색 테두리 + 체크) · **입어 보는 중**(흰 테두리 + 눈). 가격은 안 가진 것에만.
/// 장착한 모습이 곧 내 아바타다 — 게임·랭킹·프로필이 같은 모습을 쓴다.
/// (클래스 이름 ShopPage 는 예전 이름 그대로다 — 부르는 곳이 많아 화면 이름만 바꿨다)
class ShopPage extends StatefulWidget {
  final VoidCallback onBack;

  /// 하단 탭으로 열리면 false — 상단 뒤로 가기 버튼을 숨긴다
  final bool showBack;

  /// 미리보기와 장비 탭이 처음 보여 줄 존 — 홈에서 고른 존을 넘긴다(없으면 첫 존)
  final String? zoneId;

  const ShopPage({super.key, required this.onBack, this.showBack = true, this.zoneId});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

/// 가방 탭 — 캐릭터 · 꾸미기 3종 · 존 장비
enum _Tab { character, skin, trail, aura, gear }

class _ShopPageState extends State<ShopPage> {
  String _selectedCharId = Avatar.defaultCharacterId;
  bool _busy = false;

  /// 처음 들어와 서버와 맞추는 중 — 잔액 옆에 작은 스피너
  bool _syncing = true;

  /// 내 뱃지 — 뱃지 보상 장비·뱃지 해금 캐릭터 판정
  Set<String> _badges = {};

  _Tab _tab = _Tab.character;

  /// 미리보기·장비 탭의 존
  late String _zone = WorldData.getWorld(widget.zoneId ?? WorldData.defaultWorld.id).id;

  /// 입어 보는 중인 것 — 슬롯 키(장비 `gear_{존}_{부위}` · 꾸미기 `skin`/`trail`/`aura`) → 아이템 id. 탭을 바꾸면 비운다
  final Map<String, String> _tryOn = {};

  /// 입어 보는 중인 캐릭터(아직 내 것이 아닌)
  String? _tryCharId;

  /// 아래 구매 바에 올라온 것 — 마지막으로 누른 **안 가진** 물건
  _BagItem? _picked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 상점에 들어오면 원격을 한 번 읽는다 — 백오피스에서 준 코인·아이템이 바로 보인다
    if (!AuthService.isGuest) await UserProfileManager.syncProfile();
    await CoinStore.load();
    final profile = await UserProfileManager.getProfile();
    final badges = (await AchievementManager.getMine()).toSet();
    // 코인 해금을 켜기 전부터 쓰던 캐릭터는 보유로 인정
    final cur = CharacterData.getCharacter(profile['characterId'] ?? Avatar.defaultCharacterId);
    if (cur.price > 0 && !CoinStore.owns('char_${cur.id}')) await CoinStore.grant('char_${cur.id}');
    if (!mounted) return;
    setState(() {
      _badges = badges;
      _selectedCharId = profile['characterId'] ?? Avatar.defaultCharacterId;
      _syncing = false;
    });
  }

  // ── 보유 판정 ──
  /// 캐릭터 — 기본 · 코인 구매 · 해금 뱃지(character_data.dart unlockKey) 중 하나
  bool _ownsChar(Character c) =>
      c.price == 0 ||
      CharacterData.allUnlocked ||
      CoinStore.owns('char_${c.id}') ||
      (c.unlockKey != null && _badges.contains(c.unlockKey));

  bool _badgeLocked(GearItem g) => g.needsBadge != null && !_badges.contains(g.needsBadge);

  bool _ownsGear(GearItem g) => !_badgeLocked(g) && (g.price == 0 || CoinStore.owns(g.id));

  bool _ownsCosmetic(Cosmetic c) => c.price == 0 || CoinStore.owns(c.id);

  // ── 효과음 ──
  /// 착용 — "뽁" + 약한 진동
  void _equipFx() {
    AudioManager().playSfx(Sfx.equip, volume: 0.7);
    Haptics.light();
  }

  /// 입어 보기 — 작은 "뽁"
  void _tryFx() {
    AudioManager().playSfx(Sfx.equip, volume: 0.35, minGapMs: 80);
    Haptics.tick();
  }

  // ── 동작 ──
  void _selectTab(_Tab t) {
    if (t == _tab) return;
    _tryFx();
    setState(() {
      _tab = t;
      _clearTry();
    });
  }

  /// 입어 보던 것을 전부 내려놓는다(탭을 바꾸거나 장착했을 때)
  void _clearTry() {
    _tryOn.clear();
    _tryCharId = null;
    _picked = null;
  }

  /// 카드를 눌렀을 때 — 가진 것은 **바로 장착**, 없는 것은 **입어 보기**(미리보기에 입혀지고 아래 구매 바가 뜬다)
  Future<void> _pick(_BagItem item) async {
    if (item.owned) {
      _equipFx();
      await item.equip();
      if (!mounted) return;
      setState(_clearTry);
      return;
    }
    _tryFx();
    setState(() {
      if (item.slotKey == null) {
        _tryCharId = item.id;
      } else {
        _tryOn[item.slotKey!] = item.id;
      }
      _picked = item;
    });
  }

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

  /// 구매 뒤 — 수집 뱃지 검사
  Future<void> _checkCollectionBadges() async {
    final owned = CoinStore.ownedIds;
    await Badges.evaluate(BadgeContext(
      stats: await BadgeStatsStore.load(),
      ownedItems: owned.where((id) => !id.startsWith('char_')).length,
      ownedCharacters:
          CharacterData.availableCharacters.where((ch) => ch.price == 0 || owned.contains('char_${ch.id}')).length,
    ));
  }

  /// 구매 확인 → 코인 차감. 성공하면 true
  Future<bool> _confirmBuy(String itemName, int price, Future<bool> Function() buy) async {
    final lm = LanguageManager.of(context, listen: false);
    if (AuthService.isGuest) {
      _toast(lm.translate('guest_login_to_save')); // 게스트는 사지 않는다(코인은 기기에만 · 저장 없음)
      return false;
    }
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
    final done = mounted ? await runBusy(context, buy) : await buy(); // 사는 동안 스피너
    if (mounted) setState(() => _busy = false);
    _toast(lm.translate(done ? 'shop_bought' : 'shop_not_enough'));
    if (done) {
      AudioManager().playSfx(Sfx.purchase, volume: 0.8);
      Haptics.medium();
      _checkCollectionBadges();
    }
    return done;
  }

  /// 구매 바의 [구매] — 사면 그대로 장착된다
  Future<void> _buyPicked() async {
    final item = _picked;
    final buy = item?.buy;
    if (item == null || buy == null) return;
    final bought = await _confirmBuy(item.label, item.price, buy);
    if (!bought || !mounted) return;
    _equipFx();
    await item.equip();
    if (mounted) setState(_clearTry);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ── 지금 보이는 한 벌 ──
  String get _previewCharId => _tryCharId ?? _selectedCharId;

  String _cosId(CosmeticKind kind) =>
      _tryOn[Cosmetics.kindKey(kind)] ?? CoinStore.equipped(Cosmetics.kindKey(kind), Cosmetics.defaultOf(kind));

  String get _skinId => _cosId(CosmeticKind.skin);

  String _wornGear(GearSlot slot) => Gear.wornId(_zone, slot, CoinStore.equipped);

  /// 미리보기에 보이는 장비 — 입어 보는 게 있으면 그것, 아니면 장착 중인 것
  String _previewGear(GearSlot slot) => _tryOn[Gear.slotKey(_zone, slot)] ?? _wornGear(slot);

  /// 지금 미리 보고 있는 아바타 한 벌 — 착용 중인 것 위에 '입어 보는 중'을 얹는다(avatar.dart)
  Avatar get _previewAvatar => Avatar(
        characterId: _previewCharId,
        skinId: _skinId,
        trailId: _cosId(CosmeticKind.trail),
        auraId: _cosId(CosmeticKind.aura),
        gearByZone: {
          _zone: [
            for (final slot in Gear.slotsOf(_zone))
              if (_previewGear(slot) != Gear.none) _previewGear(slot),
          ],
        },
      );

  Color get _accent => WorldData.getWorld(_zone).accent;

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return NeonScaffold(
      title: lm.translate('nav_bag'),
      showBackButton: widget.showBack,
      onBack: widget.onBack,
      // 잔액은 머리 오른쪽에 — 무엇을 사든 늘 같은 자리에 보인다
      actions: [
        if (_syncing) const Padding(padding: EdgeInsets.only(right: 8), child: AppSpinner(size: 16, stroke: 2)),
        ValueListenableBuilder<int>(
          valueListenable: CoinStore.balance,
          builder: (context, b, _) => CoinChip(amount: b, size: 15),
        ),
      ],
      body: ValueListenableBuilder<int>(
        valueListenable: CoinStore.balance, // 잔액이 바뀌면 "살 수 있음" 색도 다시 그린다
        builder: (context, _, _) => LayoutBuilder(
          builder: (context, box) {
            // 미리보기 높이 — 기기 높이에 맞춰(작은 폰은 줄여 그리드가 두 줄은 보이게)
            final previewH = (box.maxHeight * 0.30).clamp(168.0, 230.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _preview(lm, previewH),
                ),
                const SizedBox(height: 10),
                _tabs(lm),
                const SizedBox(height: 8),
                Expanded(child: _list(lm)),
                _buyBar(lm),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 1. 미리보기 — 지금 존의 바닥 위에 선 내 아바타. 장착한 것 + 입어 보는 것이 그대로 보인다 ──
  Widget _preview(LanguageManager lm, double height) {
    final world = WorldData.getWorld(_zone);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: height,
        color: world.floor,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/worlds/${_zone}_bg.png',
                  fit: BoxFit.cover, alignment: Alignment.bottomCenter, errorBuilder: (_, _, _) => const SizedBox()),
            ),
            Positioned.fill(child: ColoredBox(color: world.floor.withValues(alpha: 0.35))),
            Center(child: AvatarStage(avatar: _previewAvatar, zone: _zone, size: height * 0.69)),
            // 왼쪽 아래 — 캐릭터 이름 · 오른쪽 아래 — 어느 존의 장비를 입고 있는지
            Positioned(left: 10, bottom: 8, child: _pill(lm.translate('char_$_previewCharId'))),
            Positioned(right: 10, bottom: 8, child: _pill('ZONE ${world.difficulty}')),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: AppTextStyles.text(11, color: Colors.white, weight: FontWeight.w800)),
      );

  // ── 2. 탭 한 줄 — 글자로. 긴 언어도 잘리지 않게 옆으로 넘긴다 ──
  Widget _tabs(LanguageManager lm) {
    final labels = {
      _Tab.character: lm.translate('shop_tab_characters'),
      _Tab.skin: lm.translate('shop_tab_skin'),
      _Tab.trail: lm.translate('shop_tab_trail'),
      _Tab.aura: lm.translate('shop_tab_aura'),
      _Tab.gear: lm.translate('shop_tab_gear'),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final t in _Tab.values) ...[
            if (t != _Tab.values.first) const SizedBox(width: 6),
            _tabChip(labels[t]!, t == _tab, () => _selectTab(t)),
          ],
        ],
      ),
    );
  }

  Widget _tabChip(String label, bool on, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? _accent : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? _accent : AppColors.line),
          ),
          child: Text(label,
              style: AppTextStyles.text(12.5, color: on ? AppColors.on(_accent) : AppColors.textDim, weight: FontWeight.w800)),
        ),
      );

  // ── 3. 그리드 — 탭 하나에 한 칸(장비는 부위마다 한 칸) ──
  Widget _list(LanguageManager lm) {
    final sections = switch (_tab) {
      _Tab.character => [_Section(lm.translate('shop_tab_characters'), _charItems(lm))],
      _Tab.skin => [_Section(lm.translate('shop_tab_skin'), _cosmeticItems(lm, CosmeticKind.skin))],
      _Tab.trail => [_Section(lm.translate('shop_tab_trail'), _cosmeticItems(lm, CosmeticKind.trail))],
      _Tab.aura => [_Section(lm.translate('shop_tab_aura'), _cosmeticItems(lm, CosmeticKind.aura))],
      _Tab.gear => [
          for (final slot in Gear.slotsOf(_zone)) _Section(lm.translate(Gear.slotLabelKey(slot)), _gearItems(lm, slot)),
        ],
    };
    return CustomScrollView(
      key: ValueKey('${_tab.name}_$_zone'), // 탭·존을 바꾸면 맨 위부터
      slivers: [
        // 장비만 존마다 다르다 — 장비 탭에서만 존을 고른다
        if (_tab == _Tab.gear)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            sliver: SliverToBoxAdapter(
              child: StageFilter(
                selectedId: _zone,
                onChanged: (id) => setState(() {
                  _zone = id;
                  _clearTry();
                }),
              ),
            ),
          ),
        for (final s in sections) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 2, 24, 8),
            sliver: SliverToBoxAdapter(child: _sectionHead(s)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate((context, i) => _tile(lm, s.items[i]), childCount: s.items.length),
            ),
          ),
        ],
        // 규칙 두 줄 — 외형뿐이라는 것 · 코인 보너스는 가격으로 정해진다는 것
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lm.translate('shop_style_note'), style: AppTextStyles.text(11, color: AppColors.textDim)),
                const SizedBox(height: 3),
                Text(lm.translate('shop_bonus_rule'), style: AppTextStyles.text(11, color: AppColors.textDim)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 칸 머리 — 이름 · 가진 수 / 전체(기본·벗기는 세지 않는다)
  Widget _sectionHead(_Section s) {
    final counted = s.items.where((i) => i.price > 0 || i.badgeKey != null).toList();
    final mine = counted.where((i) => i.owned).length;
    return Row(
      children: [
        Text(s.label, style: AppTextStyles.label()),
        const SizedBox(width: 8),
        Text('$mine / ${counted.length}', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
      ],
    );
  }

  // ── 물건 목록 — 싼 것부터(기본 → 코인 → 뱃지 보상은 값이 0 이라 앞에 온다). 사도 자리가 바뀌지 않는다 ──
  List<_BagItem> _sorted(List<_BagItem> list) => list..sort((a, b) => a.price.compareTo(b.price));

  List<_BagItem> _charItems(LanguageManager lm) => _sorted([
        for (final c in CharacterData.availableCharacters)
          _BagItem(
            id: c.id,
            label: lm.translate('char_${c.id}'),
            price: c.price,
            owned: _ownsChar(c),
            badgeKey: c.unlockKey,
            equipped: c.id == _selectedCharId,
            previewing: _tryCharId == c.id && c.id != _selectedCharId,
            art: AvatarView.character(c.id, size: 52, skin: _skinId),
            buy: () => CoinStore.buy('char_${c.id}', c.price),
            equip: () => _useChar(c),
          ),
      ]);

  List<_BagItem> _gearItems(LanguageManager lm, GearSlot slot) {
    final slotKey = Gear.slotKey(_zone, slot);
    final base = CharacterData.getCharacter(_previewCharId).color;
    final worn = _wornGear(slot);
    final preview = _previewGear(slot);
    return _sorted([
      // 벗기 — 늘 맨 앞(가진 것으로 친다)
      _BagItem(
        id: Gear.none,
        label: lm.translate('gear_none'),
        price: -1,
        owned: true,
        slotKey: slotKey,
        equipped: worn == Gear.none,
        previewing: preview == Gear.none && worn != Gear.none,
        art: Icon(Icons.do_not_disturb_alt_rounded, size: 28, color: AppColors.textDim.withValues(alpha: 0.6)),
        equip: () => CoinStore.equip(slotKey, Gear.none),
      ),
      for (final g in Gear.shopItemsOf(_zone, slot, CoinStore.owns))
        _BagItem(
          id: g.id,
          label: lm.translate(g.nameKey),
          price: g.price,
          owned: _ownsGear(g),
          badgeKey: g.needsBadge,
          badgeLocked: _badgeLocked(g),
          slotKey: slotKey,
          equipped: worn == g.id,
          previewing: preview == g.id && worn != g.id,
          bonus: g.bonus,
          art: CustomPaint(painter: GearIconPainter(g.id, base)),
          buy: _badgeLocked(g) ? null : () => CoinStore.buy(g.id, g.price),
          equip: () => CoinStore.equip(slotKey, g.id),
        ),
    ]);
  }

  List<_BagItem> _cosmeticItems(LanguageManager lm, CosmeticKind kind) {
    final kindKey = Cosmetics.kindKey(kind);
    final base = CharacterData.getCharacter(_previewCharId).color;
    final worn = CoinStore.equipped(kindKey, Cosmetics.defaultOf(kind));
    final preview = _cosId(kind);
    return _sorted([
      for (final c in Cosmetics.ofKind(kind))
        _BagItem(
          id: c.id,
          label: lm.translate(c.nameKey),
          price: c.price,
          owned: _ownsCosmetic(c),
          slotKey: kindKey,
          equipped: worn == c.id,
          previewing: preview == c.id && worn != c.id,
          bonus: c.bonus,
          art: c.pet
              ? PetPreview(petId: c.id, size: 48) // 펫 오라 — 시안 아트 펫
              : kind == CosmeticKind.skin
                  // 스킨 — 입은 모습 그대로(움직이며 반짝임·흐름이 보인다)
                  ? AvatarStage(avatar: Avatar(characterId: _previewCharId, skinId: c.id), size: 48, cosmetics: false)
                  : CosmeticPreview(
                      item: c,
                      base: base,
                      size: 48,
                      character: AvatarView.character(_previewCharId, size: 24, skin: _skinId),
                    ),
          buy: () => CoinStore.buy(c.id, c.price),
          equip: () => CoinStore.equip(kindKey, c.id),
        ),
    ]);
  }

  // ── 카드 한 장 ──
  /// 장착 중 = 존 색 테두리 + 체크 · 입어 보는 중 = 흰 테두리 + 눈 · 안 가진 것 = 흐린 그림 + 가격(뱃지 보상은 뱃지 표시)
  Widget _tile(LanguageManager lm, _BagItem item) {
    final accent = _accent;
    final ring = item.equipped ? accent : (item.previewing ? AppColors.text : AppColors.line);
    final marked = item.equipped || item.previewing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pick(item),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: item.equipped ? accent.withValues(alpha: 0.10) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ring, width: marked ? 2 : 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(6),
                      child: Opacity(opacity: item.owned ? 1 : 0.6, child: item.art), // 그림은 칸을 꽉 채운다(CustomPaint 는 크기를 받아야 그린다)
                    ),
                  ),
                  // 왼쪽 위 — 코인 보너스(가격 구간 규칙)
                  if (!item.bonus.isZero)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.up, borderRadius: BorderRadius.circular(999)),
                        child: Text('+${(item.bonus.coin * 100).round()}%',
                            style: AppTextStyles.display(9, color: AppColors.on(AppColors.up))),
                      ),
                    ),
                  // 오른쪽 위 — 상태
                  if (item.equipped)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded, size: 13, color: AppColors.on(accent)),
                      ),
                    )
                  else if (item.previewing)
                    Positioned(right: 4, top: 4, child: Icon(Icons.visibility_rounded, size: 16, color: AppColors.text)),
                ],
              ),
            ),
            const SizedBox(height: 5),
            // 이름 — 길면 글자를 줄여서 한 줄에 다 보여 준다(자르지 않는다)
            _fitLine(15, item.label, AppTextStyles.text(11.5, weight: FontWeight.w800)),
            const SizedBox(height: 3),
            _tileFoot(lm, item, accent),
          ],
        ),
      ),
    );
  }

  /// 카드 아래 줄(높이 18 고정) — 안 가진 것은 가격(뱃지 보상은 뱃지) · 장착 중은 '착용 중' · 가진 것은 빈 줄
  Widget _tileFoot(LanguageManager lm, _BagItem item, Color accent) {
    Widget child;
    if (item.badgeLocked) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.military_tech_rounded, size: 13, color: AppColors.gold),
          const SizedBox(width: 3),
          Text(lm.translate('shop_need_badge'), style: AppTextStyles.text(10.5, color: AppColors.gold, weight: FontWeight.w800)),
        ],
      );
    } else if (!item.owned) {
      final can = CoinStore.balance.value >= item.price;
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CoinIcon(size: 12),
          const SizedBox(width: 4),
          Text(formatCount(item.price), style: AppTextStyles.display(12, color: can ? AppColors.coin : AppColors.textDim)),
        ],
      );
    } else if (item.equipped) {
      child = Text(lm.translate('shop_equipped'),
          maxLines: 1, style: AppTextStyles.text(10.5, color: accent, weight: FontWeight.w800));
    } else {
      child = const SizedBox();
    }
    return SizedBox(height: 18, child: Center(child: child));
  }

  /// 한 줄짜리 글 — [h] 높이를 지키면서, 넘치면 글자 크기를 줄여 전부 보여 준다
  Widget _fitLine(double h, String text, TextStyle style) => SizedBox(
        height: h,
        width: double.infinity,
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, style: style)),
      );

  // ── 구매 바 — 안 가진 것을 누르면 아래에 뜬다. 구매는 늘 여기 한 곳 ──
  Widget _buyBar(LanguageManager lm) {
    final item = _picked;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: item == null ? const SizedBox(width: double.infinity) : _buyBarBody(lm, item),
    );
  }

  Widget _buyBarBody(LanguageManager lm, _BagItem item) {
    final can = CoinStore.balance.value >= item.price;
    // 둘째 줄 — 뱃지 보상이면 어떤 뱃지가 필요한지, 뱃지로도 열리는 캐릭터면 그 안내, 아니면 코인 보너스
    final String? sub;
    final Color subColor;
    if (item.badgeLocked) {
      final b = item.badgeKey!;
      sub = lm.translate('shop_need_badge_msg').replaceAll('{badge}', lm.translate(b)).replaceAll('{desc}', lm.translate('${b}_desc'));
      subColor = AppColors.gold;
    } else if (item.badgeKey != null) {
      sub = lm.translate('shop_unlock_by_badge').replaceAll('{badge}', lm.translate(item.badgeKey!));
      subColor = AppColors.textDim;
    } else if (!item.bonus.isZero) {
      sub = lm.translate('bonus_coin').replaceAll('{n}', '${(item.bonus.coin * 100).round()}');
      subColor = AppColors.up;
    } else {
      sub = null;
      subColor = AppColors.textDim;
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.text, width: 1.5), // 입어 보는 중 = 흰 테두리(카드와 같은 규칙)
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: item.art,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OneLineText(item.label, style: AppTextStyles.text(14, weight: FontWeight.w800)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.text(11, color: subColor, weight: FontWeight.w700, height: 1.25)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (item.buy != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _buyPicked,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: can ? AppColors.coin : AppColors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 14),
                    const SizedBox(width: 5),
                    Text(formatCount(item.price),
                        style: AppTextStyles.display(13, color: can ? AppColors.on(AppColors.coin) : AppColors.textDim)),
                    const SizedBox(width: 7),
                    Text(lm.translate('shop_buy'),
                        style: AppTextStyles.text(13,
                            color: can ? AppColors.on(AppColors.coin) : AppColors.textDim, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 그리드 한 칸 — 이름 + 물건들
class _Section {
  final String label;
  final List<_BagItem> items;
  const _Section(this.label, this.items);
}

/// 목록에 놓이는 물건 한 개 — 캐릭터·장비·꾸미기를 같은 모양으로 다룬다
class _BagItem {
  final String id;
  final String label;

  /// 코인 값. 0 = 기본 또는 뱃지 보상 · -1 = 벗기(맨 앞)
  final int price;
  final bool owned;

  /// 뱃지 보상 장비인데 아직 그 뱃지가 없다 — 살 수 없다
  final bool badgeLocked;

  /// 얽힌 뱃지 — 장비는 필요한 뱃지, 캐릭터는 코인 없이도 여는 뱃지
  final String? badgeKey;

  /// 입어 보기를 적는 슬롯 키(캐릭터는 null)
  final String? slotKey;
  final bool equipped;
  final bool previewing;
  final GearBonus bonus;
  final Widget art;

  /// 구매 — null 이면 살 수 없다(벗기 · 뱃지 보상)
  final Future<bool> Function()? buy;

  /// 장착(구매 뒤에도 이것)
  final Future<void> Function() equip;

  const _BagItem({
    required this.id,
    required this.label,
    required this.price,
    required this.owned,
    required this.art,
    required this.equip,
    this.badgeLocked = false,
    this.badgeKey,
    this.slotKey,
    this.equipped = false,
    this.previewing = false,
    this.bonus = GearBonus.none,
    this.buy,
  });
}
