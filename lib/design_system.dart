import 'dart:math';
import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'character_data.dart';
import 'zonber_painter.dart';
import 'language_manager.dart';

// ─────────────────────────────────────────────────────────────
// ZONBER 디자인 시스템 v2.2 — docs/UI_DESIGN.md §2
//
// 기본은 라이트(오프화이트 배경 + 흰 카드 + 짙은 슬레이트 텍스트), 설정에서 다크로 전환할 수 있다.
// 화면당 강조색은 스테이지 색 1개. gold 는 명패·챔피언·Hall of Fame 전용. 글로우·그라데이션 워시 없음.
// 위젯 이름(Neon*)은 호출부 변경을 줄이기 위해 유지하고 스타일만 교체했다.
//
// 테마 색은 getter 라서 const 문맥에서 쓸 수 없다. 전환은 GameSettings.darkMode →
// main 의 _applyTheme()가 AppColors.isDark 를 바꾸고 트리 전체를 다시 빌드한다.
// ─────────────────────────────────────────────────────────────

class AppColors {
  /// 현재 테마. GameSettings.darkMode 와 동기화된다(main._applyTheme).
  static bool isDark = false;

  static Color _t(int light, int dark) => Color(isDark ? dark : light);

  static Color get background => _t(0xFFF6F7FB, 0xFF0B0D12);
  static Color get surface => _t(0xFFFFFFFF, 0xFF151923);
  static Color get surface2 => _t(0xFFEDF0F5, 0xFF1E2331);
  static Color get line => _t(0x140F172A, 0x14FFFFFF);
  static Color get text => _t(0xFF0F172A, 0xFFF2F4F8);
  static Color get textDim => _t(0xFF64748B, 0xFF9AA3B2);
  static Color get up => _t(0xFF16A34A, 0xFF3DD68C);
  static Color get danger => _t(0xFFE5484D, 0xFFFF5A4E);
  /// 명패·챔피언·의식 화면 전용. 다른 곳에서 쓰지 않는다.
  static Color get gold => _t(0xFFC99700, 0xFFF5C542);
  static Color get goldDim => _t(0xFF8A6A00, 0xFFC9B36A);
  /// 명패 바탕 — 라이트 크림 / 다크 브론즈
  static Color get plateMetal => _t(0xFFFFF4CC, 0xFF2A2412);
  /// Hall of Fame 의식 화면 배경
  static Color get ceremony => _t(0xFFFFFBEF, 0xFF07080B);
  /// 2·3위 메달
  static Color get silver => _t(0xFF8A94A6, 0xFFC8CFD9);
  static Color get bronze => _t(0xFFB87333, 0xFFC98A5A);
  /// 코인 — 상점·보상 전용(명패 금색과 구분되는 주황빛 호박색)
  static Color get coin => _t(0xFFE8920C, 0xFFFFB02E);

  /// 브랜드 기본 강조색(= Cyber 스테이지). 스테이지 문맥이 없는 화면에서 쓴다.
  static Color get primary => _t(0xFF0A9DBD, 0xFF22C7E6);
  static Color get primaryDim => _t(0xFF7CCBDC, 0xFF0E6F7A);
  /// 위험/피격. 탄환 색은 월드 `ProjectileDef.color`가 정한다.
  static Color get secondary => danger;
  /// 장애물/벽 전용 — 탄환 색과 절대 겹치지 않는 무채색 계열.
  static const Color obstacle = Color(0xFF9FB3C8);
  /// (구) 반투명 서피스 — 이제 surface 와 동일
  static Color get surfaceGlass => surface;

  /// 상태바·내비게이션바 아이콘
  static SystemUiOverlayStyle get overlayStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      );
}

class AppTextStyles {
  /// 한글 폴백 — Sora/Manrope 에는 한글 글리프가 없다. 시스템 CJK 폴백이 없는 플랫폼(웹)에서 tofu 를 막는다.
  static final String? _krFamily = GoogleFonts.notoSansKr().fontFamily;
  static String? _scFamily, _jpFamily;
  /// 현재 언어에 맞는 CJK 폴백 — 중국어·일본어 글꼴은 그 언어일 때만 불러온다
  static List<String> get _cjkFallback {
    switch (LanguageManager().currentLanguage) {
      case 'zh':
        return [_scFamily ??= GoogleFonts.notoSansSc().fontFamily ?? '', if (_krFamily != null) _krFamily!];
      case 'ja':
        return [_jpFamily ??= GoogleFonts.notoSansJp().fontFamily ?? '', if (_krFamily != null) _krFamily!];
      default:
        return [if (_krFamily != null) _krFamily!];
    }
  }
  static TextStyle _withKr(TextStyle s) =>
      s.copyWith(fontFamilyFallback: [..._cjkFallback, ...?s.fontFamilyFallback]);

