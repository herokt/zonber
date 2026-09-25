import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../audio_manager.dart';
import '../character_data.dart';
import '../coin_store.dart';
import '../cosmetics.dart';
import '../design_system.dart';
import '../gear.dart';
import '../haptics.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../promotions.dart';
import '../services/auth_service.dart';
import '../world_config.dart';

// ─────────────────────────────────────────────────────────────
// 이벤트 페이지 — 진행 중인 프로모션을 한 줄씩 보여 주고 그 자리에서 받는다. 규칙은 promotions.dart
//   · 한 줄 = 제목 + 설명 한 줄(왼쪽) · 버튼(오른쪽). 설명이 길면 글자를 줄여 한 줄에 맞춘다
//   · 홈 배너([PromoBanner])는 진행 중인 게 있을 때만 나오고, 누르면 이 페이지('Promo')로 온다
//   · 코드 입력칸은 아래에 붙어 있다 — 키보드가 올라오면 화면이 줄어 입력칸이 키보드 바로 위에 선다
//   · 자랑하기는 OS 공유 창(SNS·메신저)을 바로 띄우고, 공유하면 하루 한 번 보상
// 새 이벤트를 열어도 이 화면은 손댈 필요가 없다 — 목록만 늘어난다.
// ─────────────────────────────────────────────────────────────

/// 보상 한 줄 — "코인 500 · 구름 · 불꽃" (코드·이벤트 받았을 때 안내)
String rewardText(LanguageManager lm, int coins, List<String> items) => [
      if (coins > 0) lm.translate('promo_reward_coins').replaceAll('{n}', '$coins'),
      for (final id in items) _itemName(lm, id),
    ].join(' · ');

String _itemName(LanguageManager lm, String id) {
  if (id.startsWith('char_')) return CharacterData.getCharacter(id.substring(5)).name;
  final gear = Gear.byId(id);
  if (gear != null) return lm.translate(gear.nameKey);
  final cos = Cosmetics.byId(id);
  if (cos != null) return lm.translate(cos.nameKey);
  return id;
}

/// 홈 배너 — 진행 중인 이벤트가 있을 때만 한 줄. 없으면 아무것도 그리지 않는다
class PromoBanner extends StatefulWidget {
  final VoidCallback onTap;
  const PromoBanner({super.key, required this.onTap});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  List<Promotion> _live = const [];
  int _claimable = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final live = await PromoService.load();
    int n = 0;
    for (final p in live) {
      if (await PromoService.isFresh(p)) n++;
    }
    if (!mounted) return;
    setState(() {
      _live = live;
      _claimable = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_live.isEmpty) return const SizedBox.shrink();
    final lm = LanguageManager.of(context);
    final first = _live.first;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.coin.withValues(alpha: 0.22), AppColors.primary.withValues(alpha: 0.14)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.coin.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.celebration_rounded, size: 18, color: AppColors.coin),
            const SizedBox(width: 8),
            Expanded(
              child: OneLineText(
                _live.length > 1
                    ? '${first.titleOf(lm.currentLanguage)} 외 ${_live.length - 1}'
                    : first.titleOf(lm.currentLanguage),
                style: AppTextStyles.text(13, weight: FontWeight.w800),
              ),
            ),
            if (_claimable > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.coin, borderRadius: BorderRadius.circular(999)),
                child: Text(lm.translate('promo_claimable').replaceAll('{n}', '$_claimable'),
                    style: AppTextStyles.text(10.5, color: Colors.white, weight: FontWeight.w900)),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

class PromoPage extends StatefulWidget {
  final VoidCallback onBack;
  const PromoPage({super.key, required this.onBack});

