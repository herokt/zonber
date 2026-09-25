import 'dart:math';

import 'package:flutter/material.dart';

import 'avatar.dart';
import 'character_data.dart';
import 'coin_store.dart';
import 'cosmetics.dart';
import 'gear.dart';
import 'gear_painter.dart';
import 'badges.dart';
import 'audio_manager.dart';
import 'haptics.dart';
import 'achievement_manager.dart';
import 'design_system.dart';
import 'language_manager.dart';
import 'user_profile.dart';
import 'world_config.dart';
import 'services/auth_service.dart';

/// 내 가방 — 가진 것을 입어 보고 바로 장착한다. 아직 없는 것은 미리보기만 되고, 코인으로 산다. (docs/SHOP.md)
///   캐릭터 · 존별 장비(머리·손·발·등) · 꾸미기(스킨·잔상·오라) · 변경권
/// 장착한 모습이 곧 내 아바타다 — 게임·랭킹·프로필이 같은 모습을 쓴다.
/// (클래스 이름 ShopPage 는 예전 이름 그대로다 — 부르는 곳이 많아 화면 이름만 바꿨다)
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

  String _selectedCharId = 'neon_green';
  bool _busy = false;
  /// 존별 명패 — 황금 복장 해금 조건
  Set<String> _badges = {};

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
    final cur = CharacterData.getCharacter(profile['characterId'] ?? 'neon_green');
    if (cur.price > 0 && !CoinStore.owns('char_${cur.id}')) await CoinStore.grant('char_${cur.id}');
    if (!mounted) return;
    setState(() {
      _badges = badges;
      _selectedCharId = profile['characterId'] ?? 'neon_green';
    });
  }

  bool _ownsChar(Character c) =>
      c.price == 0 || CharacterData.allUnlocked || CoinStore.owns('char_${c.id}');

  Future<void> _useChar(Character c) async {
    _equipFx();
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
  /// 착용 — "뽁" + 약한 진동
  void _equipFx() {
    AudioManager().playSfx(Sfx.equip, volume: 0.7);
    Haptics.light();
  }

  /// 미리 입기 — 작은 "뽁"
  void _tryFx() {
    AudioManager().playSfx(Sfx.equip, volume: 0.35, minGapMs: 80);
    Haptics.tick();
  }

  /// 구매 뒤 — 수집 뱃지 검사
  Future<void> _checkCollectionBadges() async {
    final owned = CoinStore.ownedIds;
    await Badges.evaluate(BadgeContext(
      stats: await BadgeStatsStore.load(),
      ownedItems: owned.where((id) => !id.startsWith('char_')).length,
      ownedCharacters: CharacterData.availableCharacters.where((ch) => ch.price == 0 || owned.contains('char_${ch.id}')).length,
    ));
  }

  Future<bool> _confirmBuy(String itemName, int price, Future<bool> Function() buy) async {
    final lm = LanguageManager.of(context, listen: false);
    if (AuthService.isGuest) {
      _toast(lm.translate('guest_login_to_save')); // 게스트는 사지 않는다(코인 0 · 저장 없음)
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
    final done = await buy();
    if (mounted) setState(() => _busy = false);
    _toast(lm.translate(done ? 'shop_bought' : 'shop_not_enough'));
    if (done) {
      AudioManager().playSfx(Sfx.purchase, volume: 0.8);
      Haptics.medium();
      _checkCollectionBadges();
    }
    return done;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ─────────────────────────────────────────────────────────────
  // 내 가방 — 위에서 아래로 [ZONE 필터] → [카테고리 · 미리보기 · 카테고리] → [카테고리별 가로 목록을 세로로 이어 붙인 스크롤].
  //   · 보유한 것을 누르면 **바로 장착**되고, 그게 곧 내 아바타가 된다.
  //   · 아직 없는 것을 누르면 **미리보기만** 된다(사면 그 자리에서 장착).
  //   · 장착 중 = 주황, 미리보기 = 초록.
  // ─────────────────────────────────────────────────────────────

  /// 장착 중 표시 색
  Color get _equippedColor => AppColors.coin;

  /// 미리보기(고른 것) 표시 색
  Color get _previewColor => AppColors.up;

  /// 지금 보고 있는 칸 — 'char' · 'gear_head' 같은 장비 부위 · 'skin'/'trail'/'aura' · 'extra'
  String _cat = 'char';

  /// 미리 골라 본 캐릭터(아직 쓰기 전)
  String? _tryCharId;

  String get _previewCharId => _tryCharId ?? _selectedCharId;

  /// 아래 목록(카테고리마다 한 칸, 위아래로 스크롤)
  final ScrollController _listScroll = ScrollController();

  /// 카테고리 버튼을 눌러 그 칸으로 움직이는 중 — 이동 중에는 스크롤 위치로 선택을 바꾸지 않는다
  bool _jumping = false;

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final left = _leftCats(lm);
    final right = _rightCats(lm);
    final cats = [...left, ...right];
    if (!cats.any((c) => c.id == _cat)) _cat = cats.first.id;
    _cats = cats;
    return NeonScaffold(
      title: lm.translate('nav_bag'),
      showBackButton: widget.showBack,
      onBack: widget.onBack,
      // 잔액은 머리 오른쪽에 — 무엇을 사든 늘 같은 자리에 보인다
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: CoinStore.balance,
          builder: (context, b, _) => CoinChip(amount: b, size: 15),
        ),
      ],
      body: ValueListenableBuilder<int>(
        valueListenable: CoinStore.balance, // 잔액이 바뀌면 "살 수 있음" 표시도 다시 그린다
        builder: (context, _, _) => LayoutBuilder(
          builder: (context, box) {
            // 미리보기 높이 — 기기 높이에 맞춰(작은 폰은 줄여서 아래 목록 칸이 하나는 다 보이게, 큰 폰은 키운다)
            final previewH = (box.maxHeight * 0.34).clamp(_previewMin, _previewMax).toDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 존 — 늘 맨 위. 장비는 존마다 다르다 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  child: StageFilter(selectedId: _gearZone, onChanged: (id) => setState(() => _gearZone = id)),
                ),
                // ── 카테고리(왼쪽) · 미리보기 · 카테고리(오른쪽) — 셋 다 같은 높이 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: previewH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _catColumn(left),
                        const SizedBox(width: 8),
                        Expanded(child: _previewBox(lm, previewH)),
                        const SizedBox(width: 8),
                        _catColumn(right),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ── 카테고리마다 한 칸(이름·보유 수 + 좌우로 넘기는 목록)을 위아래로 이어 붙인다 ──
                // 고른 칸만 보여 주던 때는 큰 폰에서 아래가 텅 비었다. 버튼을 누르면 그 칸으로 스크롤한다
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onListScroll,
                    child: ListView.builder(
                      controller: _listScroll,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemExtent: _sectionExtent,
                      itemCount: cats.length,
                      itemBuilder: (context, i) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _listHead(lm, cats[i]),
                          SizedBox(height: _stripHeight, child: _itemStrip(lm, cats[i])),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 지금 목록에 놓인 칸들(순서 = 왼쪽 버튼들 → 오른쪽 버튼들)
  List<_BagCat> _cats = const [];

  /// 목록 한 칸 높이 — 머리(34 + 아래 6) + 좌우 목록
  static const double _headHeight = 40;
  static const double _stripHeight = 176;
  static const double _sectionExtent = _headHeight + _stripHeight;

  /// 카테고리 버튼 → 그 칸이 목록 맨 위에 오게 스크롤(끝 칸들은 목록 끝까지만)
  void _jumpTo(String id) {
    final i = _cats.indexWhere((c) => c.id == id);
    setState(() => _cat = id);
    if (i < 0 || !_listScroll.hasClients) return;
    final pos = _listScroll.position;
    final target = min(i * _sectionExtent, pos.maxScrollExtent);
    _jumping = true;
    _listScroll
        .animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic)
        .whenComplete(() => _jumping = false);
  }

  /// 손으로 스크롤하면 맨 위에 걸린 칸의 버튼이 켜진다. 끝까지 내리면 마지막 칸
  bool _onListScroll(ScrollNotification n) {
    if (_jumping || n.depth != 0 || n is! ScrollUpdateNotification || _cats.isEmpty) return false;
    final m = n.metrics;
    int i = ((m.pixels + _sectionExtent * 0.5) / _sectionExtent).floor();
    if (m.maxScrollExtent > 0 && m.pixels >= m.maxScrollExtent - 1) i = _cats.length - 1;
    i = i.clamp(0, _cats.length - 1);
    if (_cats[i].id != _cat) setState(() => _cat = _cats[i].id);
    return false;
  }

  // ── 카테고리 ──
  /// 왼쪽 줄 — 나(캐릭터)와 몸에 두르는 것
  List<_BagCat> _leftCats(LanguageManager lm) => [
        _BagCat('char', Icons.face_retouching_natural_rounded, lm.translate('shop_tab_characters')),
        _BagCat('skin', Icons.palette_rounded, lm.translate('shop_sec_skin')),
        _BagCat('trail', Icons.air_rounded, lm.translate('shop_sec_trail')),
        _BagCat('aura', Icons.blur_on_rounded, lm.translate('shop_sec_aura')),
      ];

  /// 오른쪽 줄 — 이 존에서 입는 장비 부위
  List<_BagCat> _rightCats(LanguageManager lm) => [
        for (final slot in Gear.slotsOf(_gearZone))
          _BagCat('gear_${slot.name}', slotIcon(slot), lm.translate(Gear.slotLabelKey(slot))),
      ];

  /// 미리보기 높이 범위 — 좌우 아이콘 줄도 이 높이에 맞춰 고르게 놓인다(버튼 4개 42×4 가 들어가는 최소)
  static const double _previewMin = 184, _previewMax = 250;

  Widget _catColumn(List<_BagCat> cats) => Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final c in cats) _catButton(c)],
      );

  Widget _catButton(_BagCat c) {
    final on = _cat == c.id;
    // 이 칸에 아직 안 본 것(미보유)이 있으면 점으로 알린다
    return Tooltip(
      message: c.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _tryFx();
          _jumpTo(c.id);
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: on ? AppColors.primary : AppColors.line),
          ),
          child: Icon(c.icon, size: 20, color: on ? Colors.white : AppColors.textDim),
        ),
      ),
    );
  }

  /// 목록 머리 — 칸 이름 · 보유 수 · (미보유를 고르고 있으면) 구매 버튼
  Widget _listHead(LanguageManager lm, _BagCat cat) {
    final items = _itemsFor(lm, cat.id);
    final mine = items.where((i) => i.owned).length;
    final picked = items.where((i) => i.previewing && !i.owned).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 20, 6),
      // 구매 버튼이 생겼다 사라져도 아래 목록이 밀리지 않게 높이를 잡아 둔다
      child: SizedBox(
        height: 34,
        child: Row(
        children: [
          Text(cat.label, style: AppTextStyles.label()),
          const SizedBox(width: 8),
          Text('$mine / ${items.length}', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
          const Spacer(),
          // 미리 보는 중인 물건이 아직 내 것이 아니면 여기서 산다 — 사면 바로 장착된다
          if (picked != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _buyAndEquip(lm, picked),
              child: Container(
                height: 30,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CoinStore.balance.value >= picked.price ? AppColors.coin : AppColors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 14),
                    const SizedBox(width: 5),
                    Text(formatCount(picked.price),
                        style: AppTextStyles.display(12,
                            color: CoinStore.balance.value >= picked.price ? Colors.white : AppColors.textDim)),
                    const SizedBox(width: 6),
                    Text(lm.translate('shop_buy'),
                        style: AppTextStyles.text(12,
                            color: CoinStore.balance.value >= picked.price ? Colors.white : AppColors.textDim,
                            weight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemStrip(LanguageManager lm, _BagCat cat) {
    final items = _itemsFor(lm, cat.id);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Text(lm.translate('shop_owned_empty'),
            textAlign: TextAlign.center, style: AppTextStyles.text(12, color: AppColors.textDim)),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) => SizedBox(width: 104, child: _itemTile(items[i])),
    );
  }

  /// 칸 [catId] 의 물건들 — **가진 것이 앞**, 그다음은 싼 것부터
  List<_BagItem> _itemsFor(LanguageManager lm, String catId) {
    final list = switch (catId) {
      'char' => _charItems(lm),
      'skin' => _cosmeticItems(lm, CosmeticKind.skin),
      'trail' => _cosmeticItems(lm, CosmeticKind.trail),
      'aura' => _cosmeticItems(lm, CosmeticKind.aura),
      _ => _gearItems(lm, catId),
    };
    list.sort((a, b) {
      if (a.owned != b.owned) return a.owned ? -1 : 1;
      return a.price.compareTo(b.price);
    });
    return list;
  }

  List<_BagItem> _charItems(LanguageManager lm) => [
        for (final c in CharacterData.availableCharacters)
          _BagItem(
            id: c.id,
            label: lm.translate('char_${c.id}'),
            price: c.price,
            owned: _ownsChar(c),
            equipped: c.id == _selectedCharId,
            previewing: _previewCharId == c.id && c.id != _selectedCharId,
            art: AvatarView.character(c.id, size: 52),
            accent: c.color,
            onPick: () async {
              _tryFx();
              setState(() => _tryCharId = c.id);
              // 가진 캐릭터는 고르는 즉시 내 아바타가 된다
              if (_ownsChar(c)) {
                await _useChar(c);
                if (mounted) setState(() => _tryCharId = null);
              }
            },
            buy: () => CoinStore.buy('char_${c.id}', c.price),
            equip: () async {
              await _useChar(c);
              if (mounted) setState(() => _tryCharId = null);
            },
          ),
      ];

  List<_BagItem> _gearItems(LanguageManager lm, String catId) {
    final slotName = catId.substring('gear_'.length);
    final slot = GearSlot.values.firstWhere((s) => s.name == slotName, orElse: () => GearSlot.head);
    final zone = _gearZone;
    final slotKey = Gear.slotKey(zone, slot);
    final base = CharacterData.getCharacter(_previewCharId).color;
    final accent = WorldData.getWorld(zone).accent;
    return [
      // 벗기 — 늘 맨 앞(가진 것으로 친다)
      _BagItem(
        id: Gear.none,
        label: lm.translate('gear_none'),
        price: -1, // 정렬에서 맨 앞
        owned: true,
        equipped: _wornId(zone, slot) == Gear.none,
        previewing: _previewId(zone, slot) == Gear.none && _wornId(zone, slot) != Gear.none,
        art: Icon(Icons.do_not_disturb_alt_rounded, size: 28, color: AppColors.textDim.withValues(alpha: 0.6)),
        accent: accent,
        onPick: () async {
          _equipFx();
          await CoinStore.equip(slotKey, Gear.none);
          _tryOn.remove(slotKey);
          if (mounted) setState(() {});
        },
        buy: null,
        // '없음' 의 착용 = 그 부위를 벗는다
        equip: () async {
          await CoinStore.equip(slotKey, Gear.none);
          _tryOn.remove(slotKey);
          if (mounted) setState(() {});
        },
      ),
      for (final g in Gear.itemsOf(zone, slot))
        () {
          final plateLocked = g.needsBadge != null && !_badges.contains(g.needsBadge);
          final owned = _ownsGear(g);
          return _BagItem(
            id: g.id,
            label: lm.translate(g.nameKey),
            price: g.price,
            owned: owned,
            badgeLocked: plateLocked,
            equipped: _wornId(zone, slot) == g.id,
            previewing: _previewId(zone, slot) == g.id && _wornId(zone, slot) != g.id,
            bonus: g.bonus.isZero ? null : g.bonus.labels.map((l) => lm.translate(l.$1).replaceAll('{n}', l.$2)).join(' · '),
            art: CustomPaint(painter: GearIconPainter(g.id, base)),
            accent: accent,
            onPick: () async {
              _tryFx();
              setState(() => _tryOn[slotKey] = g.id);
              if (owned) {
                _equipFx();
                await CoinStore.equip(slotKey, g.id);
                _tryOn.remove(slotKey);
                if (mounted) setState(() {});
              } else if (plateLocked) {
                _toast(lm
                    .translate('shop_need_badge_msg')
                    .replaceAll('{badge}', lm.translate(g.needsBadge!))
                    .replaceAll('{desc}', lm.translate('${g.needsBadge!}_desc')));
              }
            },
            buy: plateLocked ? null : () => CoinStore.buy(g.id, g.price),
            equip: () async {
              await CoinStore.equip(slotKey, g.id);
              _tryOn.remove(slotKey);
              if (mounted) setState(() {});
            },
          );
        }(),
    ];
  }

  List<_BagItem> _cosmeticItems(LanguageManager lm, CosmeticKind kind) {
    final kindKey = Cosmetics.kindKey(kind);
    final base = CharacterData.getCharacter(_previewCharId).color;
    final worn = CoinStore.equipped(kindKey, Cosmetics.defaultOf(kind));
    return [
      for (final c in Cosmetics.ofKind(kind))
        () {
          final owned = _ownsCosmetic(c);
          return _BagItem(
            id: c.id,
            label: lm.translate(c.nameKey),
            price: c.price,
            owned: owned,
            equipped: worn == c.id,
            previewing: (_tryOn[kindKey] ?? worn) == c.id && worn != c.id,
            art: kind == CosmeticKind.skin
                // 스킨 — 입은 모습 그대로(움직이며 반짝임·흐름이 보인다)
                ? AvatarStage(avatar: Avatar(characterId: _previewCharId, skinId: c.id), size: 48, cosmetics: false)
                : CosmeticPreview(
                    item: c,
                    base: base,
                    size: 48,
                    character: AvatarView.character(_previewCharId, size: 24, skin: _skinId),
                  ),
            accent: AppColors.coin,
            onPick: () async {
              _tryFx();
              setState(() => _tryOn[kindKey] = c.id);
              if (owned) {
                _equipFx();
                await CoinStore.equip(kindKey, c.id);
                _tryOn.remove(kindKey);
                if (mounted) setState(() {});
              }
            },
            buy: () => CoinStore.buy(c.id, c.price),
            equip: () async {
              await CoinStore.equip(kindKey, c.id);
              _tryOn.remove(kindKey);
              if (mounted) setState(() {});
            },
          );
        }(),
    ];
  }

  bool _ownsGear(GearItem g) {
    final plateLocked = g.needsBadge != null && !_badges.contains(g.needsBadge);
    return !plateLocked && (g.price == 0 || CoinStore.owns(g.id));
  }

  bool _ownsCosmetic(Cosmetic c) => c.price == 0 || CoinStore.owns(c.id);

  /// 미리 보던 물건을 산다 — 사면 그대로 장착된다
  Future<void> _buyAndEquip(LanguageManager lm, _BagItem item) async {
    final buy = item.buy;
    if (buy == null) return;
    final bought = await _confirmBuy(item.label, item.price, buy);
    if (!bought) return;
    _equipFx();
    await item.equip?.call();
    if (mounted) setState(() {});
  }

  /// 한 줄짜리 글 — [h] 높이를 지키면서, 넘치면 글자 크기를 줄여 전부 보여 준다
  Widget _fitLine(double h, String text, TextStyle style) => SizedBox(
        height: h,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, style: style),
        ),
      );

  // ── 카드 한 장 ──
  /// 장착 중이면 주황, 미리 보는 중이면 초록. 아직 없는 것은 흐리게 + 가격.
  Widget _itemTile(_BagItem item) {
    final ring = item.equipped ? _equippedColor : (item.previewing ? _previewColor : AppColors.line);
    final marked = item.equipped || item.previewing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onPick,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
          color: item.equipped ? _equippedColor.withValues(alpha: 0.10) : AppColors.surface,
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
                      padding: const EdgeInsets.all(8),
                      child: Opacity(opacity: item.owned ? 1 : 0.55, child: item.art),
                    ),
                  ),
                  if (item.badgeLocked)
                    Positioned(left: 4, top: 4, child: Icon(Icons.lock_rounded, size: 14, color: AppColors.gold))
                  else if (!item.owned)
                    Positioned(left: 4, top: 4, child: Icon(Icons.lock_rounded, size: 14, color: AppColors.textDim)),
                  if (item.equipped)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: _equippedColor, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                      ),
                    )
                  else if (item.previewing)
                    Positioned(right: 4, top: 4, child: Icon(Icons.visibility_rounded, size: 16, color: _previewColor)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 이름·능력치 — 길면 글자를 줄여서 한 줄에 다 보여 준다(자르지 않는다).
            // 높이는 고정이라 카드마다 그림 칸이 흔들리지 않는다. 능력치가 없으면 빈 줄로 자리만 잡는다
            _fitLine(16, item.label, AppTextStyles.text(11.5, weight: FontWeight.w800)),
            _fitLine(14, item.bonus ?? ' ', AppTextStyles.text(10, color: AppColors.up, weight: FontWeight.w800)),
            const SizedBox(height: 5),
            // 아래 줄 — 낀 것은 [착용 중], 없는 것은 가격(가진 것은 카드를 누르면 바로 낀다)
            _itemAction(item),
          ],
        ),
      ),
    );
  }

  /// 카드 아래 줄 — 높이를 22 로 고정해서 어떤 상태든 카드 크기가 같다
  Widget _itemAction(_BagItem item) {
    final lm = LanguageManager.of(context, listen: false);
    if (!item.owned) {
      return SizedBox(
        height: 22,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CoinIcon(size: 13),
            const SizedBox(width: 4),
            Text(formatCount(item.price),
                style: AppTextStyles.display(12,
                    color: CoinStore.balance.value >= item.price ? AppColors.coin : AppColors.textDim)),
          ],
        ),
      );
    }
    if (item.equipped) {
      return SizedBox(
        height: 22,
        child: Center(
          child: Text(lm.translate('shop_equipped'),
              maxLines: 1, style: AppTextStyles.text(10.5, color: _equippedColor, weight: FontWeight.w800)),
        ),
      );
    }
    // 가졌지만 안 낀 것 — 카드를 누르면 바로 착용되므로 따로 버튼을 두지 않는다
    return const SizedBox(height: 22);
  }

  // ── 미리보기 ──
  /// 지금 존의 바닥 위에 선 내 아바타 — 장착한 것 + 미리 고른 것이 그대로 보인다
  Widget _previewBox(LanguageManager lm, double height) {
    final zone = _gearZone;
    final world = WorldData.getWorld(zone);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: height,
        color: world.floor,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/worlds/${zone}_bg.png',
                  fit: BoxFit.cover, alignment: Alignment.bottomCenter, errorBuilder: (_, _, _) => const SizedBox()),
            ),
            Positioned.fill(child: ColoredBox(color: world.floor.withValues(alpha: 0.35))),
            // 캐릭터 — 항상 가운데. 잔상·오라도 지금 고른 것으로 함께 보인다
            Center(child: AvatarStage(avatar: _previewAvatar, zone: zone, size: height * 0.69)),
            // 지금 캐릭터 이름
            Positioned(
              left: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(999)),
                child: Text(lm.translate('char_$_previewCharId'),
                    style: AppTextStyles.text(11, color: Colors.white, weight: FontWeight.w800)),
              ),
            ),
            // 부위 램프 — 입었으면 켜지고, 비었으면 꺼진다
            Positioned(
              right: 8,
              bottom: 8,
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
                        base: _previewAvatar.color,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 미리보기에 함께 그릴 꾸미기 — 잔상·오라(고른 게 있으면 그것, 아니면 착용 중인 것)
  /// 지금 미리 보고 있는 아바타 한 벌 — 착용 중인 것 위에 '입어 보는 중'을 얹는다(avatar.dart)
  Avatar get _previewAvatar => Avatar(
        characterId: _previewCharId,
        skinId: _skinId,
        trailId: _previewCos(CosmeticKind.trail),
        auraId: _previewCos(CosmeticKind.aura),
        gearByZone: {_gearZone: _previewGear(_gearZone)},
      );

  String _previewCos(CosmeticKind kind) =>
      _tryOn[Cosmetics.kindKey(kind)] ?? CoinStore.equipped(Cosmetics.kindKey(kind), Cosmetics.defaultOf(kind));

  /// 지금 입은(또는 미리 입어 보는) 몸통 스킨
  String get _skinId =>
      _tryOn[Cosmetics.kindKey(CosmeticKind.skin)] ?? CoinStore.equipped(Cosmetics.kindKey(CosmeticKind.skin), Cosmetics.defaultSkin);

  /// 장비를 보는 존
  String _gearZone = 'cyber';

  /// 미리 골라 둔 것 — 슬롯 키(또는 꾸미기 종류 키) → 아이템 id(Gear.none = 벗기)
  final Map<String, String> _tryOn = {};

  String _wornId(String zone, GearSlot slot) => Gear.wornId(zone, slot, CoinStore.equipped);

  /// 미리보기에 보이는 것 — 고른 게 있으면 그것, 아니면 장착 중인 것
  String _previewId(String zone, GearSlot slot) => _tryOn[Gear.slotKey(zone, slot)] ?? _wornId(zone, slot);

  List<String> _previewGear(String zone) => [
        for (final slot in Gear.slotsOf(zone))
          if (_previewId(zone, slot) != Gear.none) _previewId(zone, slot),
      ];

}