  /// Display — Sora. 타이틀·생존 시간·순위. 숫자는 타뷸러.
  static TextStyle display(double size,
          {Color? color, FontWeight weight = FontWeight.w800}) =>
      _withKr(GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ));

  /// Body — Manrope.
  static TextStyle text(double size,
          {Color? color, FontWeight weight = FontWeight.w600, double? height}) =>
      _withKr(GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color ?? AppColors.text, height: height));

  /// 12px 대문자 라벨(자간 1)
  static TextStyle label({Color? color}) =>
      _withKr(GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? AppColors.textDim, letterSpacing: 1.0));

  static TextStyle get header => display(24);
  static TextStyle get subHeader => display(18, weight: FontWeight.w700);
  static TextStyle get body => text(14, weight: FontWeight.w500);
}

// ── 문구 줄 처리 ──────────────────────────────────────────────
//
// 규칙: 두 줄 이상 문구는 스트링 테이블에 \n 으로 끊을 자리를 정한다(translations.dart).
//       한글은 LanguageManager.translate 가 어절 단위로만 줄이 바뀌게 만든다.
//       한 줄 자리(버튼 아래 힌트, 배너 등)는 OneLineText — 줄바꿈 없이, 넘치면 글자를 줄여 맞춘다.

/// 한 줄 자리 문구. 테이블에 \n 이 있어도 한 줄로 이어 붙이고, 폭이 모자라면 축소한다(말줄임 없음).
class OneLineText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  const OneLineText(this.text, {super.key, required this.style, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      child: Text(text.replaceAll('\n', ' '), style: style, maxLines: 1, softWrap: false, textAlign: textAlign),
    );
  }
}

// ── 화면 크기 대응 ────────────────────────────────────────────
//
// 규칙: 세로로 요소를 쌓고 Spacer 로 버튼을 아래에 붙이는 화면은 FillScrollView 로 감싼다.
//       공간이 남으면 지금처럼 Spacer 가 채우고, 모자라면(작은 폰·폴드 펼침·가로 화면) 스크롤된다.
//       폭은 AppScaffold 가 kMaxContentWidth 로 제한한다(태블릿·폴드에서 가운데 정렬).

/// 콘텐츠 최대 폭(dp). 이보다 넓은 화면은 가운데 이 폭으로 보인다.
const double kMaxContentWidth = 560;

/// 남는 세로 공간은 Spacer 로 채우고, 모자라면 스크롤되는 세로 레이아웃.
/// [child] 는 Spacer 를 쓰는 Column. (주의: 안쪽 PageView·ListView 는 SizedBox 로 높이를 고정해야 한다)
class FillScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const FillScrollView({super.key, required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = padding.resolve(Directionality.of(context));
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: max(0, c.maxHeight - pad.vertical)),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

// ── 포맷 헬퍼 ────────────────────────────────────────────────

/// 기록은 소수점 셋째 자리까지(넷째 자리부터 버림). 저장·비교·표시 모두 이 값.
/// (12.345 × 1000 = 12344.999… 같은 부동소수 오차로 한 자리 내려가지 않게 아주 작은 값을 더한다)
double recordTime(double seconds) => (seconds * 1000 + 1e-6).floorToDouble() / 1000;

/// 기록 표기: 소수점 3자리 초 `47.812`
String formatSurvival(double seconds) => recordTime(seconds).toStringAsFixed(3);

/// HUD 표기 — 기록과 같은 형식(초, 소수점 3자리)
String formatClock(double seconds) => formatSurvival(seconds);

String formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 국기 이모지(regional indicator 2자) → ISO 2자 코드. 변환 불가면 빈 문자열.
String flagToIso(String flag) {
  final runes = flag.runes.toList();
  if (runes.length != 2) return '';
  final buf = StringBuffer();
  for (final r in runes) {
    if (r < 0x1F1E6 || r > 0x1F1FF) return '';
    buf.writeCharCode(r - 0x1F1E6 + 0x41);
  }
  return buf.toString();
}

// ── 레이아웃 ────────────────────────────────────────────────

class NeonScaffold extends StatelessWidget {
  final String? title;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const NeonScaffold({
    super.key,
    this.title,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.showBackButton = false,
    this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (title != null)
              NeonAppBar(
                title: title!,
                showBackButton: showBackButton,
                onBack: onBack,
                actions: actions,
              ),
            if (body != null) Expanded(child: body!),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class NeonAppBar extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const NeonAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showBackButton) ...[
            AppIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack ?? () => Navigator.of(context).pop(),
              label: 'Back',
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.display(20),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: showBackButton ? TextAlign.left : TextAlign.center,
            ),
          ),
          if (actions != null) ...actions!,
          if (actions == null && showBackButton) const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final Color? color;
  final Color? background;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background ?? AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color ?? AppColors.text, size: 22),
        ),
      ),
    );
  }
}

class NeonListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const NeonListView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: children.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => children[index],
    );
  }
}

// ── 카드 / 버튼 ──────────────────────────────────────────────

class NeonCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const NeonCard({
    super.key,
    required this.child,
    this.borderColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor == null || borderColor == Colors.transparent
              ? AppColors.line
              : borderColor!,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// 버튼. `isPrimary` = 채움(월드/브랜드 색 배경, 어두운 텍스트),
/// 아니면 surface2 배경의 보조 버튼. `color` 는 primary 배경색 / secondary 텍스트색.
class NeonButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isPrimary;
  final bool isCompact;
  final IconData? icon;
  final double? fontSize;

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.isPrimary = true,
    this.isCompact = false,
    this.icon,
    this.fontSize,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? AppColors.primary;
    final bool filled = widget.isPrimary;
    final Color bg = filled ? accent : AppColors.surface2;
    final Color fg = filled ? AppColors.background : (widget.color ?? AppColors.text);
    final double h = widget.isCompact ? 44 : 56;
    final bool disabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 80),
        opacity: disabled ? 0.45 : (_isPressed ? 0.82 : 1.0),
        child: Container(
          height: h,
          padding: EdgeInsets.symmetric(horizontal: widget.isCompact ? 14 : 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.isCompact ? 12 : 16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: widget.isCompact ? 18 : 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.text,
                    style: (filled
                            ? AppTextStyles.display(widget.fontSize ?? (widget.isCompact ? 14 : 16),
                                color: fg, weight: FontWeight.w800)
                            : AppTextStyles.text(widget.fontSize ?? (widget.isCompact ? 14 : 15),
                                color: fg, weight: FontWeight.w700))
                        .copyWith(decoration: TextDecoration.none),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NeonMenuButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final bool isPrimary;
  final double? width;
  final double? fontSize;

  const NeonMenuButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.isPrimary = true,
    this.width,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: width ?? double.infinity,
      constraints: width == null ? const BoxConstraints(maxWidth: 342) : null,
      child: NeonButton(
        text: text,
        onPressed: onPressed,
        color: color,
        isPrimary: isPrimary,
        fontSize: fontSize,
      ),
    );
  }
}

/// 작은 칩. `filled` 면 `color` 배경 + 어두운 텍스트.
class AppChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool filled;
  final IconData? icon;
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    this.color,
    this.filled = false,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textDim;
    final child = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: filled ? c : AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? AppColors.background : c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.text(12,
                color: filled ? AppColors.background : (color ?? AppColors.text),
                weight: FontWeight.w700),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
  }
}

/// 국가 칩 — ISO 2자(국기 이모지에서 유도). 유도 실패 시 이모지 표시.
class CountryChip extends StatelessWidget {
  final String flag;
  final Color? color;
  /// 국기 이미지 높이(너비는 3:2)
  final double height;
  const CountryChip({super.key, required this.flag, this.color, this.height = 15});

  @override
  Widget build(BuildContext context) {
    final iso = flagToIso(flag);
    if (iso.isEmpty) {
      // 코드로 못 바꾸는 값(옛 데이터) — 글자 그대로
      return Text(flag, style: AppTextStyles.text(11, color: color ?? AppColors.textDim, weight: FontWeight.w800));
    }
    // 국기 이미지 — 흰 바탕 국기도 보이게 얇은 테두리
    final w = height * 1.5;
    return Container(
      width: w + 2,
      height: height + 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color ?? AppColors.line, width: 1),
      ),
      child: CountryFlag.fromCountryCode(
        iso,
        theme: ImageTheme(width: w, height: height, shape: const RoundedRectangle(2)),
      ),
    );
  }
}

