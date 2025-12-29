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

    // Save immediately
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
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.75,
        ),
        itemCount: CharacterData.availableCharacters.length,
        itemBuilder: (context, index) {
          final char = CharacterData.availableCharacters[index];
          final isSelected = char.id == _selectedId;

          return GestureDetector(
            onTap: () => _selectCharacter(char.id),
            child: NeonCard(
              borderColor: isSelected ? AppColors.primary : Colors.transparent,
              backgroundColor: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.surfaceGlass,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Preview
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      // color: char.color.withOpacity(0.2), // Removed background color
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: char.color.withOpacity(isSelected ? 0.8 : 0.4),
                          blurRadius: isSelected ? 20 : 10,
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
                              width: 60,
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, _, __) => Icon(
                                Icons.rocket_launch,
                                color: char.color,
                                size: 40,
                              ),
                            )
                          : Icon(
                              Icons.rocket_launch,
                              color: char.color,
                              size: 40,
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    LanguageManager.of(context).translate('char_${char.id}'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      LanguageManager.of(
                        context,
                      ).translate('char_${char.id}_desc'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textDim,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
