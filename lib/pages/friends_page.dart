import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../avatar.dart';
import '../badges.dart';
import '../design_system.dart';
import '../friends.dart';
import '../language_manager.dart';
import '../player_profile.dart';
import '../promotions.dart';
import '../services/auth_service.dart';
import '../services/share_service.dart';
import '../world_config.dart';
import 'player_profile_view.dart';
import 'promo_page.dart' show rewardText;

// ─────────────────────────────────────────────────────────────
// 친구 화면 — 프로필 탭 › 친구 (docs/FRIENDS.md)
//   ① 내 친구 코드(복사 · 공유) ② 코드로 추가 ③ 받은 요청(수락 · 거절) ④ 친구 랭킹(고른 존의 최고 기록 순, 나 포함)
//   친구를 누르면 프로필 카드(기록 · 이 기록 깨러 가기 · 친구 삭제). 창을 닫으면 목록을 다시 읽는다
// 게스트는 로그인 안내만.
// ─────────────────────────────────────────────────────────────
class FriendsPage extends StatefulWidget {
  final String initialWorldId;
  final VoidCallback onBack;
  final VoidCallback onLogin;

  /// 이 기록 깨러 가기 — 친구 기록을 목표로 판을 연다
  final void Function(String worldId, String name, double time) onChallenge;

  const FriendsPage({
    super.key,
    required this.initialWorldId,
    required this.onBack,
    required this.onLogin,
    required this.onChallenge,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late String _worldId = widget.initialWorldId;
  bool _loading = true;
  bool _busy = false;
  String? _myCode;
  String _myUid = '';
  Set<String> _ids = const {};
  List<FriendRequest> _incoming = const [];
  Map<String, PlayerProfile> _profiles = const {};
  final TextEditingController _code = TextEditingController();

  bool get _isGuest => AuthService.isGuest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isGuest) {
      setState(() => _loading = false);
      return;
    }
    final results = await Future.wait([Friends.refresh(), Friends.incoming(), FriendService.myCode()]);
    final ids = results[0] as Set<String>;
    final incoming = results[1] as List<FriendRequest>;
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final profiles = await Friends.profiles({...ids, _myUid, for (final r in incoming) r.from});
    if (!mounted) return;
    setState(() {
      _ids = ids;
      _incoming = incoming;
      _myCode = results[2] as String?;
      _profiles = profiles;
      _loading = false;
    });
  }