  @override
  State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  List<Promotion> _live = const [];
  final Map<String, bool> _can = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    final live = await PromoService.load(refresh: refresh);
    final can = <String, bool>{};
    for (final p in live) {
      can[p.id] = await PromoService.isFresh(p);
    }
    if (!mounted) return;
    setState(() {
      _live = live;
      _can
        ..clear()
        ..addAll(can);
      _loading = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    // 아래 코드 입력칸(키보드가 뜨면 키보드 바로 위)을 덮지 않게 그 위에 띄운다
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 76),
    ));
  }

  Future<void> _claim(Promotion p) async {
    final lm = LanguageManager.of(context, listen: false);
    if (AuthService.isGuest) {
      _toast(lm.translate('guest_login_to_save'));
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await PromoService.claim(p);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _toast(lm.translate('promo_already'));
      await _load();
      return;
    }
    AudioManager().playSfx(Sfx.coin, volume: 0.8);
    Haptics.medium();
    _toast(lm.translate('promo_code_got').replaceAll('{reward}', rewardText(lm, p.coins, p.items)));
    await _load();
  }

  /// 자랑하기 — 내 최고 기록 문구로 OS 공유 창(SNS·메신저)을 띄운다. 공유하면 보상(하루 한 번).
  /// 보상을 이미 받은 날에도 공유는 된다. 공유 창을 못 띄우는 기기는 문구를 복사해 준다
  Future<void> _share(Promotion p, Rect? origin) async {
    final lm = LanguageManager.of(context, listen: false);
    final best = await ProgressStore.getBestTimes();
    final lines = <String>[];
    for (final w in WorldData.worlds) {
      final t = best[w.id];
      if (t != null && t > 0) {
        lines.add('${lm.translate('stage_n').replaceAll('{n}', '${w.difficulty}')} ${lm.translate(w.nameKey)} ${formatSurvival(t)}s');
      }
    }
    final text = LanguageManager.stripJoiners([
      lm.translate('promo_share_text'),
      if (lines.isNotEmpty) lines.join(' · '),
      lm.translate('promo_share_link'),
    ].join('\n'));
    ShareResultStatus status;
    try {
      // iPad 는 공유 창을 띄울 자리(버튼 위치)가 있어야 한다
      final r = await SharePlus.instance.share(ShareParams(text: text, subject: 'ZONBER', sharePositionOrigin: origin));
      status = r.status;
    } catch (e) {
      debugPrint('share failed: $e');
      await Clipboard.setData(ClipboardData(text: text));
      _toast(lm.translate('promo_share_copied'));
      status = ShareResultStatus.unavailable;
    }
    if (!mounted || status == ShareResultStatus.dismissed) return; // 공유 창을 닫기만 하면 보상 없음
    if (_can[p.id] ?? false) await _claim(p);
  }

  /// 코드 입력 — 검증·지급은 PromoService.redeem(서버 규칙이 1인 1회·한도·기간을 다시 본다)
  Future<void> _redeem() async {
    final lm = LanguageManager.of(context, listen: false);
    if (_code.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    final (result, pc) = await PromoService.redeem(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == RedeemResult.ok && pc != null) {
      _code.clear();
      _codeFocus.unfocus();
      AudioManager().playSfx(Sfx.coin, volume: 0.8);
      Haptics.medium();
      _toast(lm.translate('promo_code_got').replaceAll('{reward}', rewardText(lm, pc.coins, pc.items)));
      return;
    }
    _toast(lm.translate(switch (result) {
      RedeemResult.guest => 'guest_login_to_save',
      RedeemResult.already => 'promo_code_used',
      RedeemResult.disabled => 'promo_code_disabled',
      RedeemResult.notStarted => 'promo_code_not_started',
      RedeemResult.expired => 'promo_code_expired',
      RedeemResult.exhausted => 'promo_code_exhausted',
      RedeemResult.error => 'promo_code_error',
      RedeemResult.invalid || RedeemResult.ok => 'promo_code_bad',
    }));
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final lang = lm.currentLanguage;
    return NeonScaffold(
      title: lm.translate('promo_title'),
      showBackButton: true,
      onBack: widget.onBack,
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: CoinStore.balance,
          builder: (context, b, _) => CoinChip(amount: b, size: 14),
        ),
      ],
      // 목록은 남는 칸을 채우고 코드 입력칸은 맨 아래 — 키보드가 뜨면 Scaffold 가 몸통을 줄여 입력칸이 키보드 위로 올라온다
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _live.isEmpty
                    ? Center(child: Text(lm.translate('promo_none'), style: AppTextStyles.text(13, color: AppColors.textDim)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _live.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _card(lm, lang, _live[i]),
                      ),
          ),
          _codeBar(lm),
        ],
      ),
    );
  }

  /// 한 줄 — 제목(+마감 임박 D-n) · 설명 한 줄 · 오른쪽 버튼
  Widget _card(LanguageManager lm, String lang, Promotion p) {
    final can = _can[p.id] ?? false;
    final days = p.daysLeft;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: can ? AppColors.coin.withValues(alpha: 0.5) : AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.titleOf(lang),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(14, weight: FontWeight.w900)),
                    ),
                    if (days != null && days <= 7) ...[
                      const SizedBox(width: 6),
                      Text(lm.translate('promo_days_left').replaceAll('{n}', '${days < 0 ? 0 : days}'),
                          style: AppTextStyles.text(10.5, color: AppColors.secondary, weight: FontWeight.w800)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                OneLineText(p.descOf(lang), style: AppTextStyles.text(12, color: AppColors.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _button(lm, p, can),
        ],
      ),
    );
  }

  Widget _button(LanguageManager lm, Promotion p, bool can) => switch (p.kind) {
        // 코드 이벤트 — 누르면 아래 입력칸으로(키보드가 뜬다)
        PromoKind.code => _pill(lm.translate('promo_code_only'), onTap: () => _codeFocus.requestFocus(), filled: false),
        // 자랑하기 — 받은 날에도 공유는 된다(보상만 없다)
        PromoKind.share => Builder(
            builder: (b) => _pill(lm.translate('promo_share'), filled: can, onTap: () {
              final box = b.findRenderObject() as RenderBox?;
              _share(p, box == null ? null : box.localToGlobal(Offset.zero) & box.size);
            }),
          ),
        _ => can
            ? _pill(lm.translate('promo_claim'), onTap: () => _claim(p))
            : _pill(lm.translate(p.cooldownHours > 0 ? 'promo_done_today' : 'promo_claimed'), filled: false),
      };

  /// 오른쪽 버튼 — 채움(받을 게 있음) / 테두리(할 수는 있음) / 흐림(onTap 없음 = 끝남)
  Widget _pill(String label, {VoidCallback? onTap, bool filled = true}) {
    final enabled = onTap != null;
    final color = filled && enabled ? AppColors.coin : Colors.transparent;
    final textColor = filled && enabled ? Colors.white : (enabled ? AppColors.coin : AppColors.textDim);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _busy ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 68),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: enabled ? AppColors.coin : AppColors.line),
        ),
        child: Text(label, style: AppTextStyles.text(12, color: textColor, weight: FontWeight.w900)),
      ),
    );
  }

  Widget _codeBar(LanguageManager lm) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _code,
                  focusNode: _codeFocus,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: PromoCodes.maxLength + 4, // 하이픈·공백 여유
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  style: AppTextStyles.text(14, weight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: lm.translate('promo_code_hint'),
                    hintStyle: AppTextStyles.text(12.5, color: AppColors.textDim),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
                  ),
                  onSubmitted: (_) => _redeem(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            NeonButton(text: lm.translate('promo_code_ok'), isCompact: true, onPressed: _redeem),
          ],
        ),
      );
}
