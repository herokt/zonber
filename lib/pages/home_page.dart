import 'package:flutter/material.dart';

import '../avatar.dart';
import '../character_data.dart';
import '../coin_store.dart';
import '../design_system.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../ranking_system.dart';
import '../services/auth_service.dart';
import '../user_profile.dart';
import '../world_config.dart';
import '../daily_rewards.dart';
import 'daily_sheet.dart';
import 'promo_page.dart';

/// 홈 — 월드 캐러셀 + 캐릭터 + START. (docs/UI_DESIGN.md §4.1)
class HomePage extends StatefulWidget {
  final String selectedWorldId;
  final Map<String, double> bestTimes;
  final Map<String, RankCacheEntry> rankCache;
  final ValueChanged<String> onWorldSelected;
  final VoidCallback onStart;
  final VoidCallback onCharacterSelect;
  final VoidCallback onLogin;
  final VoidCallback onSettings;
  final VoidCallback onRanking;
  final VoidCallback onShop;
  final VoidCallback onPromo;

  const HomePage({
    super.key,
    required this.selectedWorldId,
    required this.bestTimes,
    required this.rankCache,
    required this.onWorldSelected,
    required this.onStart,
    required this.onCharacterSelect,
    required this.onLogin,
    required this.onSettings,
    required this.onRanking,
    required this.onShop,
    required this.onPromo,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 그 존의 1위 기록 — 세계와 내 국가
typedef _TopTimes = ({double? world, double? nation});

class _HomePageState extends State<HomePage> {
  late final PageController _pager;
  Map<String, String> _profile = {};
  /// 내 아바타 — 고른 캐릭터 + 지금 착용 중인 스킨·장비(avatar.dart)
  Avatar _avatar = Avatar.fallback;
  late int _index;

  /// 존별 1위 기록 캐시(이 화면이 떠 있는 동안) — 내 기록과 견줘 보라고 카드에 같이 적는다
  final Map<String, _TopTimes> _tops = {};

  @override
  void initState() {
    super.initState();
    DailyRewards.refresh(); // 받을 보상 빨간 점
    _index = WorldData.worlds.indexWhere((w) => w.id == widget.selectedWorldId);
    if (_index < 0) _index = 0;
    _pager = PageController(initialPage: _index, viewportFraction: 0.9);
    _loadProfile();
    _loadTops(WorldData.worlds[_index].id);
  }

  /// 그 존의 세계 1위·내 국가 1위 — 한 번 읽고 캐시한다(없으면 '—')
  Future<void> _loadTops(String worldId) async {
    if (_tops.containsKey(worldId)) return;
    _tops[worldId] = (world: null, nation: null); // 중복 요청 방지
    final world = WorldData.getWorld(worldId);
    final ranking = RankingSystem();
    final flag = _profile['flag'] ?? '';
    final top = await ranking.getTopTimes(world.rankingMapId, limit: 1);
    final nat = flag.isEmpty
        ? const <Map<String, dynamic>>[]
        : await ranking.getNationalRankings(world.rankingMapId, flag, limit: 1);
    if (!mounted) return;
    setState(() {
      _tops[worldId] = (
        world: top.isEmpty ? null : top.first,
        nation: nat.isEmpty ? null : ((nat.first['survivalTime'] as num?) ?? 0).toDouble(),
      );
    });
  }

  Future<void> _loadProfile() async {
    final p = await UserProfileManager.getProfile();
    final avatar = await Avatar.mine(p['characterId'] ?? Avatar.defaultCharacterId);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _avatar = avatar;
    });
    // 국기를 알고 난 뒤라야 '내 국가 1위'를 읽을 수 있다
    _tops.clear();
    _loadTops(WorldData.worlds[_index].id);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool get _isGuest => AuthService.isGuest;

  /// 지금 보고 있는 존 — 아바타가 이 존 장비를 입고 나온다
  String get _zoneId => WorldData.worlds[_index].id;

  /// 탭·점·옆 카드로 존 이동 — onPageChanged 가 선택을 반영한다
  void _goTo(int i) {
    if (i == _index) return;
    _pager.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final world = WorldData.worlds[_index];
    final unlocked = WorldData.isUnlocked(world, widget.bestTimes);
    final accent = world.accent;
    final char = CharacterData.getCharacter(_profile['characterId'] ?? 'neon_green');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        // 세로가 짧은 화면(폴드 펼침·작은 폰)에서도 게임 시작 버튼까지 스크롤로 닿게
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 머리와 존 고르기는 늘 제자리 — 아래(존 카드·내 정보)만 스크롤한다
            _topBar(lm, char),
            _stageTabs(),
            const SizedBox(height: 10),
            Expanded(
              child: FillScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 300, child: _carousel()),
                    const SizedBox(height: 12),
                    _dots(accent),
                    _infoTiles(lm, char, accent),
                    // 이벤트 — 진행 중일 때만 한 줄 뜬다(promotions.dart). 누르면 이벤트 페이지
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: PromoBanner(onTap: widget.onPromo),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _startButton(lm, accent, unlocked),
          ],
        ),
      ),
    );
  }

  // ── 상단 바 ──
  Widget _topBar(LanguageManager lm, Character char) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSettings,
              child: Row(
                children: [
                  if (_isGuest)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.textDim, width: 1.5),
                      ),
                      child: Icon(Icons.person_outline_rounded, color: AppColors.textDim, size: 20),
                    )
                  else
                    AvatarView(avatar: _avatar, zone: _zoneId, size: 36),
                  const SizedBox(width: 10),
                  Text(
                    _isGuest ? lm.translate('guest') : (_profile['nickname'] ?? ''),
                    style: AppTextStyles.text(16, weight: FontWeight.w800),
                  ),
                  if (!_isGuest && (_profile['flag'] ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    CountryChip(flag: _profile['flag']!),
                  ],
                ],
              ),
            ),
            const Spacer(),
            // 오늘의 미션 — 받을 보상이 있으면 점으로 알린다
            _missionButton(lm),
            const SizedBox(width: 6),
            // 코인 — 맨 오른쪽. 누르면 가방
            ValueListenableBuilder<int>(
              valueListenable: CoinStore.balance,
              builder: (context, b, _) => CoinChip(amount: b, onTap: widget.onShop, size: 13),
            ),
          ],
        ),
      );

  /// 오늘의 미션 — 눌러서 바로 연다. 받을 게 있으면 오른쪽 위에 점
  Widget _missionButton(LanguageManager lm) => ValueListenableBuilder<int>(
        valueListenable: DailyRewards.claimable,
        builder: (context, n, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            AppIconButton(
              icon: Icons.checklist_rounded,
              onTap: () async {
                await showDailySheet(context);
                if (mounted) setState(() {});
              },
              label: lm.translate('daily_title'),
              background: Colors.transparent,
              color: n > 0 ? AppColors.coin : AppColors.textDim,
            ),
            if (n > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      );

  // ── 존 탭 — 스와이프 외에 탭으로도 고른다 ──
  Widget _stageTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        child: StageFilter(
          selectedId: WorldData.worlds[_index].id,
          onChanged: (id) => _goTo(WorldData.worlds.indexWhere((w) => w.id == id)),
        ),
      );

  // ── 존 캐러셀 (스와이프 · 옆 카드 탭) ──
  Widget _carousel() => PageView.builder(
        controller: _pager,
        itemCount: WorldData.worlds.length,
        onPageChanged: (i) {
          setState(() => _index = i);
          widget.onWorldSelected(WorldData.worlds[i].id);
          _loadTops(WorldData.worlds[i].id);
        },
        itemBuilder: (context, i) {
          final w = WorldData.worlds[i];
          return GestureDetector(
            // 옆에 보이는 카드를 누르면 그 존으로 넘어간다
            onTap: i == _index ? null : () => _goTo(i),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: i == _index ? 0 : 10),
              child: _WorldCard(
                world: w,
                unlocked: WorldData.isUnlocked(w, widget.bestTimes),
                best: widget.bestTimes[w.id],
                rank: widget.rankCache[w.id],
                top: _tops[w.id],
                myFlag: _profile['flag'] ?? '',
              ),
            ),
          );
        },
      );

  Widget _dots(Color accent) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < WorldData.worlds.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _goTo(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? accent : AppColors.surface2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
        ],
      );

  // ── 내 정보 — 캐릭터 · 오늘의 미션 두 장 ──
  Widget _infoTiles(LanguageManager lm, Character char, Color accent) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: SizedBox(
          height: 92,
          child: Row(
            children: [
              Expanded(child: _characterTile(lm, char)),
              const SizedBox(width: 10),
              const Expanded(child: DailyCard()),
            ],
          ),
        ),
      );

  /// 지금 쓰는 캐릭터 — 누르면 가방으로. 캐릭터 색을 옅게 깔아 카드마다 표정이 살게 한다
  Widget _characterTile(LanguageManager lm, Character char) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onCharacterSelect,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [char.color.withValues(alpha: 0.22), char.color.withValues(alpha: 0.06)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: char.color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              AvatarView(avatar: _avatar, zone: _zoneId, size: 48, borderColor: char.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OneLineText(lm.translate('char_${char.id}'), style: AppTextStyles.text(15, weight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(lm.translate('change'),
                            style: AppTextStyles.text(12, color: char.color, weight: FontWeight.w800)),
                        Icon(Icons.chevron_right_rounded, color: char.color, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  // ── START (고정) ──
  Widget _startButton(LanguageManager lm, Color accent, bool unlocked) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
        // 게임 시작 — 가로를 꽉 채운다
        child: SizedBox(
          width: double.infinity,
          child: NeonButton(
            text: unlocked ? lm.translate('start_game') : lm.translate('locked'),
            icon: unlocked ? Icons.play_arrow_rounded : Icons.lock_rounded,
            color: accent,
            onPressed: unlocked ? widget.onStart : null,
            fontSize: 18,
          ),
        ),
      );
}

class _WorldCard extends StatelessWidget {
  final WorldConfig world;
  final bool unlocked;
  final double? best;
  final RankCacheEntry? rank;
  /// 그 존의 1위 기록(세계·내 국가) — 내 기록과 견줘 본다
  final _TopTimes? top;
  final String myFlag;
  const _WorldCard(
      {required this.world, required this.unlocked, this.best, this.rank, this.top, this.myFlag = ''});

  /// 신기록 한 줄 — 라벨 + 시간. 시간은 늘 소수점 셋째 자리까지라 **칸 너비를 고정**해
  /// 두 줄의 숫자가 맞게 떨어진다(기록이 없어 '—' 여도 자리를 지킨다)
  Widget _topLine(String label, double? time) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.text(10, color: AppColors.textDim, weight: FontWeight.w700)),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: Text(
              time == null ? '—' : '${formatSurvival(time)}s',
              textAlign: TextAlign.right,
              style: AppTextStyles.display(12, color: AppColors.textDim),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final name = lm.translate(world.nameKey);
    final dim = !unlocked;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 히어로 아트 슬롯 — assets/images/worlds/{id}_hero.png (더미/실아트). 없으면 코드 드로잉.
                Image.asset(
                  'assets/images/worlds/${world.id}_hero.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => CustomPaint(painter: _WorldArtPainter(world)),
                ),
                if (dim)
                  Container(
                    color: AppColors.background.withValues(alpha: 0.62),
                    child: Icon(Icons.lock_rounded, color: AppColors.text, size: 30),
                  ),
                Positioned(
                  left: 14,
                  top: 12,
                  child: AppChip(label: 'ZONE ${world.difficulty}'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(name.toUpperCase(), style: AppTextStyles.display(21).copyWith(letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lm.translate(world.taglineKey),
                    style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w500, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // 왼쪽 내 기록 · 오른쪽 1위 기록(내 국가 · 세계) — 한눈에 견준다
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(lm.translate('my_best'),
                                    style: AppTextStyles.text(10, color: AppColors.textDim)),
                                if (rank != null) ...[
                                  const SizedBox(width: 6),
                                  Text('#${formatCount(rank!.rank)}',
                                      style: AppTextStyles.text(10, color: world.accent, weight: FontWeight.w800)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(best == null ? '—' : formatSurvival(best!), style: AppTextStyles.display(19)),
                                if (best != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2, bottom: 1),
                                    child: Text('s',
                                        style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 1위 기록 두 줄 — 오른쪽에 붙여 작게
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _topLine(lm.translate('record_country'), top?.nation),
                          const SizedBox(height: 3),
                          _topLine(lm.translate('record_world'), top?.world),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 월드 무대 일러스트(에셋 도입 전 코드 드로잉) — 바닥·라인·투사체 몇 개
class _WorldArtPainter extends CustomPainter {
  final WorldConfig world;
  _WorldArtPainter(this.world);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = world.floor);
    final line = Paint()
      ..color = world.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final inset = Rect.fromLTWH(18, 14, size.width - 36, size.height - 28);
    canvas.drawRect(inset, line);
    canvas.drawLine(Offset(size.width / 2, inset.top), Offset(size.width / 2, inset.bottom), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 26, line);

    final p = world.projectiles.first;
    final ball = Paint()..color = p.color;
    final core = Paint()..color = p.coreColor.withValues(alpha: 0.55);
    final r1 = (p.visualSize * 1.6).clamp(10.0, 24.0);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.4), r1, ball);
    canvas.drawCircle(Offset(size.width * 0.72 - r1 * 0.35, size.height * 0.4 - r1 * 0.35), r1 * 0.3, core);
    final r2 = r1 * 0.72;
    canvas.drawCircle(Offset(size.width * 0.27, size.height * 0.67), r2, ball);
    canvas.drawCircle(Offset(size.width * 0.27 - r2 * 0.35, size.height * 0.67 - r2 * 0.35), r2 * 0.3, core);

    // 플레이어(기본 캐릭터 색)
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.55), 12, Paint()..color = const Color(0xFF45A29E));
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.55), 4, Paint()..color = AppColors.background);
  }

  @override
  bool shouldRepaint(covariant _WorldArtPainter old) => old.world.id != world.id;
}
