import 'package:flutter/material.dart';
import 'design_system.dart';
import 'language_manager.dart';

/// 게임 방법 바텀시트 — 디자인 시스템 v2(플랫, 단색). 스테이지 공통 규칙만 담는다.
class GameGuideSheet extends StatelessWidget {
  const GameGuideSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GameGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(lm.translate('guide_rules_title'), style: AppTextStyles.display(20)),
                  const Spacer(),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    label: lm.translate('close'),
                    background: AppColors.surface2,
                    color: AppColors.textDim,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  _rule(Icons.adjust_rounded, lm.translate('guide_rule_1')),
                  _rule(Icons.directions_run_rounded, lm.translate('guide_rule_2')),
                  _rule(Icons.timer_outlined, lm.translate('guide_rule_3')),
                  const SizedBox(height: 22),
                  _section(lm.translate('guide_energy_title'), lm.translate('guide_energy_desc'), [
                    lm.translate('guide_rule_4'),
                    lm.translate('guide_rule_5'),
                  ]),
                  const SizedBox(height: 22),
                  _section(lm.translate('guide_iframe_title'), lm.translate('guide_iframe_desc'), const []),
                  const SizedBox(height: 22),
                  _section(lm.translate('guide_speed_title'), lm.translate('guide_speed_desc'), const []),
                  const SizedBox(height: 22),
                  _section(lm.translate('guide_warning_title'), lm.translate('guide_warning_desc'), const []),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.text, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(text, style: AppTextStyles.text(14, weight: FontWeight.w600, height: 1.4)),
              ),
            ),
          ],
        ),
      );

  Widget _section(String title, String desc, List<String> bullets) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label()),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, // 문구 길이와 상관없이 카드 폭을 맞춘다
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: AppTextStyles.text(13, color: AppColors.textDim, weight: FontWeight.w500, height: 1.5)),
                for (final b in bullets) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.textDim, shape: BoxShape.circle)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(b, style: AppTextStyles.text(13, weight: FontWeight.w600, height: 1.4))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}
