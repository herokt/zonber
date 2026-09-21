import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../achievement_manager.dart';
import '../ad_manager.dart';
import '../audio_manager.dart';
import '../character_data.dart';
import '../design_system.dart';
import '../game_settings.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../coin_store.dart';
import '../services/auth_service.dart';
import '../user_profile.dart';
import '../world_config.dart';

/// 프로필 탭 — 헤더 · 명패 · 월드별 기록 · 캐릭터 · 설정 · 계정. (docs/UI_DESIGN.md §4.6)
class ProfilePage extends StatefulWidget {
  final VoidCallback onOpenShop;
  final Future<void> Function() onLogout;
  final VoidCallback onLogin;
  final VoidCallback onStatistics;
  final VoidCallback onCharacterSelect;
  final Map<String, double> bestTimes;
  final Map<String, RankCacheEntry> rankCache;

  const ProfilePage({
    super.key,
    required this.onOpenShop,
    required this.onLogout,
    required this.onLogin,
    required this.onStatistics,
    required this.onCharacterSelect,
    required this.bestTimes,
    required this.rankCache,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, String> _profile = {};
  Map<String, PlateData> _plates = {};
  Map<String, dynamic> _stats = {};
  List<String> _achievementKeys = const [];
  int _nicknameTickets = 0;
  bool _firstEdit = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkMode = false;
  bool _adPrivacyRequired = false;
  double _sensitivity = GameSettings.defaultSensitivity;
  String _appVersion = '';
  User? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await UserProfileManager.getProfile();
    final plates = await ProgressStore.getPlates();
    final stats = await UserProfileManager.getStatistics();
    final keys = await AchievementManager.getMine();
    final nicknameTickets = await UserProfileManager.getNicknameTickets();
    final firstEdit = await UserProfileManager.isFirstEditAvailable();
    final adPrivacyRequired = await AdManager().isPrivacyOptionsRequired();
    String version = '';
    try {
      version = 'v${(await PackageInfo.fromPlatform()).version}';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _plates = plates;
      _stats = stats;
      _achievementKeys = keys;
      _nicknameTickets = nicknameTickets;
      _firstEdit = firstEdit;
      _soundEnabled = GameSettings().soundEnabled;
      _vibrationEnabled = GameSettings().vibrationEnabled;
      _darkMode = GameSettings().darkMode;
      _adPrivacyRequired = adPrivacyRequired;
      _sensitivity = GameSettings().sensitivity;
      _appVersion = version;
      _user = FirebaseAuth.instance.currentUser;
    });
  }

  bool get _isGuest => _user == null || _user!.isAnonymous;

  // ── 닉네임 편집 (첫 1회 무료, 이후 티켓) ─────────────────────────

