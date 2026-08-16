import 'dart:math';
import 'package:flutter/material.dart';
import 'character_data.dart';
import 'user_profile.dart';
import 'design_system.dart';
import 'language_manager.dart';
import 'achievement_manager.dart';

class CharacterSelectionPage extends StatefulWidget {
  final VoidCallback onBack;

  const CharacterSelectionPage({super.key, required this.onBack});

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  String _selectedId = 'neon_green';
  List<String> _achievementKeys = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentCharacter();
  }

  Future<void> _loadCurrentCharacter() async {
    final profile = await UserProfileManager.getProfile();
    final keys = await AchievementManager.getMine();
    if (!mounted) return;
    setState(() {
      _selectedId = profile['characterId'] ?? 'neon_green';
      _achievementKeys = keys;
      _loading = false;
    });
  }

  /// 이미 사용 중인 캐릭터는 해금 조건과 무관하게 계속 쓸 수 있게 한다
  /// (해금 시스템 도입 이전 유저의 선택을 뺏지 않기 위함).
  bool _isUnlocked(Character char) =>
      char.id == _selectedId ||
      CharacterData.isUnlocked(char, _achievementKeys);

  Future<void> _selectCharacter(Character char) async {
    if (!_isUnlocked(char)) {
      _showLockedDialog(char);
      return;
    }
    setState(() {
      _selectedId = char.id;
    });
    final profile = await UserProfileManager.getProfile();
    await UserProfileManager.saveProfile(
      profile['nickname']!,
      profile['flag']!,
      profile['countryName']!,
      characterId: char.id,
    );
  }

  void _showLockedDialog(Character char) {
    final lm = LanguageManager.of(context, listen: false);
    final achName = lm.translate(char.unlockKey ?? '');
    showNeonDialog(
      context: context,
      title: lm.translate('locked'),
      titleColor: AppColors.textDim,
      message: lm
          .translate('character_locked_message')
          .replaceAll('{name}', achName),
      actions: [
        NeonButton(
          text: lm.translate('ok'),
          onPressed: () => Navigator.of(context).pop(),
          isCompact: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: LanguageManager.of(context).translate('select_character'),
      showBackButton: true,
      onBack: widget.onBack,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemCount: CharacterData.availableCharacters.length,
        itemBuilder: (context, index) {
          final lm = LanguageManager.of(context);
          final char = CharacterData.availableCharacters[index];
          final isSelected = char.id == _selectedId;
          final unlocked = _isUnlocked(char);

          return GestureDetector(
            onTap: () => _selectCharacter(char),
            child: Opacity(
              opacity: unlocked ? 1.0 : 0.55,
              child: NeonCard(
                borderColor: isSelected ? char.color : Colors.transparent,
                backgroundColor: isSelected
                    ? char.color.withOpacity(0.08)
                    : AppColors.surfaceGlass,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 캐릭터 이미지 (잠금 시 자물쇠 오버레이)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        _RotatingCharacterImage(char: char, isSelected: isSelected),
                        if (!unlocked)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded,
                                color: Colors.white70, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 캐릭터 이름
                    Text(
                      lm.translate('char_${char.id}'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? char.color : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (unlocked)
                      // 스탯 바 4개
                      _StatBars(char: char, accentColor: char.color)
                    else
                      Text(
                        lm
                            .translate('unlock_requirement')
                            .replaceAll('{name}', lm.translate(char.unlockKey!)),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: AppColors.textDim,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 회전 캐릭터 이미지 + 파티클 ──────────────────────────
class _RotatingCharacterImage extends StatefulWidget {
  final Character char;
  final bool isSelected;

  const _RotatingCharacterImage({required this.char, required this.isSelected});

  @override
  State<_RotatingCharacterImage> createState() =>
      _RotatingCharacterImageState();
}

class _RotatingCharacterImageState extends State<_RotatingCharacterImage>
    with TickerProviderStateMixin {
  late final AnimationController _rotController;
  late final AnimationController _particleController;
  late final List<_Particle> _particles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _particles = List.generate(16, (_) => _Particle(_rng));
    if (widget.isSelected) _particleController.repeat();
  }

  @override
  void didUpdateWidget(_RotatingCharacterImage old) {
    super.didUpdateWidget(old);
    if (old.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _particleController.repeat();
      } else {
        _particleController.stop();
        _particleController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rotController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final char = widget.char;
    final isSelected = widget.isSelected;

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 파티클 레이어 (선택시에만)
          if (isSelected)
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                size: const Size(96, 96),
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                  color: char.color,
                ),
              ),
            ),

          // 후광 + 캐릭터 이미지
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: char.color.withOpacity(isSelected ? 0.22 : 0.07),
                  blurRadius: isSelected ? 16 : 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _rotController,
              builder: (_, child) => Transform.rotate(
                angle: _rotController.value * 2 * pi,
                child: child,
              ),
              child: char.imagePath != null
                  ? Image.asset(
                      char.imagePath!,
                      width: 76,
                      height: 76,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, _, __) => Icon(
                        Icons.rocket_launch,
                        color: char.color,
                        size: 48,
                      ),
                    )
                  : Icon(
                      Icons.rocket_launch,
                      color: char.color,
                      size: 48,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 파티클 데이터 ─────────────────────────────────────────
class _Particle {
  final double angle;
  final double startRadius;
  final double speed;
  final double size;
  final double phase;
  final double sway;

  _Particle(Random rng)
      : angle = rng.nextDouble() * 2 * pi,
        startRadius = 24 + rng.nextDouble() * 14,
        speed = 0.25 + rng.nextDouble() * 0.4,
        size = 1.5 + rng.nextDouble() * 2.5,
        phase = rng.nextDouble(),
        sway = (rng.nextDouble() - 0.5) * 18;
}

// ── 파티클 페인터 (후광 링 + 연기) ───────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 후광 링 (천천히 맥동)
    final haloPulse = (sin(progress * 2 * pi) * 0.5 + 0.5);
    final haloPaint = Paint()
      ..color = color.withOpacity(0.12 + haloPulse * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 40 + haloPulse * 3, haloPaint);

    // 연기 파티클
    for (final p in particles) {
      final t = (progress + p.phase) % 1.0;
      final opacity = t < 0.25
          ? (t / 0.25) * 0.65
          : ((1.0 - t) / 0.75) * 0.65;

      final dist = p.startRadius + t * 26 * p.speed;
      final x = center.dx + cos(p.angle) * dist + p.sway * t;
      final y = center.dy + sin(p.angle) * dist - t * 14;

      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

      canvas.drawCircle(Offset(x, y), p.size * (1 - t * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ── 스탯 3개 바 ──────────────────────────────────────────
class _StatBars extends StatelessWidget {
  final Character char;
  final Color accentColor;

  const _StatBars({required this.char, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final s = char.stats;
    final lm = LanguageManager.of(context);
    final ratings = [
      (label: lm.translate('stat_energy'), rating: CharacterData.energyRating(s.maxEnergy)),
      (label: lm.translate('stat_speed'), rating: CharacterData.speedRating(s.speedMultiplier)),
      (label: lm.translate('stat_recovery'), rating: CharacterData.cooldownRating(s.energyCooldown)),
      (label: lm.translate('stat_evasion'), rating: CharacterData.iframeRating(s.iframeDuration)),
    ];

    return Column(
      children: ratings
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _SingleStatBar(
                  label: r.label,
                  rating: r.rating,
                  maxRating: 5,
                  color: accentColor,
                ),
              ))
          .toList(),
    );
  }
}

class _SingleStatBar extends StatelessWidget {
  final String label;
  final int rating;
  final int maxRating;
  final Color color;

  const _SingleStatBar({
    required this.label,
    required this.rating,
    required this.maxRating,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: AppColors.textDim,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: List.generate(maxRating, (i) {
              final filled = i < rating;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: filled ? color : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
