import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import 'design_system.dart';

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
        _selectedCountryName = 'Selected'; // Simplified
      });
    }
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
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      text: "START",
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
}
