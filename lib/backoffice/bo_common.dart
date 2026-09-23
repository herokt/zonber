import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../badges.dart';
import 'bo_catalog.dart';
import 'bo_data.dart';

export '../badges.dart' show BadgeDef, BadgeCategory, Badges;
export 'bo_catalog.dart';
export 'bo_data.dart';

// ─────────────────────────────────────────────────────────────
// 백오피스 공통 UI — 색·글자 토큰(Bo)과 컴포넌트(BoCard, BoKpi, BoTable, BoToolbar, BoBadge, BoSectionHeader,
// BoEmpty, BoError, BoTopBar …). 화면들은 여기 것만 써서 스타일을 맞춘다. 밝은/어두운 테마 · 데스크톱 우선.
// ─────────────────────────────────────────────────────────────

/// 색 한 벌(밝은/어두운)
class BoPalette {
  final Color bg, surface, surface2, subtle, hover, line, lineSoft;
  final Color text, text2, text3;
  final Color accent, accentSoft, accentMuted;
  final Color green, red, amber, blue, purple, teal, coin, grey;
  final Color track, segBg, hoverStrong;
  final Color dangerSoft, dangerBorder, warnSoft, warnBorder, warnText;
  final Color shadow, onAccent;
  const BoPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.subtle,
    required this.hover,
    required this.line,
    required this.lineSoft,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentSoft,
    required this.accentMuted,
    required this.green,
    required this.red,
    required this.amber,
    required this.blue,
    required this.purple,
    required this.teal,
    required this.coin,
    required this.grey,
    required this.track,
    required this.segBg,
    required this.hoverStrong,
    required this.dangerSoft,
    required this.dangerBorder,
    required this.warnSoft,
    required this.warnBorder,
    required this.warnText,
    required this.shadow,
    required this.onAccent,
  });

  static const light = BoPalette(
    bg: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFFFFF),
    subtle: Color(0xFFF9FAFB),
    hover: Color(0xFFF5F7FF),
    line: Color(0xFFE5E7EB),
    lineSoft: Color(0xFFF0F1F3),
    text: Color(0xFF111827),
    text2: Color(0xFF4B5563),
    text3: Color(0xFF9CA3AF),
    accent: Color(0xFF4F46E5),
    accentSoft: Color(0xFFEEF2FF),
    accentMuted: Color(0xFFC7D2FE),
    green: Color(0xFF16A34A),
    red: Color(0xFFDC2626),
    amber: Color(0xFFD97706),
    blue: Color(0xFF2563EB),
    purple: Color(0xFF7C3AED),
    teal: Color(0xFF0D9488),
    coin: Color(0xFFB45309),
    grey: Color(0xFF6B7280),
    track: Color(0xFFF1F2F5),
    segBg: Color(0xFFF1F2F5),
    hoverStrong: Color(0xFFF3F4F6),
    dangerSoft: Color(0xFFFEF2F2),
    dangerBorder: Color(0xFFFECACA),
    warnSoft: Color(0xFFFFFBEB),
    warnBorder: Color(0xFFFDE68A),
    warnText: Color(0xFF92400E),
    shadow: Color(0x0A111827),
    onAccent: Color(0xFFFFFFFF),
  );

  static const dark = BoPalette(
    bg: Color(0xFF0F1115),
    surface: Color(0xFF171A21),
    surface2: Color(0xFF1E222B),
    subtle: Color(0xFF1B1F27),
    hover: Color(0xFF222838),
    line: Color(0xFF2A2F3A),
    lineSoft: Color(0xFF222630),
    text: Color(0xFFE6E8EC),
    text2: Color(0xFF9AA3B2),
    text3: Color(0xFF6B7384),
    accent: Color(0xFF818CF8),
    accentSoft: Color(0xFF252A4A),
    accentMuted: Color(0xFF3F4677),
    green: Color(0xFF4ADE80),
    red: Color(0xFFF87171),
    amber: Color(0xFFFBBF24),
    blue: Color(0xFF60A5FA),
    purple: Color(0xFFA78BFA),
    teal: Color(0xFF2DD4BF),
    coin: Color(0xFFF5B454),
    grey: Color(0xFF9AA3B2),
    track: Color(0xFF262B36),
    segBg: Color(0xFF12151B),
    hoverStrong: Color(0xFF232833),
    dangerSoft: Color(0xFF2A1618),
    dangerBorder: Color(0xFF5B2328),
    warnSoft: Color(0xFF2A2214),
    warnBorder: Color(0xFF5C4718),
    warnText: Color(0xFFFCD34D),
    shadow: Color(0x40000000),
    onAccent: Color(0xFF0F1115),
  );
}

/// 색·글자 토큰 — 현재 테마(BoTheme)의 팔레트를 읽는다. 값이 테마에 따라 바뀌므로 const 로 쓰지 않는다.
class Bo {
  static BoPalette p = BoPalette.light;
  static bool get isDark => identical(p, BoPalette.dark);

