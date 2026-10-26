part of '../main.dart';

// 게임 화면 — HUD(타이머·에너지·목표선) · 시작 연출 · 추가 기록 칩 (main.dart 에서 나눔 · 2026-09-22)

// ─────────────────────────────────────────────────────────────
// 게임 화면 — HUD(타이머·에너지·목표선) + 무대 + 근접 회피 카운터
// (docs/UI_DESIGN.md §4.3)
// ─────────────────────────────────────────────────────────────
class _GameScreen extends StatelessWidget {
  final ZonberGame game;
  final WorldConfig world;
  final VoidCallback onPause;
  const _GameScreen({required this.game, required this.world, required this.onPause});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final accent = world.accent;
    // HUD 는 존 바닥색 위에 얹는다 — 앱 테마(라이트/다크)와 무관하게 무대와 한 덩어리로 보이게.
    final floor = world.floor;
    final darkFloor = floor.computeLuminance() < 0.4;
    final ink = darkFloor ? const Color(0xFFF2F4F8) : const Color(0xFF0F172A);
    final inkDim = ink.withValues(alpha: 0.6);
    final chip = ink.withValues(alpha: darkFloor ? 0.10 : 0.08);
    final up = darkFloor ? const Color(0xFF3DD68C) : const Color(0xFF15803D);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkFloor ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: floor,
        body: SafeArea(
          child: Column(
            children: [
              // ── 상단 HUD: 일시정지 · 생존 시간(+최고 기록) · 에너지 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconButton(
                      icon: Icons.pause_rounded,
                      onTap: onPause,
                      label: lm.translate('paused'),
                      color: ink,
                      background: chip,
                    ),
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: game.survivalTimeNotifier,
                        builder: (context, value, _) {
                          final pb = game.personalBest;
                          final beaten = pb > 0 && value > pb;
                          final rival = game.rival;
                          final rivalBeaten = rival != null && value > rival.time;
                          return Column(
                            children: [
                              // 소수점 셋째 자리까지 매 프레임 바뀌므로 숫자 폭을 고정해 흔들리지 않게
                              Text(formatClock(value),
                                  style: AppTextStyles.display(40, color: beaten || rivalBeaten ? up : ink)
                                      .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                              const SizedBox(height: 4),
                              Text(
                                beaten
                                    ? lm.translate('hud_new_best')
                                    : rivalBeaten
                                        ? lm.translate('hud_rival_beaten').replaceAll('{name}', rival.name)
                                        : pb > 0
                                            ? '${lm.translate('hud_best')} ${formatClock(pb)}'
                                            : lm.translate(world.nameKey).toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label(color: beaten || rivalBeaten ? up : inkDim),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _EnergyPips(notifier: game.energyNotifier, accent: accent, empty: chip),
                    ),
                  ],
                ),
              ),
              // ── 다음 목표선 (TOP 100 → 30 → 10 → 1) ──
              // 자리는 늘 같은 높이(34) — 목표선이 늦게 뜨거나(서버 응답) 1위를 넘어 사라질 때
              // 무대 높이가 바뀌면 맵이 다시 맞춰지며 꿈틀거렸다
              SizedBox(
                height: 34,
                child: ValueListenableBuilder<({String label, double time})?>(
                valueListenable: game.targetNotifier,
                builder: (context, target, _) {
                  if (target == null) return const SizedBox.shrink();
                  // 상대 목표(이 기록 깨러 가기)는 게스트도 잠금 없이 보인다 — 잠금은 TOP N 랭킹 목표만
                  final isRival = game.rival != null && target.time == game.rival!.time;
                  final guest = AuthService.isGuest && !isRival;
                  return ValueListenableBuilder<double>(
                    valueListenable: game.survivalTimeNotifier,
                    builder: (context, t, _) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
                      child: Row(
                        children: [
                          if (guest) ...[
                            Icon(Icons.lock_rounded, size: 12, color: inkDim),
                            const SizedBox(width: 4),
                          ],
                          Text(target.label, style: AppTextStyles.label(color: guest ? inkDim : ink)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                value: target.time <= 0 ? 1 : (t / target.time).clamp(0.0, 1.0),
                                backgroundColor: chip,
                                valueColor: AlwaysStoppedAnimation(guest ? inkDim : accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(formatClock(target.time), style: AppTextStyles.display(12, color: inkDim)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ),
              // ── 경기장 — 세 존 모두 같은 480×768 무대를 이 영역에 가장 크게, 가운데 맞춤으로 그린다(ZonberGame._fitView) ──
              Expanded(
                child: Stack(
                  children: [
                    // 처음 그림·소리를 불러오는 동안도 스피너
                    Positioned.fill(
                      child: GameWidget(
                        game: game,
                        loadingBuilder: (_) => ColoredBox(color: AppColors.background, child: const AppLoading()),
                      ),
                    ),
                    // 위기 — 에너지 1칸이면 가장자리가 붉게 두근거린다
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: game.dangerNotifier,
                          builder: (context, on, _) => on ? const _DangerVignette() : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    // 붉은 번쩍임 — 맞거나 골을 먹으면 가장자리부터
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<int>(
                          valueListenable: game.flashNotifier,
                          builder: (context, v, _) => v == 0
                              ? const SizedBox.shrink()
                              : TweenAnimationBuilder<double>(
                                  key: ValueKey(v),
                                  tween: Tween(begin: 1, end: 0),
                                  duration: const Duration(milliseconds: 420),
                                  builder: (context, a, _) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        radius: 0.9,
                                        colors: [Colors.transparent, const Color(0xFFE5484D).withValues(alpha: 0.55 * a)],
                                        stops: const [0.55, 1],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // 시작 연출 문구 — 나의 ZONE → START!
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: game.introNotifier,
                          builder: (context, phase, _) {
                            if (phase == null) return const SizedBox.shrink();
                            final isStart = phase == 'start';
                            return Center(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(phase),
                                tween: Tween(begin: 0.7, end: 1),
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutBack,
                                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isStart ? accent : Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: isStart
                                      ? Text(lm.translate('intro_start'),
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.display(44, color: Colors.white))
                                      // 스테이지별 미션 — 존버 정체성: [존]에서 [버]텨라 · [존]에서 [생]존하라 · [존]에서 [막]아라
                                      : EmphasisText(
                                          lm.translate('intro_mission_${game.worldConfig.id}'),
                                          style: AppTextStyles.display(28, color: Colors.white),
                                          dotColor: const Color(0xFFFFD23F),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // 첫 판 안내 — 손가락을 끌면 사라진다(ZonberGame.tutorial)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 28,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: game.tutorialNotifier,
                          builder: (context, on, _) => !on
                              ? const SizedBox.shrink()
                              : Center(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 320),
                                    builder: (context, a, child) => Opacity(opacity: a, child: child),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.touch_app_rounded, color: accent, size: 22),
                                          const SizedBox(width: 10),
                                          Text(lm.translate('tutorial_drag'),
                                              style: AppTextStyles.text(15, color: Colors.white, weight: FontWeight.w800)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // 게임 오버 — 기절 연출 동안 GAME OVER, 그 뒤 결과 화면을 준비하는 동안 스피너
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: game.gameOverNotifier,
                          builder: (context, over, _) =>
                              over ? _GameOverOverlay(title: lm.translate('game_over'), accent: accent) : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    // 추가 기록 칩 — 경기장 위쪽 가장자리(아래쪽은 골키퍼 골문·피구 내 뒤 외야가 있다)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 12,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<int>(
                          valueListenable: game.grazeNotifier,
                          builder: (context, g, _) => g == 0
                              ? const SizedBox.shrink()
                              : Center(
                                  child: Container(
                                    height: 28,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: floor.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: chip),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(lm.translate(world.statKey),
                                            style: AppTextStyles.label(color: ink)),
                                        const SizedBox(width: 6),
                                        Text('×$g', style: AppTextStyles.display(14, color: accent)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 게임 오버 덮개 — 화면이 어두워지며 GAME OVER 가 통 튀어나오고, 기절 연출(ZonberGame.koDuration)이 끝나면
/// 결과 화면을 준비하는 동안 아래에 스피너가 돈다(멈춘 화면으로 기다리지 않게)
class _GameOverOverlay extends StatefulWidget {
  final String title;
  final Color accent;
  const _GameOverOverlay({required this.title, required this.accent});

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: (ZonberGame.koDuration * 1000).round()))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0 → 1 (기절 연출 길이)
          final dim = Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));
          final pop = Curves.easeOutBack.transform(((t - 0.12) / 0.3).clamp(0.0, 1.0));
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [Colors.black.withValues(alpha: 0.18 * dim), Colors.black.withValues(alpha: 0.5 * dim)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: pop.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * pop,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: widget.accent.withValues(alpha: 0.7), width: 2),
                        ),
                        child: Text(widget.title, style: AppTextStyles.display(36, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 연출이 끝나면 — 결과 화면이 뜰 때까지
                  SizedBox(
                    height: 26,
                    child: t >= 1 ? AppSpinner(size: 26, color: Colors.white.withValues(alpha: 0.9)) : null,
                  ),
                ],
              ),
            ),
          );
        },
      );
}

/// 에너지 핍 — 캐릭터 최대치만큼, 채워진 칸은 존 색. 충전 중인 칸은 반투명.
class _EnergyPips extends StatelessWidget {
  final ValueNotifier<({int current, int max, double chargeProgress, Color color})> notifier;
  final Color accent;
  final Color empty;
  const _EnergyPips({required this.notifier, required this.accent, required this.empty});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, e, _) {
        if (e.max == 0) return const SizedBox();
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (int i = 0; i < e.max; i++)
              Container(
                margin: const EdgeInsets.only(left: 3),
                width: e.max > 4 ? 5 : e.max > 3 ? 7 : 10, // 자리 44 안에 — 골키퍼 목숨 5칸이 넘쳤다
                height: 24,
                decoration: BoxDecoration(
                  color: i < e.current
                      ? accent
                      : i == e.current
                          ? accent.withValues(alpha: 0.15 + 0.5 * e.chargeProgress)
                          : empty,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 위기 테두리 — 0.8초 주기(심장박동 소리와 같은 박자)로 붉게 두근
class _DangerVignette extends StatefulWidget {
  const _DangerVignette();

  @override
  State<_DangerVignette> createState() => _DangerVignetteState();
}

class _DangerVignetteState extends State<_DangerVignette> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();

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
        // 쿵(0) · 쿵(0.22) 두 번 — 빠르게 올라갔다 천천히 빠진다
        double beat(double at) {
          final d = (_c.value - at) % 1.0;
          return d < 0.25 ? (1 - d / 0.25) : 0;
        }
        final a = 0.22 + 0.33 * (beat(0).clamp(0.0, 1.0) * 1.0 + beat(0.22) * 0.7).clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.95,
              colors: [Colors.transparent, const Color(0xFFE5484D).withValues(alpha: a)],
              stops: const [0.6, 1],
            ),
          ),
        );
      },
    );
  }
}
