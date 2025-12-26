import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'design_system.dart';
import 'game_settings.dart';
import 'audio_manager.dart';

class UserProfileManager {
  static const String _keyNickname = 'user_nickname';
  static const String _keyFlag = 'user_flag_code';
  static const String _keyCountryName = 'user_country_name';
  static const String _keyCharacterId = 'user_character_id';
  static const String _keyInitialSetupDone = 'initial_setup_done';
  static const String _keyNicknameTicket = 'nickname_change_ticket';
  static const String _keyCountryTicket = 'country_change_ticket';

  static Future<bool> hasProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyInitialSetupDone) ?? false;
  }

  static Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nickname': prefs.getString(_keyNickname) ?? 'Unknown',
      'flag': prefs.getString(_keyFlag) ?? '',
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

  static Future<void> markInitialSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInitialSetupDone, true);
  }

  static Future<int> getNicknameTickets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNicknameTicket) ?? 0;
  }

  static Future<int> getCountryTickets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCountryTicket) ?? 0;
  }

  static Future<void> addNicknameTicket(int count) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyNicknameTicket) ?? 0;
    await prefs.setInt(_keyNicknameTicket, current + count);
  }

  static Future<void> addCountryTicket(int count) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyCountryTicket) ?? 0;
    await prefs.setInt(_keyCountryTicket, current + count);
  }

  static Future<bool> useNicknameTicket() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyNicknameTicket) ?? 0;
    if (current > 0) {
      await prefs.setInt(_keyNicknameTicket, current - 1);
      return true;
    }
    return false;
  }

  static Future<bool> useCountryTicket() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyCountryTicket) ?? 0;
    if (current > 0) {
      await prefs.setInt(_keyCountryTicket, current - 1);
      return true;
    }
    return false;
  }
}

class InitialSetupPage extends StatefulWidget {
  final VoidCallback onComplete;

  const InitialSetupPage({super.key, required this.onComplete});

