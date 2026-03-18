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
          childAspectRatio: 0.62,
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
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 캐릭터 이미지
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: char.color.withOpacity(isSelected ? 0.7 : 0.3),
                          blurRadius: isSelected ? 18 : 8,
                        ),
                      ],
                      border: Border.all(
                        color: char.color.withOpacity(0.8),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: char.imagePath != null
                          ? Image.asset(
                              char.imagePath!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, _, __) => Icon(
                                Icons.rocket_launch,
                                color: char.color,
                                size: 34,
                              ),
                            )
                          : Icon(
                              Icons.rocket_launch,
                              color: char.color,
                              size: 34,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 캐릭터 이름
                  Text(
                    LanguageManager.of(context).translate('char_${char.id}'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? char.color : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 스탯 바 4개
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

// ── 스탯 4개 바 ──────────────────────────────────────────
class _StatBars extends StatelessWidget {
  final Character char;
  final Color accentColor;

  const _StatBars({required this.char, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final s = char.stats;
    final ratings = [
      (
        label: '판정',
        rating: CharacterData.hitboxRating(s.hitboxSize),
        // 판정은 역방향: 작을수록 유리 → 별 많을수록 좋음
      ),
      (
        label: '속도',
        rating: CharacterData.speedRating(s.speedMultiplier),
      ),
      (
        label: '에너지',
        rating: CharacterData.shieldRating(s.shieldCount, s.shieldCooldown),
      ),
      (
        label: '반발',
        rating: CharacterData.repelRating(s.repelRadius),
      ),
    ];

    return Column(
      children: ratings
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
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
          width: 28,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textDim,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
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