  // 바탕·선
  static Color get bg => p.bg;
  static Color get surface => p.surface;
  static Color get surface2 => p.surface2;
  static Color get subtle => p.subtle;
  static Color get hover => p.hover;
  static Color get line => p.line;
  static Color get lineSoft => p.lineSoft;
  // 글자
  static Color get text => p.text;
  static Color get text2 => p.text2;
  static Color get text3 => p.text3;
  // 강조·상태
  static Color get accent => p.accent;
  static Color get accentSoft => p.accentSoft;
  static Color get accentMuted => p.accentMuted;
  static Color get green => p.green;
  static Color get red => p.red;
  static Color get amber => p.amber;
  static Color get blue => p.blue;
  static Color get purple => p.purple;
  static Color get teal => p.teal;
  static Color get coin => p.coin;
  static Color get grey => p.grey;
  static Color get track => p.track;
  static Color get segBg => p.segBg;
  static Color get hoverStrong => p.hoverStrong;
  static Color get dangerSoft => p.dangerSoft;
  static Color get dangerBorder => p.dangerBorder;
  static Color get warnSoft => p.warnSoft;
  static Color get warnBorder => p.warnBorder;
  static Color get warnText => p.warnText;
  static Color get onAccent => p.onAccent;

  /// 게임 색(등급·캐릭터 등)을 글자로 쓸 때 — 밝은 테마는 어둡게, 어두운 테마는 밝게
  static Color ink(Color c, [double t = 0.3]) => Color.lerp(c, isDark ? Colors.white : Colors.black, t)!;

  static const radius = 10.0;
  static const gap = 16.0;

  static const tabular = [FontFeature.tabularFigures()];

  static TextStyle get h1 => TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text, height: 1.25, letterSpacing: -0.2);
  static TextStyle get h2 => TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: text, height: 1.3);
  static TextStyle get body => TextStyle(fontSize: 13, color: text, height: 1.35);
  static TextStyle get cell => TextStyle(fontSize: 13, color: text, fontFeatures: tabular, height: 1.3);
  static TextStyle get cellStrong => TextStyle(fontSize: 13, color: text, fontWeight: FontWeight.w600, fontFeatures: tabular);
  static TextStyle get muted => TextStyle(fontSize: 12, color: text2, fontFeatures: tabular, height: 1.35);
  static TextStyle get caption => TextStyle(fontSize: 11.5, color: text3, fontFeatures: tabular, height: 1.3);
  static TextStyle get th => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text2, letterSpacing: 0.1);
  static TextStyle get mono => TextStyle(fontSize: 12, color: text2, fontFamily: 'monospace', fontFeatures: tabular);

  static List<BoxShadow> get shadow => [BoxShadow(color: p.shadow, blurRadius: 2, offset: const Offset(0, 1))];

  static Color providerColor(String p) => switch (p) {
        'Google' => blue,
        'Apple' => text,
        'Email' => purple,
        _ => amber,
      };
}

// ─────────────────────────────────────────────────────────────
// 테마 모드 — 기본은 시스템 설정. 상단 바 해/달 버튼으로 바꾸면 기기에 기억한다(shared_preferences = 웹 localStorage)
// ─────────────────────────────────────────────────────────────
class BoTheme {
  static const _key = 'bo_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// 저장된 선택을 읽는다(실패하면 시스템 따름)
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      mode.value = v == 'dark' ? ThemeMode.dark : (v == 'light' ? ThemeMode.light : ThemeMode.system);
    } catch (e) {
      debugPrint('BoTheme.load: $e');
    }
  }

  static bool resolveDark(Brightness platform) =>
      mode.value == ThemeMode.dark || (mode.value == ThemeMode.system && platform == Brightness.dark);

  /// 지금 보이는 것과 반대로 바꾸고 기억한다
  static Future<void> toggle() async {
    mode.value = Bo.isDark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.value == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('BoTheme.save: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 앱 테마
// ─────────────────────────────────────────────────────────────
ThemeData boTheme() {
  final dark = Bo.isDark;
  final scheme =
      ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: dark ? Brightness.dark : Brightness.light).copyWith(
    primary: Bo.accent,
    onPrimary: Bo.onAccent,
    surface: Bo.surface,
    onSurface: Bo.text,
    onSurfaceVariant: Bo.text2,
    error: Bo.red,
    outline: Bo.line,
    outlineVariant: Bo.line,
    surfaceContainerHighest: Bo.subtle,
    surfaceContainerHigh: Bo.surface2,
    surfaceContainer: Bo.surface2,
    surfaceContainerLow: Bo.surface,
    surfaceContainerLowest: Bo.surface,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Bo.bg,
    canvasColor: Bo.surface2,
    dividerColor: Bo.line,
    dividerTheme: DividerThemeData(color: Bo.line, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: Bo.text2),
    visualDensity: VisualDensity.compact,
    splashFactory: InkRipple.splashFactory,
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(Bo.text3.withValues(alpha: 0.5))),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? Bo.surface2 : Bo.text.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: dark ? Border.all(color: Bo.line) : null,
      ),
      textStyle: TextStyle(color: dark ? Bo.text : Bo.surface, fontSize: 12),
      waitDuration: const Duration(milliseconds: 300),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Bo.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), side: dark ? BorderSide(color: Bo.line) : BorderSide.none),
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Bo.text),
      contentTextStyle: Bo.body,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Bo.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Bo.line)),
      textStyle: Bo.body,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: Bo.accent, selectionColor: Bo.accent.withValues(alpha: 0.3)),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: dark ? Bo.subtle : Bo.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Bo.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Bo.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Bo.accent, width: 1.5)),
      hintStyle: TextStyle(fontSize: 13, color: Bo.text3),
      labelStyle: TextStyle(fontSize: 13, color: Bo.text2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        backgroundColor: Bo.accent,
        foregroundColor: Bo.onAccent,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        foregroundColor: Bo.text,
        side: BorderSide(color: Bo.line),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          shape: rounded, foregroundColor: Bo.accent, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(Bo.line),
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Bo.onAccent : Bo.text3),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Bo.accent : Bo.track),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Bo.accent,
      unselectedLabelColor: Bo.text2,
      indicatorColor: Bo.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Bo.line,
      labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: Bo.accent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Bo.surface2 : Bo.text,
      contentTextStyle: TextStyle(color: dark ? Bo.text : Bo.surface, fontSize: 13),
      width: 420,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), side: dark ? BorderSide(color: Bo.line) : BorderSide.none),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// 카드 · 섹션 헤더