  @override
  State<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends State<InitialSetupPage> {
  final TextEditingController _nicknameController = TextEditingController();
  String _selectedFlag = '';
  String _selectedCountryName = '';

  Future<void> _saveAndContinue() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a nickname')),
      );
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
    await UserProfileManager.markInitialSetupDone();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("WELCOME", style: AppTextStyles.header.copyWith(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                "SET UP YOUR PROFILE",
                style: AppTextStyles.body.copyWith(color: AppColors.textDim, letterSpacing: 2.0),
              ),
              const SizedBox(height: 40),
              NeonCard(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _nicknameController,
                        style: AppTextStyles.body.copyWith(fontSize: 16),
                        maxLength: 8,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: "NICKNAME",
                          labelStyle: TextStyle(color: AppColors.textDim),
                          hintText: "Enter nickname",
                          hintStyle: TextStyle(color: AppColors.textDim.withOpacity(0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.textDim),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          counterStyle: TextStyle(color: AppColors.textDim),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "SELECT COUNTRY",
                        style: TextStyle(color: AppColors.textDim, fontSize: 12, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showCountryPicker(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedFlag.isNotEmpty ? AppColors.primary : AppColors.textDim,
                              width: _selectedFlag.isNotEmpty ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_selectedFlag.isEmpty)
                                Text("Tap to select", style: TextStyle(color: AppColors.textDim, fontSize: 16))
                              else ...[
                                Text(_selectedFlag, style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _selectedCountryName,
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                color: _selectedFlag.isNotEmpty ? AppColors.primary : AppColors.textDim,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: NeonButton(text: "START", onPressed: _saveAndContinue, icon: Icons.play_arrow),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "This cannot be changed later\nwithout a change ticket",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textDim.withOpacity(0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      favorite: ['KR', 'US', 'JP'],
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
        bottomSheetHeight: 500,
        borderRadius: BorderRadius.circular(20),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          hintStyle: TextStyle(color: AppColors.textDim),
          prefixIcon: Icon(Icons.search, color: AppColors.textDim),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.textDim)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}

class MyProfilePage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onOpenShop;
  final VoidCallback onLogout;

  const MyProfilePage({super.key, required this.onBack, required this.onOpenShop, required this.onLogout});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  Map<String, String> _profile = {};
  int _nicknameTickets = 0;
  int _countryTickets = 0;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await UserProfileManager.getProfile();
    final nicknameTickets = await UserProfileManager.getNicknameTickets();
    final countryTickets = await UserProfileManager.getCountryTickets();
    setState(() {
      _profile = profile;
      _nicknameTickets = nicknameTickets;
      _countryTickets = countryTickets;
      _soundEnabled = GameSettings().soundEnabled;
      _vibrationEnabled = GameSettings().vibrationEnabled;
      _currentUser = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _profile['nickname']);
    final result = await showNeonDialog<String>(
      context: context,
      title: "CHANGE NICKNAME",
      content: TextField(
        controller: controller,
        style: AppTextStyles.body.copyWith(fontSize: 16),
        maxLength: 8,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: "New nickname",
          hintStyle: TextStyle(color: AppColors.textDim),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.textDim)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          counterStyle: TextStyle(color: AppColors.textDim),
        ),
      ),
      actions: [
        NeonButton(text: "CANCEL", color: AppColors.secondary, isPrimary: false, onPressed: () => Navigator.pop(context)),
        NeonButton(text: "CONFIRM", onPressed: () => Navigator.pop(context, controller.text.trim())),
      ],
    );
    if (result != null && result.isNotEmpty && result != _profile['nickname']) {
      bool used = await UserProfileManager.useNicknameTicket();
      if (used) {
        await UserProfileManager.saveProfile(result, _profile['flag']!, _profile['countryName']!);
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nickname changed!')));
      }
    }
  }

  Future<void> _editCountry() async {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      favorite: ['KR', 'US', 'JP'],
      onSelect: (Country country) async {
        bool used = await UserProfileManager.useCountryTicket();
        if (used) {
          await UserProfileManager.saveProfile(_profile['nickname']!, country.flagEmoji, country.name);
          _loadData();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Country changed!')));
        }
      },
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.surface,
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        bottomSheetHeight: 500,
        borderRadius: BorderRadius.circular(20),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          hintStyle: TextStyle(color: AppColors.textDim),
          prefixIcon: Icon(Icons.search, color: AppColors.textDim),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.textDim)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }

  void _showNoTicketDialog(String type) {
    showNeonDialog(
      context: context,
      title: "NO TICKET",
      message: "You need a $type Change Ticket.\n\nVisit the Shop to purchase one.",
      actions: [
        NeonButton(text: "GO TO SHOP", onPressed: () { Navigator.pop(context); widget.onOpenShop(); }),
        NeonButton(text: "CLOSE", color: AppColors.textDim, isPrimary: false, onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: "MY PROFILE",
      showBackButton: true,
      onBack: widget.onBack,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("ACCOUNT", Icons.account_circle),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.email, "Email", _currentUser?.email ?? 'Not logged in'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.verified_user, "Provider", _getProviderName()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("PROFILE", Icons.person),
                  const SizedBox(height: 16),
                  _buildEditableRow(Icons.badge, "Nickname", _profile['nickname'] ?? 'Unknown', _nicknameTickets, _nicknameTickets > 0 ? _editNickname : null),
                  const SizedBox(height: 12),
                  _buildEditableRow(Icons.flag, "Country", "${_profile['flag'] ?? ''} ${_profile['countryName'] ?? 'Unknown'}", _countryTickets, _countryTickets > 0 ? _editCountry : null),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NeonCard(
              borderColor: const Color(0xFFFFD700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("MY TICKETS", Icons.confirmation_number, color: const Color(0xFFFFD700)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTicketBadge("Nickname", _nicknameTickets, Icons.badge)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTicketBadge("Country", _countryTickets, Icons.flag)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(text: "VISIT SHOP", color: const Color(0xFFFFD700), icon: Icons.store, onPressed: widget.onOpenShop),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("SETTINGS", Icons.settings),
                  const SizedBox(height: 16),
                  _buildSettingRow(Icons.volume_up, "Sound", _soundEnabled, (v) async { setState(() => _soundEnabled = v); await GameSettings().setSound(v); AudioManager().refreshBgm(); }),
                  const SizedBox(height: 8),
                  _buildSettingRow(Icons.vibration, "Vibration", _vibrationEnabled, (v) async { setState(() => _vibrationEnabled = v); await GameSettings().setVibration(v); }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                text: "LOGOUT",
                color: AppColors.secondary,
                icon: Icons.logout,
                onPressed: () {
                  showNeonDialog(
                    context: context,
                    title: "LOGOUT",
                    message: "Are you sure you want to logout?",
                    actions: [
                      NeonButton(text: "CANCEL", isPrimary: false, onPressed: () => Navigator.pop(context)),
                      NeonButton(text: "LOGOUT", color: AppColors.secondary, onPressed: () { Navigator.pop(context); widget.onLogout(); }),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getProviderName() {
    if (_currentUser == null) return 'None';
    for (var info in _currentUser!.providerData) {
      if (info.providerId == 'google.com') return 'Google';
      if (info.providerId == 'apple.com') return 'Apple';
    }
    return 'Unknown';
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color ?? AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textDim, size: 18),
        const SizedBox(width: 12),
        Text("$label:", style: TextStyle(color: AppColors.textDim, fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildEditableRow(IconData icon, String label, String value, int ticketCount, VoidCallback? onEdit) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textDim, size: 18),
        const SizedBox(width: 12),
        Text("$label:", style: TextStyle(color: AppColors.textDim, fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
        if (ticketCount > 0)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit, color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Text("EDIT", style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          )
        else
          Icon(Icons.lock, color: AppColors.textDim.withOpacity(0.5), size: 16),
      ],
    );
  }

  Widget _buildTicketBadge(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: count > 0 ? const Color(0xFFFFD700).withOpacity(0.5) : AppColors.textDim.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: count > 0 ? const Color(0xFFFFD700) : AppColors.textDim, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textDim, fontSize: 11)),
        const SizedBox(height: 2),
        Text("$count", style: TextStyle(color: count > 0 ? const Color(0xFFFFD700) : AppColors.textDim, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildSettingRow(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ]),
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

class UserProfilePage extends StatefulWidget {
  final VoidCallback onComplete;
  const UserProfilePage({super.key, required this.onComplete});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  @override
  Widget build(BuildContext context) => InitialSetupPage(onComplete: widget.onComplete);
}