  void _toast(String key) {
    final lm = LanguageManager.of(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lm.translate(key)), duration: const Duration(seconds: 2)));
  }

  Future<void> _run(Future<FriendResult> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await f();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(friendResultKey(r));
    await _load();
  }

  Future<void> _addByCode() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    await _run(() async {
      final r = await Friends.addByCode(code);
      if (r == FriendResult.added) _code.clear();
      return r;
    });
  }

  Future<void> _copyCode() async {
    final code = _myCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _toast('friend_code_copied');
  }

  Future<void> _shareCode(Rect? origin) async {
    final code = _myCode;
    if (code == null) return;
    final lm = LanguageManager.of(context, listen: false);
    final text = [
      lm.translate('friend_share_line').replaceAll('{code}', code).replaceAll('{reward}', rewardText(lm, FriendCodes.newcomerCoins, const [])),
      ShareLinks.url(lang: lm.currentLanguage, src: 'friends', code: code),
    ].join('\n');
    final outcome = await ShareService.share(text: text, src: 'friends', itemId: 'friend_code', origin: origin);
    if (outcome == ShareOutcome.copied && mounted) _toast('promo_share_copied');
  }

  Future<void> _open(String uid, double time) async {
    final p = _profiles[uid];
    final name = (p?.nickname.isNotEmpty ?? false) ? p!.nickname : '?';
    final worldId = _worldId;
    await showPlayerCard(
      context,
      uid: uid,
      zone: worldId,
      challenge: uid == _myUid || time <= 0 ? null : (time: time, onTap: () => widget.onChallenge(worldId, name, time)),
    );
    if (mounted) _load(); // 창에서 친구를 삭제했을 수 있다
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return NeonScaffold(
      title: lm.translate('friends_title'),
      showBackButton: true,
      onBack: widget.onBack,
      body: _isGuest
          ? _guest(lm)
          : _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _myCodeCard(lm),
                      const SizedBox(height: 10),
                      _codeInput(lm),
                      if (_incoming.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        SectionLabel('${lm.translate('friend_requests')} ${_incoming.length}'),
                        const SizedBox(height: 10),
                        for (final r in _incoming) ...[_requestRow(lm, r), const SizedBox(height: 8)],
                      ],
                      const SizedBox(height: 22),
                      SectionLabel('${lm.translate('friend_list')} · ${_ids.length}/${Friends.maxFriends}'),
                      const SizedBox(height: 10),
                      StageFilter(selectedId: _worldId, onChanged: (id) => setState(() => _worldId = id)),
                      const SizedBox(height: 12),
                      _ranking(lm),
                    ],
                  ),
                ),
    );
  }

  Widget _guest(LanguageManager lm) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.group_outlined, color: AppColors.textDim, size: 44),
            const SizedBox(height: 12),
            Text(lm.translate('friend_guest'), textAlign: TextAlign.center, style: AppTextStyles.text(14, color: AppColors.textDim)),
            const SizedBox(height: 18),
            NeonButton(text: lm.translate('login'), isCompact: true, onPressed: widget.onLogin),
          ]),
        ),
      );

  Widget _myCodeCard(LanguageManager lm) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _copyCode,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lm.translate('friend_my_code'), style: AppTextStyles.text(11.5, color: AppColors.textDim, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(_myCode ?? '—', style: AppTextStyles.display(26, color: AppColors.primary).copyWith(letterSpacing: 4)),
                  const SizedBox(width: 8),
                  if (_myCode != null) Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                ]),
              ]),
            ),
          ),
          Builder(
            builder: (b) => NeonButton(
              text: lm.translate('friend_share'),
              icon: Icons.ios_share_rounded,
              isCompact: true,
              onPressed: _myCode == null
                  ? null
                  : () {
                      final box = b.findRenderObject() as RenderBox?;
                      _shareCode(box == null ? null : box.localToGlobal(Offset.zero) & box.size);
                    },
            ),
          ),
        ]),
      );

  Widget _codeInput(LanguageManager lm) => Row(children: [
        Expanded(
          child: TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 5,
            style: AppTextStyles.text(14, weight: FontWeight.w800),
            onSubmitted: (_) => _addByCode(),
            decoration: InputDecoration(
              hintText: lm.translate('friend_code_hint'),
              hintStyle: AppTextStyles.text(12.5, color: AppColors.textDim),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        NeonButton(text: lm.translate('friend_add'), isCompact: true, onPressed: _busy ? null : _addByCode),
      ]);

  Widget _requestRow(LanguageManager lm, FriendRequest r) {
    final p = _profiles[r.from];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
      child: Row(children: [
        GestureDetector(
          onTap: () => _open(r.from, 0),
          child: AvatarView(avatar: p?.avatar ?? Avatar.fallback, zone: _worldId, size: 34),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OneLineText(
            (p?.nickname.isNotEmpty ?? false) ? p!.nickname : lm.translate('unknown'),
            style: AppTextStyles.text(14, weight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => _run(() => Friends.answer(r.from, accept: false)),
          child: Text(lm.translate('friend_decline'), style: AppTextStyles.text(13, color: AppColors.textDim, weight: FontWeight.w700)),
        ),
        NeonButton(
          text: lm.translate('friend_accept'),
          isCompact: true,
          onPressed: _busy ? null : () => _run(() => Friends.answer(r.from, accept: true)),
        ),
      ]),
    );
  }

  /// 친구 랭킹 — 나 + 친구, 이 존 기록이 있는 사람만 기록 순. 없는 사람은 아래 한 줄로 센다
  Widget _ranking(LanguageManager lm) {
    if (_ids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(lm.translate('friend_empty'), textAlign: TextAlign.center, style: AppTextStyles.text(13.5, color: AppColors.textDim)),
      );
    }
    final world = WorldData.getWorld(_worldId);
    final rows = [
      for (final uid in {..._ids, _myUid})
        if ((_profiles[uid]?.bestOf(_worldId) ?? 0) > 0) (uid: uid, time: _profiles[uid]!.bestOf(_worldId)!),
    ]..sort((a, b) => b.time.compareTo(a.time));
    final noRecord = _ids.where((u) => (_profiles[u]?.bestOf(_worldId) ?? 0) <= 0).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (rows.isNotEmpty)
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < rows.length; i++)
              Builder(builder: (_) {
                final p = _profiles[rows[i].uid];
                final me = rows[i].uid == _myUid;
                return RankRow(
                  rank: i + 1,
                  nickname: me ? '${p?.nickname ?? ''} (${lm.translate('friend_me')})' : (p?.nickname ?? lm.translate('unknown')),
                  flag: p?.flag ?? '',
                  avatar: p?.avatar ?? Avatar.fallback,
                  zone: _worldId,
                  survivalTime: rows[i].time,
                  highlighted: me,
                  accent: world.accent,
                  badge: p == null ? null : Badges.best(p.badgeKeys),
                  last: i == rows.length - 1,
                  onTap: () => _open(rows[i].uid, rows[i].time),
                );
              }),
          ]),
        ),
      if (noRecord > 0) ...[
        const SizedBox(height: 8),
        Text(lm.translate('friend_no_record').replaceAll('{n}', '$noRecord'),
            textAlign: TextAlign.center, style: AppTextStyles.text(12, color: AppColors.textDim)),
      ],
    ]);
  }
}