// ─────────────────────────────────────────────────────────────
class BoSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;
  const BoSectionHeader(this.title,
      {super.key, this.subtitle, this.trailing, this.padding = const EdgeInsets.fromLTRB(16, 14, 12, 12)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Bo.h2, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: Bo.caption)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 흰 카드 — title 이 있으면 헤더를 달고, body 는 padding 안에 둔다
class BoCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final bool divider;
  final bool fill; // true: child 를 Expanded 로(높이 꽉 채우는 표 등)
  const BoCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.divider = false,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: Bo.surface,
        borderRadius: BorderRadius.circular(Bo.radius),
        border: Border.all(color: Bo.line),
        boxShadow: Bo.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) BoSectionHeader(title!, subtitle: subtitle, trailing: trailing),
          if (title != null && divider) const Divider(),
          if (fill) Expanded(child: body) else body,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KPI
// ─────────────────────────────────────────────────────────────
class BoKpi extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color? _color;
  Color get color => _color ?? Bo.accent;

  /// 이전 기간 대비 변화율(0.12 = +12%). null 이면 표시 안 함
  final double? delta;
  final String? deltaLabel;
  const BoKpi({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    Color? color,
    this.delta,
    this.deltaLabel,
  }) : _color = color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Bo.surface,
        borderRadius: BorderRadius.circular(Bo.radius),
        border: Border.all(color: Bo.line),
        boxShadow: Bo.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: Bo.muted, overflow: TextOverflow.ellipsis)),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                child: Icon(icon, size: 15, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: Bo.text, fontFeatures: Bo.tabular, letterSpacing: -0.3)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (delta != null) ...[
                _DeltaPill(delta!),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  delta != null ? (deltaLabel ?? '') : (sub ?? ''),
                  style: Bo.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (delta != null && sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub!, style: Bo.caption, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double delta;
  const _DeltaPill(this.delta);

  @override
  Widget build(BuildContext context) {
    final up = delta > 0.0005, down = delta < -0.0005;
    final c = up ? Bo.green : (down ? Bo.red : Bo.grey);
    final pct = (delta.abs() * 100);
    final txt = pct >= 999 ? '999%+' : '${pct.toStringAsFixed(pct < 10 ? 1 : 0)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : (down ? Icons.arrow_downward_rounded : Icons.remove_rounded), size: 11, color: c),
        const SizedBox(width: 2),
        Text(txt, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c, fontFeatures: Bo.tabular)),
      ]),
    );
  }
}

/// 변화율 — 이전 값이 0 이면 null(표시 안 함)
double? deltaOf(num now, num prev) => prev <= 0 ? null : (now - prev) / prev;

