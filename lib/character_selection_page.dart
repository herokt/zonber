import 'dart:math';
import 'package:flutter/material.dart';
import 'character_data.dart';
import 'user_profile.dart';
import 'design_system.dart';
import 'language_manager.dart';

class CharacterSelectionPage extends StatefulWidget {
  final VoidCallback onBack;

  const CharacterSelectionPage({super.key, required this.onBack});

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  String _selectedId = 'neon_green';

  @override
  void initState() {
    super.initState();
    _loadCurrentCharacter();
  }

  Future<void> _loadCurrentCharacter() async {
    final profile = await UserProfileManager.getProfile();
    setState(() {
      _selectedId = profile['characterId'] ?? 'neon_green';
    });
  }

  Future<void> _selectCharacter(String id) async {
    setState(() {
      _selectedId = id;
    });
    final profile = await UserProfileManager.getProfile();
    await UserProfileManager.saveProfile(
      profile['nickname']!,
      profile['flag']!,
      profile['countryName']!,
      characterId: id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: LanguageManager.of(context).translate('select_character'),
      showBackButton: true,
      onBack: widget.onBack,
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
        itemCount: CharacterData.availableCharacters.length,
        itemBuilder: (context, index) {
          final char = CharacterData.availableCharacters[index];
          final isSelected = char.id == _selectedId;

          return GestureDetector(
            onTap: () => _selectCharacter(char.id),
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
                  // 캐릭터 이미지 (회전 애니메이션, 원형 배경 없음)
                  _RotatingCharacterImage(char: char, isSelected: isSelected),
                  const SizedBox(height: 8),

                  // 캐릭터 이름
                  Text(
                    LanguageManager.of(context).translate('char_${char.id}'),
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
                  const SizedBox(height: 8),

                  // 스탯 바 3개
                  _StatBars(char: char, accentColor: char.color),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 회전 캐릭터 이미지 ────────────────────────────────────
class _RotatingCharacterImage extends StatefulWidget {
  final Character char;
  final bool isSelected;

  const _RotatingCharacterImage({required this.char, required this.isSelected});

  @override
  State<_RotatingCharacterImage> createState() =>
      _RotatingCharacterImageState();
}

class _RotatingCharacterImageState extends State<_RotatingCharacterImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final char = widget.char;
    final isSelected = widget.isSelected;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.rotate(
        angle: _controller.value * 2 * pi,
        child: child,
      ),
      child: Container(
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
    );
  }
}

// ── 스탯 3개 바 ──────────────────────────────────────────
class _StatBars extends StatelessWidget {
  final Character char;
  final Color accentColor;

  const _StatBars({required this.char, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final s = char.stats;
    final ratings = [
      (label: '피지컬', rating: CharacterData.hitboxRating(s.hitboxSize)),
      (label: '속도', rating: CharacterData.speedRating(s.speedMultiplier)),
      (label: '에너지', rating: CharacterData.shieldRating(s.shieldCount, s.shieldCooldown)),
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
