import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../audio_manager.dart';
import '../design_system.dart';
import '../game_settings.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../user_profile.dart';
import '../world_config.dart';

/// Hall of Fame 의식 — 순위 카운트다운 → 명패 등장 → 이름 각인. (docs/UI_DESIGN.md §4.4 B)
class HallOfFamePage extends StatefulWidget {
  final PlateData plate;
  final VoidCallback onViewRanking;
  final VoidCallback onClose;

  const HallOfFamePage({
    super.key,
    required this.plate,
    required this.onViewRanking,
    required this.onClose,
  });

  @override
  State<HallOfFamePage> createState() => _HallOfFamePageState();
}

class _HallOfFamePageState extends State<HallOfFamePage> with TickerProviderStateMixin {
  late final AnimationController _rankCtrl;
  late final AnimationController _plateCtrl;
  late final AnimationController _engraveCtrl;
  late final AnimationController _shineCtrl;
  Map<String, String> _profile = {};

  @override
  void initState() {
    super.initState();
    _rankCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _plateCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _engraveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _shineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    UserProfileManager.getProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    });
    _play();
  }

  Future<void> _play() async {
    await _rankCtrl.forward();
    if (!mounted) return;
    await _plateCtrl.forward();
    if (!mounted) return;
    AudioManager().playSfx('hit.wav', volume: 0.5);
    _engraveCtrl.forward().then((_) {
      // 각인이 끝나면 빛이 한 번 판 위를 훑고 지나간다
      if (mounted) _shineCtrl.forward();
    });
    if (GameSettings().vibrationEnabled) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 160), HapticFeedback.heavyImpact);
      Future.delayed(const Duration(milliseconds: 320), HapticFeedback.heavyImpact);
    }
  }

  @override
  void dispose() {
    _rankCtrl.dispose();
    _plateCtrl.dispose();
    _engraveCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  Future<void> _share(LanguageManager lm, String worldName) async {
    final text = lm
        .translate('share_text')
        .replaceAll('{world}', worldName)
        .replaceAll('{rank}', formatCount(widget.plate.rank))
        .replaceAll('{time}', formatSurvival(widget.plate.survivalTime))
        .replaceAll('{link}', lm.translate('download_link'));
    final shareText = LanguageManager.stripJoiners(text);
    try {
      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: shareText));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final world = WorldData.getWorld(widget.plate.worldId);
    final worldName = lm.translate(world.nameKey).toUpperCase();
    final isWorld = widget.plate.scope == 'world';
    final scopeLabel = lm.translate(isWorld ? 'plate_scope_world' : 'plate_scope_country');
    final nickname = _profile['nickname'] ?? '';
    final flag = _profile['flag'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.ceremony, // 명패 의식은 살짝 따뜻하게
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _SpecksPainter())),
            FillScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 64),
                  Text(lm.translate('hof_title'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label(color: AppColors.gold).copyWith(letterSpacing: 3)),
                  const SizedBox(height: 12),
                  Text(lm.translate('hof_engraved'),
                      textAlign: TextAlign.center, style: AppTextStyles.display(24).copyWith(height: 1.3)),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _rankCtrl,
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(_rankCtrl.value);
                      final from = widget.plate.rank * 9 + 300;
                      final shown = (from + (widget.plate.rank - from) * t).round();
                      return Text('#${formatCount(shown)}',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(88, color: AppColors.gold).copyWith(letterSpacing: -2));
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lm
                        .translate(isWorld ? 'hof_of_total' : 'hof_country_of_total')
                        .replaceAll('{n}', formatCount(widget.plate.total)),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.text(14, color: AppColors.textDim, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  AnimatedBuilder(
                    animation: Listenable.merge([_plateCtrl, _engraveCtrl, _shineCtrl]),
                    builder: (context, _) {
                      final slide = 1 - Curves.easeOutCubic.transform(_plateCtrl.value);
                      final shownChars = (nickname.length * _engraveCtrl.value).ceil().clamp(0, nickname.length);
                      return Opacity(
                        opacity: _plateCtrl.value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 40 * slide),
                          child: NamePlate(
                            nickname: nickname.substring(0, shownChars),
                            flag: flag,
                            worldName: worldName,
                            scopeLabel: scopeLabel,
                            rank: widget.plate.rank,
                            survivalTime: widget.plate.survivalTime,
                            dateLabel: widget.plate.dateLabel,
                            scope: widget.plate.scope,
                            shine: _shineCtrl.value == 0 ? -0.2 : Curves.easeInOut.transform(_shineCtrl.value) * 1.2 - 0.1,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(lm.translate('hof_permanent'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.text(12, color: AppColors.textDim, height: 1.5)),
                  const Spacer(),
                  NeonButton(
                    text: lm.translate('share_plate'),
                    icon: Icons.ios_share_rounded,
                    color: AppColors.gold,
                    onPressed: () => _share(lm, worldName),
                  ),
                  const SizedBox(height: 10),
                  NeonButton(
                    text: lm.translate('view_my_rank'),
                    isPrimary: false,
                    isCompact: true,
                    onPressed: widget.onViewRanking,
                  ),
                  SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: widget.onClose,
                      child: Text(lm.translate('home'), style: AppTextStyles.text(14, color: AppColors.textDim, weight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecksPainter extends CustomPainter {
  const _SpecksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.gold.withValues(alpha: 0.7);
    const pts = [
      (0.12, 0.19, 2.0), (0.85, 0.14, 1.5), (0.92, 0.36, 2.0), (0.08, 0.5, 1.5), (0.51, 0.11, 1.0),
      (0.28, 0.66, 1.5), (0.77, 0.71, 2.0), (0.18, 0.83, 1.0), (0.87, 0.85, 1.5), (0.64, 0.21, 1.0),
    ];
    for (final (x, y, r) in pts) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // 테마 전환 시 금색이 바뀐다
}