/// 같은 너비로 나눠 까는 격자(KPI 줄·차트 카드). minItemWidth 보다 좁아지면 줄 수가 는다
class BoGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final bool stretch; // 한 줄 안 카드 높이를 맞춘다(IntrinsicHeight — LayoutBuilder 가 든 자식에는 끈다)
  const BoGrid(
      {super.key, required this.children, this.minItemWidth = 180, this.maxColumns = 6, this.spacing = Bo.gap, this.stretch = true});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var cols = ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor().clamp(1, maxColumns);
      if (cols > children.length) cols = children.length;
      if (cols < 1) cols = 1;
      // 마지막 줄에 하나만 남지 않게 줄마다 고르게 나눈다(6개·5칸 → 3칸 × 2줄)
      final rowsNeeded = (children.length + cols - 1) ~/ cols;
      cols = (children.length + rowsNeeded - 1) ~/ rowsNeeded;
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      final rows = <Widget>[];
      for (int i = 0; i < children.length; i += cols) {
        final slice = children.sublist(i, (i + cols).clamp(0, children.length));
        final row = Row(
          crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          children: [
            for (int k = 0; k < cols; k++) ...[
              if (k > 0) SizedBox(width: spacing),
              SizedBox(width: w, child: k < slice.length ? slice[k] : const SizedBox()),
            ],
          ],
        );
        rows.add(stretch ? IntrinsicHeight(child: row) : row);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < rows.length; i++) ...[if (i > 0) SizedBox(height: spacing), rows[i]],
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// 배지(pill) · 캐릭터 점 · 뱃지 아이콘
// ─────────────────────────────────────────────────────────────
class BoBadge extends StatelessWidget {
  final String text;
  final Color? _color;
  final IconData? icon;
  final bool dense;
  const BoBadge(this.text, {super.key, Color? color, this.icon, this.dense = false}) : _color = color;
  Color get color => _color ?? Bo.grey;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 1 : 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
            Flexible(
              child: Text(text,
                  style: TextStyle(fontSize: dense ? 11 : 11.5, color: color, fontWeight: FontWeight.w600, height: 1.3),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class BoProviderBadge extends StatelessWidget {
  final String provider;
  const BoProviderBadge(this.provider, {super.key});

  @override
  Widget build(BuildContext context) => BoBadge(providerLabel(provider), color: Bo.providerColor(provider), dense: true);
}

class CharDot extends StatelessWidget {
  final String? charId;
  final double size;
  const CharDot(this.charId, {super.key, this.size = 10});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: charName(charId),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: charColor(charId),
            shape: BoxShape.circle,
            border: Border.all(color: Bo.line),
          ),
        ),
      );
}

/// 캐릭터 색 원 + 닉네임 첫 글자
class BoAvatar extends StatelessWidget {
  final String? charId;
  final String name;
  final double size;
  const BoAvatar({super.key, required this.charId, required this.name, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final c = charColor(charId);
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c, Colors.white, 0.15)!, Color.lerp(c, Colors.black, 0.12)!],
        ),
        border: Border.all(color: Bo.surface, width: 3),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(letter, style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w700)),
    );
  }
}

/// 뱃지 아이콘 — 등급 색 원. earned=false 면 회색
class BoBadgeIcon extends StatelessWidget {
  final BadgeDef badge;
  final double size;
  final bool earned;
  final bool tooltip;
  const BoBadgeIcon(this.badge, {super.key, this.size = 18, this.earned = true, this.tooltip = true});

  @override
  Widget build(BuildContext context) {
    final c = earned ? badge.color : Bo.line;
    final w = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? c.withValues(alpha: 0.16) : Bo.subtle,
        border: Border.all(color: c.withValues(alpha: earned ? 0.9 : 1), width: size >= 28 ? 1.6 : 1.2),
      ),
      child: Icon(badge.icon, size: size * 0.58, color: earned ? Bo.ink(c, 0.25) : Bo.text3),
    );
    if (!tooltip) return w;
    return Tooltip(message: '${badgeName(badge.key)} · ${tierName(badge.tier)}', child: w);
  }
}

// ─────────────────────────────────────────────────────────────
// 툴바 · 입력
// ─────────────────────────────────────────────────────────────
/// 표 위 필터 줄 — 왼쪽 children(검색·필터), 오른쪽 trailing
class BoToolbar extends StatelessWidget {
  final List<Widget> filters;
  final List<Widget> trailing;
  const BoToolbar({super.key, required this.filters, this.trailing = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: filters,
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 10),
            Row(mainAxisSize: MainAxisSize.min, children: trailing),
          ],
        ],
      ),
    );
  }
}

class BoSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;
  const BoSearchField({super.key, required this.controller, required this.hint, required this.onChanged, this.width = 280});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 34,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: Bo.body,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: Bo.text3),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: Bo.text3),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// 세그먼트 버튼(한 개 선택)
class BoSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const BoSegmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Bo.segBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Bo.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            _SegItem(label: o.$2, selected: o.$1 == value, onTap: () => onChanged(o.$1)),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegItem({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Bo.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: Bo.isDark ? 0.4 : 0.08), blurRadius: 2, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Bo.text : Bo.text2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 테두리 있는 작은 드롭다운 — "라벨: 값"
class BoDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  const BoDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cur = items.where((e) => e.$1 == value).map((e) => e.$2).firstOrNull ?? '';
    return PopupMenuButton<T>(
      tooltip: label,
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 180, maxHeight: 420),
      itemBuilder: (_) => [
        for (final e in items) PopupMenuItem<T>(value: e.$1, height: 36, child: Text(e.$2, style: Bo.body)),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: Bo.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Bo.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label ', style: Bo.muted),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(cur, style: Bo.body.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: Bo.text3),
          ],
        ),
      ),
    );
  }
}

/// 켜고 끄는 작은 스위치 + 라벨
class BoToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const BoToggle({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 4, right: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Transform.scale(
            scale: 0.7,
            child: Switch(value: value, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
          Text(label, style: Bo.body),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 표
// ─────────────────────────────────────────────────────────────
class BoCol {
  final String label;
  final double? width; // 고정 너비
  final int flex; // width 가 없을 때
  final double minWidth; // flex 칸의 최소 너비(좁으면 가로 스크롤)
  final bool numeric;
  final bool sortable;
  final String? tooltip;
  const BoCol(this.label,
      {this.width, this.flex = 1, this.minWidth = 90, this.numeric = false, this.sortable = false, this.tooltip});

  double get min => width ?? minWidth;
}

/// 데이터 표 — 헤더 고정, 40px 행, 호버, 숫자 오른쪽 정렬, 헤더 클릭 정렬.
/// scroll=true 면 부모 높이를 채우고 행만 스크롤(가상화). false 면 행 수만큼 늘어난다.
class BoTable extends StatelessWidget {
  final List<BoCol> columns;
  final int rowCount;
  final List<Widget> Function(int i) cells;
  final void Function(int i)? onRowTap;
  final Color? Function(int i)? rowTint;
  final int? sortColumn;
  final bool sortAsc;
  final void Function(int col)? onSort;
  final bool scroll;
  final Widget? footer;
  final Widget? empty;
  final double rowHeight;
  const BoTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.cells,
    this.onRowTap,
    this.rowTint,
    this.sortColumn,
    this.sortAsc = false,
    this.onSort,
    this.scroll = false,
    this.footer,
    this.empty,
    this.rowHeight = 40,
  });

  static const double _hpad = 12;

  /// 한 줄 글자 칸
  static Widget text(String s, {TextStyle? style, Color? color, String? tooltip}) {
    final st = style ?? Bo.cell;
    final t = Text(s, style: color == null ? st : st.copyWith(color: color), overflow: TextOverflow.ellipsis, maxLines: 1);
    return (tooltip == null || tooltip.isEmpty) ? t : Tooltip(message: tooltip, child: t);
  }

  double get _minWidth => columns.fold<double>(0, (a, c) => a + c.min) + _hpad * 2;

  Widget _cellBox(BoCol c, Widget child) {
    final aligned = Align(alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child);
    final padded = Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: aligned);
    return c.width != null ? SizedBox(width: c.width, child: padded) : Expanded(flex: c.flex, child: padded);
  }

  Widget _header() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: _hpad),
      decoration: BoxDecoration(color: Bo.subtle, border: Border(bottom: BorderSide(color: Bo.line))),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++) _cellBox(columns[i], _headerLabel(i)),
        ],
      ),
    );
  }

  Widget _headerLabel(int i) {
    final c = columns[i];
    final active = sortColumn == i;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(c.label, style: active ? Bo.th.copyWith(color: Bo.text) : Bo.th, overflow: TextOverflow.ellipsis)),
        if (c.sortable) ...[
          const SizedBox(width: 2),
          Icon(
            active ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
            size: 13,
            color: active ? Bo.accent : Bo.text3,
          ),
        ],
      ],
    );
    Widget w = label;
    if (c.tooltip != null) w = Tooltip(message: c.tooltip!, child: w);
    if (!c.sortable || onSort == null) return w;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onSort!(i), child: w),
    );
  }

  Widget _row(int i) {
    final cs = cells(i);
    return _BoTableRow(
      height: rowHeight,
      tint: rowTint?.call(i),
      onTap: onRowTap == null ? null : () => onRowTap!(i),
      child: Row(children: [for (int k = 0; k < columns.length; k++) _cellBox(columns[k], cs[k])]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final minW = _minWidth;
      final tooNarrow = c.maxWidth.isFinite && c.maxWidth < minW;
      // 머리줄 + 행 (footer 는 가로 스크롤 밖에 둔다)
      Widget grid;
      if (scroll) {
        grid = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Expanded(
              child: rowCount == 0
                  ? (empty ?? const BoEmpty('데이터가 없습니다'))
                  : ListView.builder(itemCount: rowCount, itemExtent: rowHeight, itemBuilder: (_, i) => _row(i)),
            ),
          ],
        );
      } else {
        grid = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            if (rowCount == 0) empty ?? const BoEmpty('데이터가 없습니다'),
            for (int i = 0; i < rowCount; i++) _row(i),
          ],
        );
      }
      if (tooNarrow) {
        grid = Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minW, child: grid),
          ),
        );
      }
      return Column(
        mainAxisSize: scroll ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scroll) Expanded(child: grid) else grid,
          ?footer,
        ],
      );
    });
  }
}

