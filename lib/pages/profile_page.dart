import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../achievement_manager.dart';
import '../badges.dart';
import '../ad_manager.dart';
import '../audio_manager.dart';
import '../avatar.dart';
import '../player_profile.dart';
import 'player_profile_view.dart';
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
  final VoidCallback onBack;
  final Map<String, double> bestTimes;
  final Map<String, RankCacheEntry> rankCache;

  const ProfilePage({
    super.key,
    required this.onOpenShop,
    required this.onLogout,
    required this.onLogin,
    required this.onStatistics,
    required this.onBack,
    required this.bestTimes,
    required this.rankCache,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, String> _profile = {};
  /// 내 공개 프로필 한 벌 — 남의 프로필과 같은 클래스로 그린다(player_profile.dart)
  PlayerProfile _me = const PlayerProfile(uid: '');
  List<String> _achievementKeys = const [];
  bool _firstEdit = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkMode = false;
  bool _adPrivacyRequired = false;
  String _appVersion = '';
  User? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await UserProfileManager.getProfile();
    final stats = await UserProfileManager.getStatistics();
    final keys = await AchievementManager.getMine();
    final firstEdit = await UserProfileManager.isFirstEditAvailable();
    final avatar = await Avatar.mine(profile['characterId'] ?? Avatar.defaultCharacterId);
    final adPrivacyRequired = await AdManager().isPrivacyOptionsRequired();
    String version = '';
    try {
      version = 'v${(await PackageInfo.fromPlatform()).version}';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _achievementKeys = keys;
      _me = PlayerProfile(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        nickname: profile['nickname'] ?? '',
        flag: profile['flag'] ?? '',
        countryName: profile['countryName'] ?? '',
        avatar: avatar,
        badgeKeys: keys,
        bestTimes: widget.bestTimes,
        totalGames: (stats['totalGamesPlayed'] as num?)?.toInt() ?? 0,
        totalPlayTime: (stats['totalPlayTime'] as num?)?.toDouble() ?? 0,
      );
      _firstEdit = firstEdit;
      _soundEnabled = GameSettings().soundEnabled;
      _vibrationEnabled = GameSettings().vibrationEnabled;
      _darkMode = GameSettings().darkMode;
      _adPrivacyRequired = adPrivacyRequired;
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary),
          ),
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
          NeonButton(
            text: '${lm.translate('shop_buy')} (${formatCount(kTicketPrice)})',
            isCompact: true,
            color: AppColors.coin,
            onPressed: () {
              Navigator.pop(context);
              _buyNicknameTicket(lm);
            },
          ),
        ],
      );
    }
  }

  /// 닉네임 변경권 구매 — 가방에서 빠져서 여기서 바로 산다
  Future<void> _buyNicknameTicket(LanguageManager lm) async {
    if (AuthService.isGuest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lm.translate('guest_login_to_save'))));
      }
      return;
    }
    if (CoinStore.balance.value < kTicketPrice) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lm.translate('shop_not_enough'))));
      return;
    }
    if (!await CoinStore.spend(kTicketPrice)) return;
    await UserProfileManager.setNicknameTickets(await UserProfileManager.getNicknameTickets() + 1);
    if (!mounted) return;
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lm.translate('shop_bought'))));
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NeonAppBar(title: lm.translate('nav_profile'), showBackButton: true, onBack: widget.onBack),
            Expanded(
              child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            // ── 헤더 ──
            // 게스트 — 한 줄만. 누르면 로그인으로
            if (_isGuest)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onLogin,
                child: NeonCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.textDim, width: 1.5),
                        ),
                        child: Icon(Icons.person_outline_rounded, color: AppColors.textDim, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lm.translate('guest'), style: AppTextStyles.display(16)),
                            const SizedBox(height: 2),
                            OneLineText(lm.translate('guest_profile_hint'),
                                style: AppTextStyles.text(11, color: AppColors.textDim)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(lm.translate('login'), style: AppTextStyles.text(13, weight: FontWeight.w800)),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 18),
                    ],
                  ),
                ),
              )
            else
              ProfileIdentityCard(
                profile: _me,
                trailing: AppIconButton(
                  icon: Icons.edit_rounded,
                  label: lm.translate('edit'),
                  color: AppColors.textDim,
                  onTap: _editNickname,
                ),
                stats: [
                  ProfileStat(label: lm.translate('stats_games'), value: '${_me.totalGames}'),
                  ProfileStat(label: lm.translate('stats_total_time'), value: _formatDuration(_me.totalPlayTime)),
                  ProfileStat(label: lm.translate('badges'), value: '${_earnedBadges.length}/${Badges.all.length}'),
                ],
              ),

            // ── 내 기록 — 스테이지별 최고 기록과 세계 순위를 같은 무게로 ──
            const SizedBox(height: 22),
            SectionLabel(lm.translate('world_records')),
            const SizedBox(height: 10),
            for (final w in WorldData.worlds) ...[
              StageRecordRow(
                world: w,
                best: widget.bestTimes[w.id],
                bestLabel: lm.translate('my_best'),
                worldRank: widget.rankCache[w.id]?.rank,
              ),
              const SizedBox(height: 8),
            ],

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
                  _row(
                    lm.translate('dark_mode'),
                    trailing: _switch(_darkMode, (v) async {
                      setState(() => _darkMode = v);
                      await GameSettings().setDarkMode(v);
                    }),
                  ),
                  _row(
                    lm.translate('sound'),
                    trailing: _switch(_soundEnabled, (v) async {
                      setState(() => _soundEnabled = v);
                      await GameSettings().setSound(v);
                      if (!v) AudioManager().stopBgm();
                    }),
                  ),
                  _row(
                    lm.translate('vibration'),
                    trailing: _switch(_vibrationEnabled, (v) async {
                      setState(() => _vibrationEnabled = v);
                      await GameSettings().setVibration(v);
                    }),
                  ),
                  if (_adPrivacyRequired)
                    _row(
                      lm.translate('ad_privacy'),
                      onTap: () => AdManager().showPrivacyOptions(),
                      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20),
                    ),
                  _row(
                    lm.translate('stats_title'),
                    onTap: widget.onStatistics,
                    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20),
                  ),
                  _row(
                    lm.translate('app_version'),
                    trailing: Text(_appVersion, style: AppTextStyles.text(13, color: AppColors.textDim)),
                    last: true,
                  ),
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
                    _row(
                      lm.translate('email'),
                      trailing: Text(
                        _user?.email ?? lm.translate('provider_unknown'),
                        style: AppTextStyles.text(13, color: AppColors.textDim),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _row(
                      lm.translate('logout'),
                      onTap: _confirmLogout,
                      trailing: Icon(Icons.logout_rounded, color: AppColors.textDim, size: 20),
                    ),
                    _row(
                      lm.translate('delete_account'),
                      onTap: _deleteAccount,
                      color: AppColors.danger,
                      trailing: Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 20),
                      last: true,
                    ),
                  ],
                ),
              ),
            ],
          ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<String> get _earnedBadges => {
    for (final b in Badges.all)
      if (_achievementKeys.contains(b.key)) b.key,
  };

  Widget _row(String label, {Widget? trailing, VoidCallback? onTap, Color? color, bool last = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: AppTextStyles.text(14, color: color ?? AppColors.text)),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) => Switch(
    value: value,
    onChanged: onChanged,
    activeThumbColor: AppColors.background,
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

  String _formatDuration(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
