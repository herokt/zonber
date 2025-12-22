import 'package:flutter/material.dart';
import 'character_data.dart';
import 'user_profile.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2833),
        title: const Text(
          'SELECT CHARACTER',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 0.8,
          ),
          itemCount: CharacterData.availableCharacters.length,
          itemBuilder: (context, index) {
            final char = CharacterData.availableCharacters[index];
            final isSelected = char.id == _selectedId;

            return GestureDetector(
              onTap: () => _selectCharacter(char.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2833),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF66FCF1)
                        : Colors.transparent,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF66FCF1).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Preview
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: char.color,
                        boxShadow: [
                          BoxShadow(
                            color: char.color.withOpacity(0.6),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          color: char.color.withOpacity(0.5), // Inner core
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      char.name,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF66FCF1)
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        char.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