class _BoTableRow extends StatefulWidget {
  final double height;
  final Color? tint;
  final VoidCallback? onTap;
  final Widget child;
  const _BoTableRow({required this.height, this.tint, this.onTap, required this.child});

  @override
  State<_BoTableRow> createState() => _BoTableRowState();
}

class _BoTableRowState extends State<_BoTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover ? (widget.tint != null ? Color.lerp(widget.tint, Bo.hover, 0.4)! : Bo.hover) : (widget.tint ?? Colors.transparent);
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: BoTable._hpad),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: Bo.lineSoft))),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 표 아래 줄 — 왼쪽 요약 글자, 오른쪽 버튼(더 보기·페이지)
class BoTableFooter extends StatelessWidget {
  final String text;
  final List<Widget> actions;
  const BoTableFooter({super.key, required this.text, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Bo.surface, border: Border(top: BorderSide(color: Bo.line))),
      child: Row(children: [
        Expanded(child: Text(text, style: Bo.muted, overflow: TextOverflow.ellipsis)),
        ...actions,
      ]),
    );
  }
}

/// 페이지 넘김 — "1–50 / 1,234" + 이전·다음
class BoPager extends StatelessWidget {
  final int total;
  final int page; // 0부터
  final int pageSize;
  final ValueChanged<int> onPage;
  final String unit;
  const BoPager({super.key, required this.total, required this.page, required this.pageSize, required this.onPage, this.unit = '건'});

  int get pages => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, total);
    return BoTableFooter(
      text: '${fmtNum(from)}–${fmtNum(to)} / 전체 ${fmtNum(total)}$unit',
      actions: [
        Text('${page + 1} / $pages 페이지', style: Bo.muted),
        const SizedBox(width: 8),
        _pagerBtn(Icons.first_page_rounded, page > 0 ? () => onPage(0) : null),
        _pagerBtn(Icons.chevron_left_rounded, page > 0 ? () => onPage(page - 1) : null),
        _pagerBtn(Icons.chevron_right_rounded, page < pages - 1 ? () => onPage(page + 1) : null),
        _pagerBtn(Icons.last_page_rounded, page < pages - 1 ? () => onPage(pages - 1) : null),
      ],
    );
  }

  Widget _pagerBtn(IconData icon, VoidCallback? onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: Bo.text2,
        disabledColor: Bo.line,
        visualDensity: VisualDensity.compact,
        splashRadius: 16,
      );
}

// ─────────────────────────────────────────────────────────────
// 상태 표시 — 비어 있음 · 오류 · 불러오는 중
// ─────────────────────────────────────────────────────────────
class BoEmpty extends StatelessWidget {
  final String text;
  final IconData icon;
  final double padding;
  const BoEmpty(this.text, {super.key, this.icon = Icons.inbox_outlined, this.padding = 28});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(padding),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 26, color: Bo.text3),
            const SizedBox(height: 6),
            Text(text, style: Bo.muted.copyWith(color: Bo.text3), textAlign: TextAlign.center),
          ]),
        ),
      );
}

class BoError extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const BoError({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final msg = error.toString();
    final needsIndex = msg.contains('index') || msg.contains('FAILED_PRECONDITION');
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Bo.dangerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Bo.dangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.error_outline_rounded, color: Bo.red, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text('불러오기 실패', style: TextStyle(color: Bo.red, fontWeight: FontWeight.w700, fontSize: 13))),
            if (onRetry != null)
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('다시 시도')),
          ]),
          if (needsIndex)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Firestore 색인이 필요합니다. firestore.indexes.json 을 배포(firebase deploy --only firestore:indexes)하거나 아래 링크로 색인을 만드세요.',
                style: TextStyle(color: Bo.text2, fontSize: 12),
              ),
            ),
          const SizedBox(height: 6),
          SelectableText(msg, style: TextStyle(color: Bo.text2, fontSize: 12)),
        ],
      ),
    );
  }
}

class BoLoading extends StatelessWidget {
  final double padding;
  const BoLoading({super.key, this.padding = 32});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(padding),
        child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
}