/// 강조점(방점) 텍스트 — 스트링의 `[존]` 처럼 대괄호로 감싼 글자 위에 점을 찍는다.
/// 존버 정체성 문구(존·버 / 존·생 / 존·막)용. 대괄호가 없으면 그냥 텍스트다(외국어).
class EmphasisText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color dotColor;
  const EmphasisText(this.text, {super.key, required this.style, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    final parts = LanguageManager.parseEmphasis(text);
    final size = style.fontSize ?? 20;
    return Text.rich(
      TextSpan(children: [
        for (final (s, em) in parts)
          if (!em)
            TextSpan(text: s, style: style)
          else
            for (final ch in s.characters)
              WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: size * 0.2,
                      height: size * 0.2,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                    SizedBox(height: size * 0.08),
                    Text(ch, style: style.copyWith(color: dotColor)),
                  ],
                ),
              ),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// 코인 표시 — 동전 아이콘 + 숫자. [onTap] 이 있으면 누를 수 있다(홈 → 상점)
class CoinChip extends StatelessWidget {
  final int amount;
  final VoidCallback? onTap;
  final String? prefix; // 예: '+'
  final double size;
  const CoinChip({super.key, required this.amount, this.onTap, this.prefix, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: size + 18,
      padding: EdgeInsets.symmetric(horizontal: size * 0.7),
      decoration: BoxDecoration(
        color: AppColors.coin.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.coin.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: size + 2),
          SizedBox(width: size * 0.4),
          Text('${prefix ?? ''}${formatCount(amount)}', style: AppTextStyles.display(size, color: AppColors.coin)),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: chip);
  }
}

/// 동전 — 호박색 원 + 안쪽 테두리 + 가운데 Z
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    // 코인 그림(assets/images/game/coin.png). 없으면 아래 코드 그림
    return Image.asset(
      'assets/images/game/coin.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD66B), Color(0xFFF2A516), Color(0xFFD9800A)],
        ),
        border: Border.all(color: const Color(0xFFB86A00), width: size * 0.07),
      ),
      alignment: Alignment.center,
      child: Text('Z', style: AppTextStyles.display(size * 0.55, color: const Color(0xFF7A4300))),
    );
  }
}