/// 가방의 칸 — 미리보기 좌우에 놓이는 아이콘 버튼 하나
class _BagCat {
  final String id;
  final IconData icon;
  final String label;
  const _BagCat(this.id, this.icon, this.label);
}

/// 목록에 놓이는 물건 한 개 — 캐릭터·장비·꾸미기·변경권을 같은 모양으로 다룬다
class _BagItem {
  final String id;
  final String label;
  final int price;
  final bool owned;
  final bool badgeLocked;
  final bool equipped;
  final bool previewing;
  final String? bonus;

  final Widget art;
  final Color accent;

  /// 카드를 눌렀을 때 — 가진 것은 장착, 아직 없는 것은 미리보기
  final VoidCallback onPick;

  /// 구매(있으면 목록 머리에 구매 버튼이 뜬다)
  final Future<bool> Function()? buy;

  /// 구매 뒤 장착
  final Future<void> Function()? equip;

  const _BagItem({
    required this.id,
    required this.label,
    required this.price,
    required this.owned,
    required this.art,
    required this.accent,
    required this.onPick,
    this.badgeLocked = false,
    this.equipped = false,
    this.previewing = false,
    this.bonus,
    this.buy,
    this.equip,
  });
}

/// 부위 아이콘 — 카테고리 버튼과 부위 램프가 같은 그림을 쓴다
IconData slotIcon(GearSlot s) => switch (s) {
      GearSlot.head => Icons.sports_motorsports_rounded,
      GearSlot.hands => Icons.back_hand_rounded,
      GearSlot.feet => Icons.directions_walk_rounded,
      GearSlot.back => Icons.flight_rounded,
    };


/// 장비 미리보기의 부위 램프 — 입었으면 아이템 그림으로 켜지고, 비었으면 부위 아이콘만 흐리게.
/// 입어 보는 중(아직 착용 안 함)이면 오른쪽 위에 작은 점.
class _SlotLamp extends StatelessWidget {
  final GearSlot slot;
  final String itemId;
  final bool trying;
  final Color accent;
  final Color base;
  const _SlotLamp({required this.slot, required this.itemId, required this.trying, required this.accent, required this.base});

  /// 부위 하나의 상태를 한눈에 — **입었으면 꽉 찬 점 + 부위 아이콘**, 비었으면 옅은 테두리만.
  /// 미리 고른 중이면 초록(장착 = 주황과 같은 규칙).
  @override
  Widget build(BuildContext context) {
    final on = itemId != Gear.none;
    final color = trying ? AppColors.up : (on ? AppColors.coin : Colors.white.withValues(alpha: 0.35));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: on ? color : Colors.white.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Icon(
        slotIcon(slot),
        size: 11,
        color: on ? Colors.white : Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}