// ─────────────────────────────────────────────────────────────
// 가로 막대 한 줄 · 키-값 한 줄
// ─────────────────────────────────────────────────────────────
class BoHBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String valueText;
  final Color? _color;
  Color get color => _color ?? Bo.accent;
  final double labelWidth;
  final double valueWidth;
  final Widget? leading;
  final String? tooltip;
  const BoHBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.valueText,
    Color? color,
    this.labelWidth = 130,
    this.valueWidth = 80,
    this.leading,
    this.tooltip,
  }) : _color = color;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final row = SizedBox(
      height: 28,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          SizedBox(width: labelWidth, child: Text(label, style: Bo.body, overflow: TextOverflow.ellipsis)),
          Expanded(child: BoBarTrack(ratio: ratio, color: color)),
          SizedBox(
            width: valueWidth,
            child: Text(valueText, textAlign: TextAlign.right, style: Bo.cellStrong, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
    return tooltip == null ? row : Tooltip(message: tooltip!, child: row);
  }
}

/// 얇은 진행 막대
class BoBarTrack extends StatelessWidget {
  final double ratio;
  final Color? _color;
  final double height;
  const BoBarTrack({super.key, required this.ratio, Color? color, this.height = 8}) : _color = color;
  Color get color => _color ?? Bo.accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: Bo.track, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: ratio.clamp(0.0, 1.0),
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
      ),
    );
  }
}

class BoKv extends StatelessWidget {
  final String k;
  final String? v;
  final Widget? child;
  final bool mono;
  final bool copy;
  final String? note;
  final double keyWidth;
  const BoKv(this.k, {super.key, this.v, this.child, this.mono = false, this.copy = false, this.note, this.keyWidth = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Bo.lineSoft))),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: keyWidth, child: Text(k, style: Bo.muted)),
          Expanded(
            child: child ??
                Row(children: [
                  Flexible(child: SelectableText(v ?? '-', style: mono ? Bo.mono.copyWith(color: Bo.text) : Bo.cell)),
                  if (note != null) Padding(padding: const EdgeInsets.only(left: 6), child: BoBadge(note!, dense: true)),
                  if (copy && (v ?? '').isNotEmpty) BoCopyButton(v!),
                ]),
          ),
        ],
      ),
    );
  }
}

class BoCopyButton extends StatelessWidget {
  final String value;
  const BoCopyButton(this.value, {super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: '복사',
        visualDensity: VisualDensity.compact,
        iconSize: 14,
        splashRadius: 14,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          toast(context, '복사했습니다');
        },
        icon: Icon(Icons.content_copy_rounded, color: Bo.text3),
      );
}

// ─────────────────────────────────────────────────────────────
// 상단 바 — 제목·경로 / 전역 새로고침 · 마지막 갱신 · 관리자 · 로그아웃
// ─────────────────────────────────────────────────────────────
class BoTopBar extends StatelessWidget {
  final String title;
  final List<String> breadcrumb;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  const BoTopBar({super.key, required this.title, this.breadcrumb = const [], this.subtitle, this.onBack, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1180;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: Bo.surface, border: Border(bottom: BorderSide(color: Bo.line))),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              tooltip: '뒤로',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              color: Bo.text2,
              style: IconButton.styleFrom(side: BorderSide(color: Bo.line)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (breadcrumb.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(breadcrumb.join('  /  '), style: Bo.caption, overflow: TextOverflow.ellipsis),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(child: Text(title, style: Bo.h1, overflow: TextOverflow.ellipsis)),
                    if (subtitle != null) ...[
                      const SizedBox(width: 12),
                      Flexible(child: Text(subtitle!, style: Bo.muted, overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ...actions,
          if (actions.isNotEmpty) const SizedBox(width: 8),
          const _LastRefresh(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: Bo.isDark ? '밝은 화면' : '어두운 화면',
            onPressed: BoTheme.toggle,
            icon: Icon(Bo.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 19),
            color: Bo.text2,
          ),
          IconButton(
            tooltip: '전체 새로고침',
            onPressed: BoData.refreshAll,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: Bo.text2,
          ),
          Container(width: 1, height: 28, color: Bo.line, margin: const EdgeInsets.symmetric(horizontal: 12)),
          _AdminChip(compact: compact),
        ],
      ),
    );
  }
}

class _LastRefresh extends StatefulWidget {
  const _LastRefresh();

  @override
  State<_LastRefresh> createState() => _LastRefreshState();
}

class _LastRefreshState extends State<_LastRefresh> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: BoData.lastLoaded,
      builder: (context, at, _) {
        final txt = at == null ? '갱신 전' : (DateTime.now().difference(at).inMinutes < 1 ? '방금 갱신' : '${timeAgo(at)} 갱신');
        return Tooltip(
          message: at == null ? '' : '마지막 갱신 ${fmtDateTimeSec(at)}',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule_rounded, size: 14, color: Bo.text3),
            const SizedBox(width: 4),
            Text(txt, style: Bo.caption),
          ]),
        );
      },
    );
  }
}

class _AdminChip extends StatelessWidget {
  final bool compact;
  const _AdminChip({required this.compact});

