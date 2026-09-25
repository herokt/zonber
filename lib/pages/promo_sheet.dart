import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio_manager.dart';
import '../coin_store.dart';
import '../design_system.dart';
import '../haptics.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../promotions.dart';
import '../services/auth_service.dart';
import '../world_config.dart';

// ─────────────────────────────────────────────────────────────
// 이벤트 창 — 진행 중인 프로모션을 한 줄씩 보여 주고 그 자리에서 받는다. 규칙은 promotions.dart
//   · 홈 배너([PromoBanner])는 진행 중인 게 있을 때만 나온다
//   · 코드 이벤트는 입력칸에 코드를 넣어 받는다
//   · 자랑하기는 내 기록 문구를 복사해 주고(친구 유입 경로) 하루 한 번 보상
// 새 이벤트를 열어도 이 화면은 손댈 필요가 없다 — 목록만 늘어난다.
// ─────────────────────────────────────────────────────────────

Future<void> showPromoSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _PromoSheet(),
    );

/// 홈 배너 — 진행 중인 이벤트가 있을 때만 한 줄. 없으면 아무것도 그리지 않는다
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

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
      onTap: () async {
        await showPromoSheet(context);
        _load();
      },
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

class _PromoSheet extends StatefulWidget {
  const _PromoSheet();

  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  final TextEditingController _code = TextEditingController();
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
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
    _toast(p.coins > 0
        ? lm.translate('reward_got').replaceAll('{n}', '${p.coins}')
        : lm.translate('promo_got_item'));
    await _load();
  }

  /// 자랑하기 — 내 최고 기록 문구를 복사해 준다(붙여넣기로 친구에게). 복사하면 보상
  Future<void> _share(Promotion p) async {
    final lm = LanguageManager.of(context, listen: false);
    final best = await ProgressStore.getBestTimes();
    final lines = <String>[];
    for (final w in WorldData.worlds) {
      final t = best[w.id];
      if (t != null && t > 0) {
        lines.add('${lm.translate('stage_n').replaceAll('{n}', '${w.difficulty}')} ${lm.translate(w.nameKey)} ${formatSurvival(t)}s');
      }
    }
    final text = [
      lm.translate('promo_share_text'),
      if (lines.isNotEmpty) lines.join(' · '),
      lm.translate('promo_share_link'),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _toast(lm.translate('promo_share_copied'));
    await _claim(p);
  }

  Future<void> _redeem() async {
    final lm = LanguageManager.of(context, listen: false);
    final input = _code.text.trim();
    if (input.isEmpty) return;
    final p = await PromoService.byCode(input);
    if (!mounted) return;
    if (p == null) {
      _toast(lm.translate('promo_code_bad'));
      return;
    }
    if (!(await PromoService.isFresh(p))) {
      if (!mounted) return;
      _toast(lm.translate('promo_already'));
      return;
    }
    _code.clear();
    if (!mounted) return;
    await _claim(p);
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final lang = lm.currentLanguage;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.celebration_rounded, size: 18, color: AppColors.coin),
                const SizedBox(width: 6),
                Text(lm.translate('promo_title'), style: AppTextStyles.text(16, weight: FontWeight.w900)),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: CoinStore.balance,
                  builder: (context, b, _) => CoinChip(amount: b, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator()))
            else if (_live.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                    child: Text(lm.translate('promo_none'), style: AppTextStyles.text(13, color: AppColors.textDim))),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final p in _live) ...[_card(lm, lang, p), const SizedBox(height: 8)],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            _codeBox(lm),
          ],
        ),
      ),
    );
  }

  Widget _card(LanguageManager lm, String lang, Promotion p) {
    final can = _can[p.id] ?? false;
    final days = p.daysLeft;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: can ? AppColors.coin.withValues(alpha: 0.5) : AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.coin.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(_icon(p.kind), size: 20, color: AppColors.coin),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.titleOf(lang),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(13.5, weight: FontWeight.w900)),
                    ),
                    if (days != null && days <= 7) ...[
                      const SizedBox(width: 6),
                      Text(lm.translate('promo_days_left').replaceAll('{n}', '${days < 0 ? 0 : days}'),
                          style: AppTextStyles.text(10.5, color: AppColors.secondary, weight: FontWeight.w800)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(p.descOf(lang),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(11.5, color: AppColors.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _button(lm, p, can),
        ],
      ),
    );
  }

  Widget _button(LanguageManager lm, Promotion p, bool can) {
    final label = switch (p.kind) {
      PromoKind.code => lm.translate('promo_code_only'),
      PromoKind.share => lm.translate('promo_share'),
      _ => lm.translate('promo_claim'),
    };
    if (p.kind == PromoKind.code) {
      return Text(label, style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w800));
    }
    if (!can) {
      return Text(lm.translate(p.cooldownHours > 0 ? 'promo_done_today' : 'promo_claimed'),
          style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w800));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _busy ? null : () => p.kind == PromoKind.share ? _share(p) : _claim(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.coin, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: AppTextStyles.text(12, color: Colors.white, weight: FontWeight.w900)),
      ),
    );
  }

  Widget _codeBox(LanguageManager lm) => Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
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
      );

  IconData _icon(PromoKind k) => switch (k) {
        PromoKind.welcome => Icons.card_giftcard_rounded,
        PromoKind.code => Icons.confirmation_number_rounded,
        PromoKind.share => Icons.ios_share_rounded,
        PromoKind.bonus => Icons.local_activity_rounded,
      };
}