/// 세그먼트 컨트롤 — 기간·범위 선택
class AppSegmented extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  const AppSegmented({super.key, required this.items, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    items[i],
                    style: AppTextStyles.text(12,
                        color: i == index ? AppColors.text : AppColors.textDim,
                        weight: i == index ? FontWeight.w700 : FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 캐릭터 아바타 — 코드로 그린 동글동글한 존버(몸 색 = 캐릭터 색). 사진 업로드 없음.
class CharacterAvatar extends StatelessWidget {
  final String characterId;
  final double size;
  final Color? borderColor;
  const CharacterAvatar({super.key, required this.characterId, this.size = 32, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final c = CharacterData.getCharacter(characterId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor!, width: 2) : null,
      ),
      child: CustomPaint(painter: ZonberPainter(ZonberLook(color: c.color, body: c.id))),
    );
  }
}

/// 명패 등급 — 세계 1위 챔피언 · 세계 TOP 10 골드 · 세계 TOP 100 실버 · 국가 TOP 10 브론즈.
/// 등급마다 금속이 달라서 한눈에 급이 보인다. 랭킹 이름 옆 배지에도 같은 등급을 쓴다.
enum PlateTier { champion, gold, silver, bronze }

PlateTier plateTierOf(String scope, int rank) {
  if (scope != 'world') return PlateTier.bronze;
  if (rank <= 1) return PlateTier.champion;
  if (rank <= 10) return PlateTier.gold;
  return PlateTier.silver;
}

/// 명패 금속 — 테마(라이트/다크)와 무관하게 같은 금속으로 보인다.
class PlateStyle {
  final List<Color> metal; // 대각선 그라데이션(밝음 → 어두움 → 밝음)
  final Color edge; // 테두리·리벳
  final Color ink; // 각인 글자
  final Color inkDim;
  final IconData icon;
  final String labelKey;
  final bool darkPlate; // 각인 그림자 방향(어두운 판은 아래로, 밝은 판은 위로 파인 느낌)

  const PlateStyle(this.metal, this.edge, this.ink, this.inkDim, this.icon, this.labelKey, {this.darkPlate = false});

  static PlateStyle of(PlateTier t) {
    switch (t) {
      case PlateTier.champion:
        return const PlateStyle(
          [Color(0xFF3A2F17), Color(0xFF14110A), Color(0xFF2E2511)],
          Color(0xFFE9B949), Color(0xFFF7D774), Color(0xFFC9A54A),
          Icons.emoji_events_rounded, 'plate_tier_champion', darkPlate: true);
      case PlateTier.gold:
        return const PlateStyle(
          [Color(0xFFFFF1C2), Color(0xFFF0C24A), Color(0xFFFFE08A)],
          Color(0xFFB8860B), Color(0xFF4F3700), Color(0xFF7A5A12),
          Icons.workspace_premium_rounded, 'plate_tier_gold');
      case PlateTier.silver:
        return const PlateStyle(
          [Color(0xFFFAFBFD), Color(0xFFC3CAD5), Color(0xFFEEF1F5)],
          Color(0xFF7E8898), Color(0xFF263040), Color(0xFF566173),
          Icons.military_tech_rounded, 'plate_tier_silver');
      case PlateTier.bronze:
        return const PlateStyle(
          [Color(0xFFF7D9BD), Color(0xFFCB895A), Color(0xFFF0C29C)],
          Color(0xFF94552A), Color(0xFF45220E), Color(0xFF6F3E1D),
          Icons.military_tech_rounded, 'plate_tier_bronze');
    }
  }
}

/// 명패 — Hall of Fame 진입 시 새겨지는 영구 기록. 등급별 금속 판에 이름을 각인한다.
class NamePlate extends StatelessWidget {
  final String nickname;
  final String flag;
  final String worldName;
  final String scopeLabel; // 예: "WORLD TOP 100"
  final int rank;
  final double survivalTime;
  final String dateLabel;
  final bool compact;
  /// 'world' | 'country' — 등급을 정한다
  final String scope;
  /// 빛 반사 위치 0→1 (의식 화면에서 한 번 훑고 지나간다). null 이면 고정 위치
  final double? shine;

  const NamePlate({
    super.key,
    required this.nickname,
    required this.flag,
    required this.worldName,
    required this.scopeLabel,
    required this.rank,
    required this.survivalTime,
    required this.dateLabel,
    this.compact = false,
    this.scope = 'world',
    this.shine,
  });

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final st = PlateStyle.of(plateTierOf(scope, rank));
    final double h = compact ? 112 : 150;
    final r = compact ? 14.0 : 18.0;
    // 각인 — 글자가 판에 파인 것처럼 한쪽은 밝게, 반대쪽은 어둡게
    final engrave = [
      Shadow(color: (st.darkPlate ? Colors.black : Colors.white).withValues(alpha: st.darkPlate ? 0.8 : 0.7), offset: const Offset(0, 1)),
      Shadow(color: (st.darkPlate ? Colors.white : Colors.black).withValues(alpha: st.darkPlate ? 0.10 : 0.18), offset: const Offset(0, -1)),
    ];
    Widget rivet(Alignment a) => Align(
          alignment: a,
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 10),
            child: Container(
              width: compact ? 5 : 6,
              height: compact ? 5 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.9), st.edge], stops: const [0, 0.7]),
              ),
            ),
          ),
        );
    final s = shine ?? 0.28;
    return Container(
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: st.metal),
        border: Border.all(color: st.edge, width: 2),
        boxShadow: [BoxShadow(color: st.edge.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r - 2),
        child: Stack(
          children: [
            // 빛 반사 — 비스듬한 띠 하나가 판 위를 지나간다
            Positioned.fill(
              child: LayoutBuilder(builder: (context, bc) {
                final x = -90 + (bc.maxWidth + 180) * s;
                return Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: x - 32,
                    top: -h,
                    width: 64,
                    height: h * 3,
                    child: Transform.rotate(
                      angle: 0.45,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: st.darkPlate ? 0.12 : 0.5),
                            Colors.white.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]);
              }),
            ),
            // 안쪽 테두리(판 가장자리 몰딩)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(compact ? 5 : 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r - 6),
                  border: Border.all(color: st.ink.withValues(alpha: 0.22), width: 1),
                ),
              ),
            ),
            rivet(Alignment.topLeft),
            rivet(Alignment.topRight),
            rivet(Alignment.bottomLeft),
            rivet(Alignment.bottomRight),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(st.icon, size: compact ? 13 : 15, color: st.ink),
                        const SizedBox(width: 5),
                        Text(
                          '${lm.translate(st.labelKey)} · $worldName',
                          style: AppTextStyles.label(color: st.ink)
                              .copyWith(fontSize: compact ? 9 : 10, letterSpacing: 2, shadows: engrave),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 5 : 9),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              nickname.toUpperCase(),
                              maxLines: 1,
                              style: AppTextStyles.display(compact ? 22 : 30, color: st.ink)
                                  .copyWith(letterSpacing: 2.5, shadows: engrave),
                            ),
                          ),
                        ),
                        if (flag.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          CountryChip(flag: flag, color: st.edge, height: compact ? 13 : 16),
                        ],
                      ],
                    ),
                    SizedBox(height: compact ? 6 : 10),
                    // 가운데 가는 선 + 순위
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: compact ? 18 : 26, height: 1, color: st.inkDim.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Text(
                          '$scopeLabel #${formatCount(rank)}',
                          style: AppTextStyles.text(compact ? 10 : 11, color: st.ink, weight: FontWeight.w800)
                              .copyWith(letterSpacing: 1.2, shadows: engrave),
                        ),
                        const SizedBox(width: 8),
                        Container(width: compact ? 18 : 26, height: 1, color: st.inkDim.withValues(alpha: 0.6)),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 5),
                    Text(
                      '${formatSurvival(survivalTime)}s · $dateLabel',
                      style: AppTextStyles.text(compact ? 10 : 11, color: st.inkDim, weight: FontWeight.w700)
                          .copyWith(letterSpacing: 1, shadows: engrave),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 랭킹 이름 옆 명패 배지 — 이 존에서 명패를 새긴 사람만 붙는다
class PlateBadge extends StatelessWidget {
  final PlateTier tier;
  final double size;
  const PlateBadge({super.key, required this.tier, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final st = PlateStyle.of(tier);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: st.metal),
        border: Border.all(color: st.edge, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(st.icon, size: size * 0.62, color: st.ink),
    );
  }
}

/// 리더보드 행
class RankRow extends StatelessWidget {
  final int rank;
  final String nickname;
  final String flag;
  final String characterId;
  final double survivalTime;
  final bool highlighted;
  final Color? accent;
  final VoidCallback? onTap;
  /// 이 존에서 새긴 명패 등급(없으면 null)
  final PlateTier? plate;
  /// 목록 마지막 행이면 아래 구분선을 그리지 않는다
  final bool last;

  const RankRow({
    super.key,
    required this.rank,
    required this.nickname,
    required this.flag,
    required this.characterId,
    required this.survivalTime,
    this.highlighted = false,
    this.accent,
    this.onTap,
    this.plate,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? AppColors.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: highlighted ? a.withValues(alpha: 0.10) : null,
          border: highlighted
              ? Border(left: BorderSide(color: a, width: 3))
              : (last ? null : Border(bottom: BorderSide(color: AppColors.line))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(
                rank > 0 ? '$rank' : '-',
                style: AppTextStyles.display(rank > 999 ? 13 : 15, color: highlighted ? a : AppColors.textDim),
              ),
            ),
            CharacterAvatar(
              characterId: characterId,
              size: 32,
              borderColor: plate != null ? PlateStyle.of(plate!).edge : null,
            ),
            const SizedBox(width: 10),
            // 이름 · 명패 배지 · 국기 — 남는 폭은 이름이 다 쓴다(Spacer 와 나눠 가지면 이름이 반만 보인다)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      nickname,
                      style: AppTextStyles.text(14, weight: highlighted ? FontWeight.w800 : FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (plate != null) ...[
                    const SizedBox(width: 6),
                    PlateBadge(tier: plate!, size: 18),
                  ],
                  const SizedBox(width: 8),
                  CountryChip(flag: flag, height: 13),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: formatSurvival(survivalTime), style: AppTextStyles.display(15)),
                TextSpan(text: 's', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 탭 — 홈 · 랭킹 · 프로필
class AppBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final Color? accent;
  const AppBottomNav({super.key, required this.index, required this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final items = [
      (Icons.home_rounded, lm.translate('nav_home')),
      (Icons.emoji_events_rounded, lm.translate('nav_ranking')),
      (Icons.storefront_rounded, lm.translate('nav_shop')),
      (Icons.person_rounded, lm.translate('nav_profile')),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i].$1, size: 24, color: i == index ? (accent ?? AppColors.primary) : AppColors.textDim),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$2,
                      style: AppTextStyles.text(11,
                          color: i == index ? (accent ?? AppColors.primary) : AppColors.textDim, weight: FontWeight.w700),
                    ),
                  ],
                ),
                ),
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }
}