  @override
  Widget build(BuildContext context) {
    final email = BoData.src.adminEmail;
    return PopupMenuButton<String>(
      tooltip: email,
      position: PopupMenuPosition.under,
      onSelected: (_) => BoData.src.signOut(),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          height: 36,
          child: Text(email.isEmpty ? '(이메일 없음)' : email, style: Bo.muted),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          height: 36,
          child: Row(children: [Icon(Icons.logout_rounded, size: 16, color: Bo.text2), SizedBox(width: 8), Text('로그아웃')]),
        ),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Bo.accentSoft, shape: BoxShape.circle),
          child: Text(email.isEmpty ? 'A' : email[0].toUpperCase(),
              style: TextStyle(color: Bo.accent, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(email, style: Bo.body.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
              Text(BoData.src.isPreview ? '미리보기 모드' : '관리자', style: Bo.caption),
            ],
          ),
        ],
        const SizedBox(width: 2),
        Icon(Icons.expand_more_rounded, size: 18, color: Bo.text3),
      ]),
    );
  }
}

/// 페이지 기본 틀 — 상단 바 + 내용
class BoPage extends StatelessWidget {
  final BoTopBar topBar;
  final Widget child;
  const BoPage({super.key, required this.topBar, required this.child});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [topBar, Expanded(child: child)]);
}

/// 전역 새로고침(epoch)을 듣는 State 도우미 — reload() 를 구현하면 initState·새로고침 때 부른다
mixin BoReloadable<T extends StatefulWidget> on State<T> {
  Future<void> reload();

  void _onEpoch() => reload();

  @override
  void initState() {
    super.initState();
    BoData.epoch.addListener(_onEpoch);
    reload();
  }

  @override
  void dispose() {
    BoData.epoch.removeListener(_onEpoch);
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// 대화상자 · 알림
// ─────────────────────────────────────────────────────────────
/// 확인 대화상자 — true 면 진행

/// 데이터를 바꾸기 전 마지막 확인 — 화면에 뜬 숫자(0~9)를 **손으로 직접 입력**해야 진행된다.
/// 버튼만 누르는 확인은 습관적으로 지나치기 쉬워서, 눈으로 읽고 옮겨 적게 한다(붙여넣기 막음).
Future<bool> confirmCode(BuildContext context, String title, String message,
    {String ok = '확인', Color? okColor}) async {
  final code = Random().nextInt(10);
  final controller = TextEditingController();
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final typed = controller.text.trim();
        final matched = typed == '$code';
        void submit() {
          if (matched) Navigator.pop(ctx, true);
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message, style: Bo.body.copyWith(color: Bo.text2, height: 1.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Bo.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Bo.line),
                      ),
                      child: Text('$code', style: Bo.h1.copyWith(fontSize: 28)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLength: 1,
                        // 붙여넣기 메뉴는 막는다(직접 입력) — 선택·지우기는 되어야 고쳐 쓸 수 있다
                        contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: '왼쪽 숫자를 직접 입력',
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => submit(),
                      ),
                    ),
                  ],
                ),
                if (typed.isNotEmpty && !matched) ...[
                  const SizedBox(height: 6),
                  Text('숫자가 다릅니다.', style: Bo.caption.copyWith(color: Bo.red)),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(
              onPressed: matched ? submit : null,
              style: FilledButton.styleFrom(backgroundColor: okColor ?? Bo.red, foregroundColor: Bo.onAccent),
              child: Text(ok),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return r == true;
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? Bo.red : null),
  );
}

// ─────────────────────────────────────────────────────────────
// 표 칸 공용
// ─────────────────────────────────────────────────────────────
/// 표 안 유저 칸 — 캐릭터 점 · 국기 · 닉네임 (문서 없으면 표시)
class BoUserCell extends StatelessWidget {
  final String uid;
  final Map<String, dynamic>? data;
  final String? charId;
  final bool showBadge; // 대표 뱃지 아이콘
  final String? fallbackName; // 유저 문서가 없을 때(랭킹 기록의 nickname 등)
  const BoUserCell({super.key, required this.uid, required this.data, this.charId, this.showBadge = false, this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final flag = flagOf(data);
    final best = showBadge ? bestBadgeOf(data) : null;
    return Row(children: [
      CharDot(charId ?? data?['characterId'] as String?),
      const SizedBox(width: 8),
      if (flag.isNotEmpty) ...[Text(flag, style: const TextStyle(fontSize: 13)), const SizedBox(width: 4)],
      Flexible(
        child: Text(data == null ? (fallbackName ?? '(유저 문서 없음)') : nickOf(data),
            style: data == null ? Bo.muted.copyWith(color: Bo.text3) : Bo.cellStrong, overflow: TextOverflow.ellipsis),
      ),
      if (best != null) ...[const SizedBox(width: 6), BoBadgeIcon(best, size: 18)],
    ]);
  }
}

class BoStageCell extends StatelessWidget {
  final String mapId;
  const BoStageCell(this.mapId, {super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: stageColor(mapId), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(stageLabel(mapId), style: Bo.cell, overflow: TextOverflow.ellipsis)),
      ]);
}
