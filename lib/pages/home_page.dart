import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../character_data.dart';
import '../coin_store.dart';
import '../design_system.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../user_profile.dart';
import '../world_config.dart';

/// 홈 — 월드 캐러셀 + 캐릭터 + START. (docs/UI_DESIGN.md §4.1)
class HomePage extends StatefulWidget {
  final String selectedWorldId;
  final Map<String, double> bestTimes;
  final Map<String, RankCacheEntry> rankCache;
  final ValueChanged<String> onWorldSelected;
  final VoidCallback onStart;
  final VoidCallback onCharacterSelect;
  final VoidCallback onLogin;
  final VoidCallback onGuide;
  final VoidCallback onSettings;
  final VoidCallback onRanking;
  final VoidCallback onShop;

  const HomePage({
    super.key,
    required this.selectedWorldId,
    required this.bestTimes,
    required this.rankCache,
    required this.onWorldSelected,
    required this.onStart,
    required this.onCharacterSelect,
    required this.onLogin,
    required this.onGuide,
    required this.onSettings,
    required this.onRanking,
    required this.onShop,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PageController _pager;
  Map<String, String> _profile = {};
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = WorldData.worlds.indexWhere((w) => w.id == widget.selectedWorldId);
    if (_index < 0) _index = 0;
    _pager = PageController(initialPage: _index, viewportFraction: 0.9);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await UserProfileManager.getProfile();
    if (mounted) setState(() => _profile = p);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool get _isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

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
            // 위쪽(존 카드·캐릭터)만 스크롤 — 게임 시작 버튼은 아래에 항상 고정
            Expanded(
              child: FillScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            // ── 상단 바 ──
            Padding(
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
                          CharacterAvatar(characterId: char.id, size: 36),
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
                  // 코인 — 누르면 상점
                  ValueListenableBuilder<int>(
                    valueListenable: CoinStore.balance,
                    builder: (context, b, _) => CoinChip(amount: b, onTap: widget.onShop, size: 13),
                  ),
                  const SizedBox(width: 4),
                  AppIconButton(
                    icon: Icons.help_outline_rounded,
                    onTap: widget.onGuide,
                    label: lm.translate('guide_rules_title'),
                    background: Colors.transparent,
                    color: AppColors.textDim,
                  ),
                  AppIconButton(
                    icon: Icons.settings_rounded,
                    onTap: widget.onSettings,
                    label: lm.translate('settings'),
                    background: Colors.transparent,
                    color: AppColors.textDim,
                  ),
                ],
              ),
            ),

            // ── 게스트 배너 ──
            if (_isGuest)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onLogin,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textDim),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OneLineText(
                            lm.translate('guest_banner'),
                            style: AppTextStyles.text(12, color: AppColors.textDim),
                          ),
                        ),
                        Text(lm.translate('login'), style: AppTextStyles.text(12, weight: FontWeight.w800)),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textDim),
                      ],
                    ),
                  ),
                ),
              ),

            // ── 섹션 라벨 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: SectionLabel(
                lm.translate('todays_stage'),
                trailing: '${_index + 1} / ${WorldData.worlds.length}',
              ),
            ),

            // ── 존 탭 — 스와이프 외에 탭으로도 고른다 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: _ZoneTabs(index: _index, onTap: _goTo),
            ),

            // ── 존 캐러셀 (스와이프 · 옆 카드 탭) ──
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _pager,
                itemCount: WorldData.worlds.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  widget.onWorldSelected(WorldData.worlds[i].id);
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
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
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
            ),

            // ── 캐릭터 행 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onCharacterSelect,
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      CharacterAvatar(characterId: char.id, size: 40, borderColor: char.color),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lm.translate('char_${char.id}'), style: AppTextStyles.text(14, weight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(lm.translate('char_same_stats_short'), style: AppTextStyles.text(11, color: AppColors.textDim)),
                        ],
                      ),
                      const Spacer(),
                      Text(lm.translate('change'), style: AppTextStyles.text(13, color: AppColors.textDim, weight: FontWeight.w700)),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20),
                    ],
                  ),
                ),
              ),
            ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── START (고정) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
              child: Column(
                children: [
                  NeonButton(
                    text: unlocked ? lm.translate('start_game') : lm.translate('locked'),
                    icon: unlocked ? Icons.play_arrow_rounded : Icons.lock_rounded,
                    color: accent,
                    onPressed: unlocked ? widget.onStart : null,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  OneLineText(
                    _startHint(lm, world, unlocked),
                    style: AppTextStyles.text(12, color: AppColors.textDim),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _startHint(LanguageManager lm, WorldConfig world, bool unlocked) {
    final name = lm.translate(world.nameKey);
    final cache = widget.rankCache[world.id];
    if (cache != null) {
      return '$name · ${lm.translate('records_count').replaceAll('{n}', formatCount(cache.total))}';
    }
    return '$name · ${lm.translate(world.taglineKey).split('\n').first}';
  }
}

class _WorldCard extends StatelessWidget {
  final WorldConfig world;
  final bool unlocked;
  final double? best;
  final RankCacheEntry? rank;
  const _WorldCard({required this.world, required this.unlocked, this.best, this.rank});

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
                  errorBuilder: (_, __, ___) => CustomPaint(painter: _WorldArtPainter(world)),
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
                      const Spacer(),
                      if (rank != null)
                        Text(
                          lm.translate('records_count').replaceAll('{n}', formatCount(rank!.total)),
                          style: AppTextStyles.text(11, color: AppColors.textDim),
                        ),
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
                  Row(
                    children: [
                      Text(lm.translate('my_best'), style: AppTextStyles.text(11, color: AppColors.textDim)),
                      const SizedBox(width: 8),
                      Text(
                        best == null ? '—' : formatSurvival(best!),
                        style: AppTextStyles.display(17),
                      ),
                      if (best != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 1),
                          child: Text('s', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
                        ),
                      const Spacer(),
                      if (rank != null)
                        AppChip(label: '${lm.translate('rank_world')} #${formatCount(rank!.rank)}'),
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

/// 존 탭 — 번호 + 이름. 선택된 존은 존 색으로 채운다.
class _ZoneTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _ZoneTabs({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (int i = 0; i < WorldData.worlds.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${WorldData.worlds[i].difficulty}',
                          style: AppTextStyles.display(12,
                              color: i == index ? WorldData.worlds[i].accent : AppColors.textDim)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          lm.translate(WorldData.worlds[i].nameKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.text(13,
                              color: i == index ? AppColors.text : AppColors.textDim,
                              weight: i == index ? FontWeight.w800 : FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