/// 섹션 라벨(12px, 자간) + 우측 보조 텍스트
class SectionLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  const SectionLabel(this.text, {super.key, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(text, style: AppTextStyles.label()),
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

// ── 다이얼로그 ──────────────────────────────────────────────

class NeonDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;
  final Color? titleColor;
  final bool barrierDismissible;

  const NeonDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
    this.titleColor,
    this.barrierDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: barrierDismissible ? () => Navigator.of(context).pop() : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 180),
              tween: Tween(begin: 0.94, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenSize.width * 0.88,
                  maxHeight: screenSize.height * 0.8,
                ),
                child: NeonCard(
                  padding: const EdgeInsets.all(24),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.display(20, color: titleColor ?? AppColors.text),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (message != null) ...[
                            Text(
                              message!,
                              style: AppTextStyles.text(14, color: AppColors.textDim, weight: FontWeight.w500, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (content != null) ...[
                            content!,
                            const SizedBox(height: 20),
                          ],
                          if (actions.length == 2)
                            Row(
                              children: [
                                Expanded(child: actions[0]),
                                const SizedBox(width: 10),
                                Expanded(child: actions[1]),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int i = 0; i < actions.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  actions[i],
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showNeonDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  required List<Widget> actions,
  Color? titleColor,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (context) => NeonDialog(
      title: title,
      message: message,
      content: content,
      actions: actions,
      titleColor: titleColor,
      barrierDismissible: barrierDismissible,
    ),
  );
}

/// 최상위 래퍼 — 배너 광고 슬롯 + 하단 탭 + Android 백버튼.
class AppScaffold extends StatelessWidget {
  final Widget child;
  final Widget? bannerAd;
  final VoidCallback? onBack;
  final bool showBanner;
  final Widget? bottomNav;
  /// 화면 전체 바탕(상태바·내비게이션바 영역 포함). 게임 중에는 존 바닥색 — 무대와 한 덩어리로 보이게.
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.child,
    this.bannerAd,
    this.onBack,
    this.showBanner = true,
    this.bottomNav,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 바탕색을 지정한 화면은 그 명도에 맞춰 상태바 아이콘 색을 정한다
      value: bg == null
          ? AppColors.overlayStyle
          : (bg.computeLuminance() < 0.4 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: bg),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;
          if (onBack != null) {
            onBack!();
          } else {
            final langManager = LanguageManager.of(context, listen: false);
            bool exit = await showNeonDialog<bool>(
                  context: context,
                  title: langManager.translate('exit_game'),
                  message: langManager.translate('exit_game_message'),
                  actions: [
                    NeonButton(
                      text: langManager.translate('cancel'),
                      isPrimary: false,
                      isCompact: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    NeonButton(
                      text: langManager.translate('quit'),
                      color: AppColors.danger,
                      isCompact: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ) ??
                false;
            if (exit) SystemNavigator.pop();
          }
        },
        child: Scaffold(
          backgroundColor: bg ?? AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // 숨길 때도 트리에서 빼지 않는다 — AdWidget 을 떼었다 붙이면 플랫폼 뷰가 재생성된다
                if (bannerAd != null)
                  Visibility(
                    visible: showBanner,
                    maintainState: true,
                    child: Container(
                      color: AppColors.background,
                      width: double.infinity,
                      height: 50,
                      alignment: Alignment.center,
                      child: bannerAd,
                    ),
                  ),
                // 넓은 화면(태블릿·폴드)은 가운데 kMaxContentWidth 폭으로
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Center(
                      child: SizedBox(
                        width: min(c.maxWidth, kMaxContentWidth),
                        height: c.maxHeight,
                        child: child,
                      ),
                    ),
                  ),
                ),
                if (bottomNav != null) bottomNav!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