  Future<void> _editNickname() async {
    final lm = LanguageManager.of(context, listen: false);
    final controller = TextEditingController(text: _profile['nickname']);
    final result = await showNeonDialog<String>(
      context: context,
      title: lm.translate('change_nickname'),
      content: TextField(
        controller: controller,
        style: AppTextStyles.text(16, weight: FontWeight.w700),
        maxLength: 8,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: lm.translate('new_nickname_hint'),
          hintStyle: AppTextStyles.text(14, color: AppColors.textDim),
          filled: true,
          fillColor: AppColors.surface2,
          counterStyle: AppTextStyles.text(11, color: AppColors.textDim),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
      actions: [
        NeonButton(text: lm.translate('cancel'), isPrimary: false, isCompact: true, onPressed: () => Navigator.pop(context)),
        NeonButton(text: lm.translate('confirm'), isCompact: true, onPressed: () => Navigator.pop(context, controller.text.trim())),
      ],
    );
    if (result == null || result.isEmpty || result == _profile['nickname']) return;

    bool canEdit = false;
    if (_firstEdit) {
      canEdit = true;
      await UserProfileManager.useFirstEdit();
    } else {
      canEdit = await UserProfileManager.useNicknameTicket();
    }
    if (!mounted) return;
    if (canEdit) {
      await UserProfileManager.saveProfile(result, _profile['flag']!, _profile['countryName']!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lm.translate('nickname_changed'))));
      }
    } else {
      showNeonDialog(
        context: context,
        title: lm.translate('no_ticket_title'),
        message: lm.translate('ticket_required').replaceAll('{type}', lm.translate('ticket_nickname')),
        actions: [
          NeonButton(text: lm.translate('close'), isPrimary: false, isCompact: true, onPressed: () => Navigator.pop(context)),
          NeonButton(text: lm.translate('shop'), isCompact: true, onPressed: () { Navigator.pop(context); widget.onOpenShop(); }),
        ],
      );
    }
  }

  // ── 로그아웃 / 계정 삭제 ─────────────────────────────────────────

  void _confirmLogout() {
    final lm = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: lm.translate('logout'),
      message: lm.translate('logout_confirm'),
      actions: [
        NeonButton(text: lm.translate('cancel'), isPrimary: false, isCompact: true, onPressed: () => Navigator.pop(context)),
        NeonButton(
          text: lm.translate('logout'),
          color: AppColors.danger,
          isCompact: true,
          onPressed: () async {
            Navigator.pop(context);
            await widget.onLogout();
          },
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    final lm = LanguageManager.of(context, listen: false);
    final confirmed = await showNeonDialog<bool>(
      context: context,
      title: lm.translate('delete_account_confirm'),
      message: lm.translate('delete_account_message'),
      actions: [
        NeonButton(text: lm.translate('cancel'), isPrimary: false, isCompact: true, onPressed: () => Navigator.pop(context, false)),
        NeonButton(text: lm.translate('delete'), color: AppColors.danger, isCompact: true, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    final success = await AuthService().deleteAccount();
    if (mounted) Navigator.pop(context);
    if (success) {
      await UserProfileManager.clearProfile();
      await ProgressStore.clearLocal();
      await CoinStore.clearLocal();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lm.translate('delete_success'))));
      }
      await widget.onLogout();
    } else if (mounted) {
      showNeonDialog(
        context: context,
        title: 'ERROR',
        message: lm.translate('delete_fail'),
        actions: [NeonButton(text: lm.translate('ok'), isCompact: true, onPressed: () => Navigator.pop(context))],
      );
    }
  }

  // ── 빌드 ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final char = CharacterData.getCharacter(_profile['characterId'] ?? 'neon_green');
    final hasPlate = _plates.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            // ── 헤더 ──
            if (_isGuest)
              NeonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.textDim, width: 1.5)),
                          child: Icon(Icons.person_outline_rounded, color: AppColors.textDim),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lm.translate('guest'), style: AppTextStyles.display(18)),
                              const SizedBox(height: 4),
                              Text(lm.translate('guest_profile_hint'),
                                  style: AppTextStyles.text(12, color: AppColors.textDim, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    NeonButton(text: lm.translate('login'), icon: Icons.login_rounded, isCompact: true, onPressed: widget.onLogin),
                  ],
                ),
              )
            else
              Row(
                children: [
                  CharacterAvatar(characterId: char.id, size: 64, borderColor: hasPlate ? AppColors.gold : char.color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(_profile['nickname'] ?? '',
                                  style: AppTextStyles.display(22), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            if ((_profile['flag'] ?? '').isNotEmpty) CountryChip(flag: _profile['flag']!),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${lm.translate('plates_count').replaceAll('{n}', '${_plates.length}')} · '
                          '${lm.translate('games_count').replaceAll('{n}', '${_stats['totalGamesPlayed'] ?? 0}')} · '
                          '${_formatDuration((_stats['totalPlayTime'] as num?)?.toDouble() ?? 0)}',
                          style: AppTextStyles.text(12, color: AppColors.textDim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.edit_rounded,
                    label: lm.translate('edit'),
                    color: AppColors.textDim,
                    onTap: (_firstEdit || _nicknameTickets > 0) ? _editNickname : () => _editNickname(),
                  ),
                ],
              ),

            // ── 내 명패 ──
            const SizedBox(height: 22),
            SectionLabel(lm.translate('my_plates'), trailing: lm.translate('plates_permanent')),
            const SizedBox(height: 10),
            SizedBox(
              height: 124,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  for (final w in WorldData.worlds)
                    if (_plates[w.id] != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 272,
                          child: NamePlate(
                            nickname: _profile['nickname'] ?? '',
                            flag: _profile['flag'] ?? '',
                            worldName: lm.translate(w.nameKey).toUpperCase(),
                            scopeLabel: lm.translate(_plates[w.id]!.scope == 'world' ? 'plate_scope_world' : 'plate_scope_country'),
                            rank: _plates[w.id]!.rank,
                            survivalTime: _plates[w.id]!.survivalTime,
                            dateLabel: _plates[w.id]!.dateLabel,
                            scope: _plates[w.id]!.scope,
                            compact: true,
                          ),
                        ),
                      ),
                  _emptyPlate(lm),
                ],
              ),
            ),

            // ── 월드별 기록 ──
            const SizedBox(height: 22),
            SectionLabel(lm.translate('world_records')),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [for (final w in WorldData.worlds) _worldRecord(lm, w)],
            ),

            // ── 캐릭터 ──
            const SizedBox(height: 22),
            SectionLabel(lm.translate('character'), trailing: lm.translate('change'), onTrailingTap: widget.onCharacterSelect),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onCharacterSelect,
              child: Row(
                children: [
                  for (final c in CharacterData.availableCharacters)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Opacity(
                        opacity: (c.id == char.id || CharacterData.isUnlocked(c, _achievementKeys)) ? 1 : 0.4,
                        child: CharacterAvatar(characterId: c.id, size: 44, borderColor: c.id == char.id ? c.color : AppColors.surface2),
                      ),
                    ),
                ],
              ),
            ),

            // ── 설정 ──
            const SizedBox(height: 22),
            SectionLabel(lm.translate('settings')),
            const SizedBox(height: 10),
            NeonCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _row(
                    lm.translate('language'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final code in LanguageManager.visibleLanguages) ...[
                          if (code != LanguageManager.visibleLanguages.first) const SizedBox(width: 8),
                          _lang(code, LanguageManager.languageNames[code] ?? code.toUpperCase()),
                        ],
                      ],
                    ),
                  ),
                  _row(lm.translate('dark_mode'), trailing: _switch(_darkMode, (v) async {
                    setState(() => _darkMode = v);
                    await GameSettings().setDarkMode(v);
                  })),
                  _row(lm.translate('sound'), trailing: _switch(_soundEnabled, (v) async {
                    setState(() => _soundEnabled = v);
                    await GameSettings().setSound(v);
                    if (!v) AudioManager().stopBgm();
                  })),
                  _row(lm.translate('vibration'), trailing: _switch(_vibrationEnabled, (v) async {
                    setState(() => _vibrationEnabled = v);
                    await GameSettings().setVibration(v);
                  })),
                  _sensitivityRow(lm),
                  if (_adPrivacyRequired)
                    _row(lm.translate('ad_privacy'), onTap: () => AdManager().showPrivacyOptions(),
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20)),
                  _row(lm.translate('stats_title'), onTap: widget.onStatistics,
                      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20)),
                  _row(lm.translate('app_version'),
                      trailing: Text(_appVersion, style: AppTextStyles.text(13, color: AppColors.textDim)), last: true),
                ],
              ),
            ),

            // ── 계정 ──
            if (!_isGuest) ...[
              const SizedBox(height: 22),
              SectionLabel(lm.translate('account')),
              const SizedBox(height: 10),
              NeonCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _row(lm.translate('email'),
                        trailing: Text(_user?.email ?? lm.translate('provider_unknown'),
                            style: AppTextStyles.text(13, color: AppColors.textDim), overflow: TextOverflow.ellipsis)),
                    _row(lm.translate('logout'), onTap: _confirmLogout,
                        trailing: Icon(Icons.logout_rounded, color: AppColors.textDim, size: 20)),
                    _row(lm.translate('delete_account'), onTap: _deleteAccount, color: AppColors.danger,
                        trailing: Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 20), last: true),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyPlate(LanguageManager lm) {
    final next = WorldData.worlds.firstWhere(
      (w) => _plates[w.id] == null,
      orElse: () => WorldData.defaultWorld,
    );
    return Container(
      width: 272,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surface2, width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            lm.translate('no_plate_hint').replaceAll('{world}', lm.translate(next.nameKey).toUpperCase()),
            textAlign: TextAlign.center,
            style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 10),
          // 받을 수 있는 명패 등급 — 챔피언 · 골드 · 실버 · 브론즈
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final t in PlateTier.values) ...[
                PlateBadge(tier: t, size: 22),
                if (t != PlateTier.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(lm.translate('plate_tiers_hint'),
              style: AppTextStyles.text(9, color: AppColors.textDim, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _worldRecord(LanguageManager lm, WorldConfig w) {
    final unlocked = WorldData.isUnlocked(w, widget.bestTimes);
    final best = widget.bestTimes[w.id];
    final rank = widget.rankCache[w.id];
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: w.accent, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lm.translate(w.nameKey).toUpperCase(), style: AppTextStyles.text(12, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  if (unlocked)
                    Text(best == null ? '—' : formatSurvival(best), style: AppTextStyles.display(16))
                  else
                    Text(
                      lm.translate('coming_soon'),
                      style: AppTextStyles.text(11, color: AppColors.textDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (unlocked && rank != null)
              Text('#${formatCount(rank.rank)}', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700))
            else if (!unlocked)
              Icon(Icons.lock_rounded, color: AppColors.textDim, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, {Widget? trailing, VoidCallback? onTap, Color? color, bool last = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.text(14, color: color ?? AppColors.text))),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) => Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.background,
        activeTrackColor: AppColors.primary,
        inactiveThumbColor: AppColors.textDim,
        inactiveTrackColor: AppColors.surface2,
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      );

  Widget _lang(String code, String label) {
    final selected = LanguageManager.of(context).currentLanguage == code;
    return AppChip(
      label: label,
      filled: selected,
      color: selected ? AppColors.primary : AppColors.textDim,
      onTap: () async {
        await LanguageManager().changeLanguage(code);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _sensitivityRow(LanguageManager lm) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(lm.translate('sensitivity'), style: AppTextStyles.text(14))),
              Text('${_sensitivity.toStringAsFixed(2)}x', style: AppTextStyles.display(13)),
            ],
          ),
          OneLineText(lm.translate('sensitivity_desc'), style: AppTextStyles.text(11, color: AppColors.textDim)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surface2,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: _sensitivity,
              min: GameSettings.minSensitivity,
              max: GameSettings.maxSensitivity,
              divisions: 12,
              onChanged: (v) => setState(() => _sensitivity = v),
              onChangeEnd: (v) => GameSettings().setSensitivity(v),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
