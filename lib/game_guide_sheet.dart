import 'package:flutter/material.dart';
import 'design_system.dart';
import 'language_manager.dart';
import 'powerup_system.dart';

class GameGuideSheet extends StatefulWidget {
  final int initialTab;
  const GameGuideSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int tab = 0}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameGuideSheet(initialTab: tab),
    );
  }

  @override
  State<GameGuideSheet> createState() => _GameGuideSheetState();
}

class _GameGuideSheetState extends State<GameGuideSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDim.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.55)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textDim,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontFamily: 'Orbitron',
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontFamily: 'Orbitron',
                  ),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: lm.translate('guide_rules_title')),
                    Tab(text: lm.translate('guide_items_title')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _RulesTab(scrollController: controller),
                  _ItemsTab(scrollController: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rules tab ──────────────────────────────────────────────────

class _RulesTab extends StatelessWidget {
  final ScrollController scrollController;
  const _RulesTab({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _SectionLabel('OBJECTIVE'),
        const SizedBox(height: 12),
        _RuleRow(icon: Icons.adjust_rounded, color: AppColors.primary, text: lm.translate('guide_rule_1')),
        _RuleRow(icon: Icons.radio_button_unchecked, color: AppColors.secondary, text: lm.translate('guide_rule_2')),
        _RuleRow(icon: Icons.timer_outlined, color: const Color(0xFFFFD700), text: lm.translate('guide_rule_3')),
        const SizedBox(height: 28),
        _SectionLabel(lm.translate('guide_energy_title')),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFFF4081),
          desc: lm.translate('guide_energy_desc'),
        ),
        const SizedBox(height: 10),
        _RuleRow(icon: Icons.warning_amber_rounded, color: const Color(0xFFFF8F00), text: lm.translate('guide_rule_4')),
        _RuleRow(icon: Icons.close_rounded, color: AppColors.secondary, text: lm.translate('guide_rule_5')),
        const SizedBox(height: 28),
        _SectionLabel(lm.translate('guide_iframe_title')),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.shield_moon_outlined,
          color: const Color(0xFF69F0AE),
          desc: lm.translate('guide_iframe_desc'),
        ),
        const SizedBox(height: 28),
        _SectionLabel(lm.translate('guide_speed_title')),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.touch_app_outlined,
          color: AppColors.primary,
          desc: lm.translate('guide_speed_desc'),
        ),
        const SizedBox(height: 28),
        _SectionLabel(lm.translate('guide_warning_title')),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.priority_high_rounded,
          color: AppColors.secondary,
          desc: lm.translate('guide_warning_desc'),
        ),
      ],
    );
  }
}

// ── Items tab ──────────────────────────────────────────────────

class _ItemsTab extends StatelessWidget {
  final ScrollController scrollController;
  const _ItemsTab({required this.scrollController});

  static const _icons = {
    PowerUpType.speedBoost: Icons.flash_on_rounded,
    PowerUpType.shield: Icons.favorite_rounded,
    PowerUpType.bulletClear: Icons.blur_on_rounded,
    PowerUpType.slowTime: Icons.hourglass_bottom_rounded,
  };

  static const _descKeys = {
    PowerUpType.speedBoost: 'powerup_speed_desc',
    PowerUpType.shield: 'powerup_shield_desc',
    PowerUpType.bulletClear: 'powerup_clear_desc',
    PowerUpType.slowTime: 'powerup_slow_desc',
  };

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          lm.translate('guide_items_intro'),
          style: const TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        ...PowerUpType.values.map((type) {
          final def = PowerUpDef.all[type]!;
          final icon = _icons[type]!;
          final descKey = _descKeys[type]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ItemCard(
              icon: icon,
              def: def,
              name: lm.translate(def.nameKey),
              desc: lm.translate(descKey),
            ),
          );
        }),
        const SizedBox(height: 16),
        _SectionLabel(lm.translate('guide_active_title')),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.donut_large_rounded,
          color: const Color(0xFFFFD700),
          desc: lm.translate('guide_active_desc'),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final IconData icon;
  final PowerUpDef def;
  final String name;
  final String desc;
  const _ItemCard({required this.icon, required this.def, required this.name, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: def.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: def.color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: def.color.withValues(alpha: 0.15),
              border: Border.all(color: def.color.withValues(alpha: 0.6), width: 2),
              boxShadow: [BoxShadow(color: def.color.withValues(alpha: 0.3), blurRadius: 12)],
            ),
            child: Icon(icon, color: def.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: def.color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const Spacer(),
                    if (def.duration > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: def.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: def.color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${def.duration.toInt()}s',
                          style: TextStyle(
                            color: def.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.5,
          fontFamily: 'Orbitron',
        ),
      );
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _RuleRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String desc;
  const _StatCard({required this.icon, required this.color, required this.desc});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                desc,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      );
}
