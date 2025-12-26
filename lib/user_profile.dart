import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import 'design_system.dart';
import 'game_settings.dart';
import 'audio_manager.dart';

class UserProfileManager {
  static const String _keyNickname = 'user_nickname';
  static const String _keyFlag = 'user_flag_code';
  static const String _keyCountryName = 'user_country_name';
  static const String _keyCharacterId = 'user_character_id';

  static Future<bool> hasProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyNickname) && prefs.containsKey(_keyFlag);
  }

  static Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nickname': prefs.getString(_keyNickname) ?? 'Unknown',
      'flag': prefs.getString(_keyFlag) ?? '🏳️',
      'countryName': prefs.getString(_keyCountryName) ?? 'Unknown Region',
      'characterId': prefs.getString(_keyCharacterId) ?? 'neon_green',
    };
  }

  static Future<void> saveProfile(
    String nickname,
    String flag,
    String countryName, {
    String? characterId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
    await prefs.setString(_keyFlag, flag);
    await prefs.setString(_keyCountryName, countryName);
    if (characterId != null) {
      await prefs.setString(_keyCharacterId, characterId);
    }
  }
}

class UserProfilePage extends StatefulWidget {
  final VoidCallback onComplete;

  const UserProfilePage({super.key, required this.onComplete});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  String _selectedFlag = '';
  String _selectedCountryName = 'Select Country';
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final profile = await UserProfileManager.getProfile();
    if (profile['nickname'] != 'Unknown') {
      _nicknameController.text = profile['nickname']!;
    }
    if (profile['flag'] != '🏳️') {
      setState(() {
        _selectedFlag = profile['flag']!;
        _selectedCountryName = 'Selected';
      });
    }
    // Load settings
    setState(() {
      _soundEnabled = GameSettings().soundEnabled;
      _vibrationEnabled = GameSettings().vibrationEnabled;
    });
  }

  Future<void> _saveAndContinue() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a nickname')));
      return;
    }
    if (_selectedFlag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your country')),
      );
      return;
    }

    await UserProfileManager.saveProfile(
      _nicknameController.text.trim(),
      _selectedFlag,
      _selectedCountryName,
    );

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: "PROFILE SETUP",
      body: Center(
        child: SingleChildScrollView(
          child: NeonCard(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header removed as NeonScaffold has it, but this is a card content so maybe "EDIT PROFILE"?
                  // Or just keep the fields.
                  TextField(
                    controller: _nicknameController,
                    style: AppTextStyles.body.copyWith(fontSize: 16),
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: "NICKNAME",
                      labelStyle: TextStyle(color: AppColors.textDim),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.textDim),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      counterStyle: TextStyle(color: AppColors.textDim),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "SELECT COUNTRY",
                    style: TextStyle(color: AppColors.textDim, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        favorite: ['KR'],
                        onSelect: (Country country) {
                          setState(() {
                            _selectedFlag = country.flagEmoji;
                            _selectedCountryName = country.name;
                          });
                        },
                        countryListTheme: CountryListThemeData(
                          backgroundColor: AppColors.surface,
                          textStyle: const TextStyle(color: Colors.white),
                          searchTextStyle: const TextStyle(color: Colors.white),
                          bottomSheetHeight: 600,
                          borderRadius: BorderRadius.circular(20),
                          inputDecoration: InputDecoration(
                            hintText: 'Search country',
                            hintStyle: TextStyle(color: AppColors.textDim),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.textDim,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.textDim),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedFlag.isNotEmpty
                              ? AppColors.primary
                              : AppColors.textDim,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedFlag.isEmpty
                                  ? "Tap to select"
                                  : "$_selectedFlag  $_selectedCountryName",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Settings Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryDim.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SETTINGS",
                          style: TextStyle(
                            color: AppColors.textDim,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingRow(
                          icon: Icons.volume_up,
                          label: "Sound",
                          value: _soundEnabled,
                          onChanged: (value) async {
                            setState(() => _soundEnabled = value);
                            await GameSettings().setSound(value);
                            AudioManager().refreshBgm();
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildSettingRow(
                          icon: Icons.vibration,
                          label: "Vibration",
                          value: _vibrationEnabled,
                          onChanged: (value) async {
                            setState(() => _vibrationEnabled = value);
                            await GameSettings().setVibration(value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      text: "SAVE",
                      onPressed: _saveAndContinue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withOpacity(0.3),
          inactiveThumbColor: AppColors.textDim,
          inactiveTrackColor: AppColors.textDim.withOpacity(0.3),
        ),
      ],
    );
  }
}
