import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'language_manager.dart';

class AppColors {
  static const Color primary = Color(0xFF00B8D4); // Cyan (Darker)
  static const Color primaryDim = Color(0xFF006064); // Darker Cyan (Dim)
  static const Color secondary = Color(0xFFD32F2F); // Red (Darker)
  static const Color background = Color(0xFF050510); // Deep Space Black
  static const Color surface = Color(0xFF121212); // Almost Black Surface
  static const Color surfaceGlass = Color(
    0xEE121212,
  ); // Less Transparent Surface
  static const Color text = Colors.white;
  static const Color textDim = Color(0xFFB0BEC5); // Blue-Grey Dim
}

class AppTextStyles {
  static const TextStyle header = TextStyle(
    color: AppColors.primary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
    shadows: [
      Shadow(blurRadius: 4, color: AppColors.primary, offset: Offset(0, 0)),
    ],
  );

  static const TextStyle subHeader = TextStyle(
    color: AppColors.text,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle body = TextStyle(color: AppColors.text, fontSize: 14);
}

// --- CORE LAYOUT COMPONENTS ---

class NeonScaffold extends StatelessWidget {
  final String? title;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final VoidCallback? onBack;

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

  final List<Widget>? actions;

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

  const NeonAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBack,
    this.actions,
  });

  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primaryDim.withOpacity(0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDim.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: showBackButton
                  ? Alignment.centerLeft
                  : Alignment.center,
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.header,
                maxLines: 1,
              ),
            ),
          ),
          if (actions != null) ...actions!,
          if (actions == null && showBackButton) const SizedBox(width: 44),
        ],
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

// --- WIDGETS ---

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
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (borderColor ?? AppColors.primary).withOpacity(0.5),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (borderColor ?? AppColors.primary).withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

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
    Color baseColor =
        widget.color ??
        (widget.isPrimary ? AppColors.primary : AppColors.secondary);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.isCompact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _isPressed ? baseColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: baseColor.withOpacity(_isPressed ? 1.0 : 0.6),
            width: 1.5,
          ),
          boxShadow: [
            if (!_isPressed)
              BoxShadow(
                color: baseColor.withOpacity(0.1),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            if (_isPressed)
              BoxShadow(
                color: baseColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: baseColor,
                size: widget.isCompact ? 16 : 20,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: baseColor,
                    fontSize: widget.fontSize ?? (widget.isCompact ? 13 : 16),
                    fontWeight: FontWeight.bold,
                    decoration:
                        TextDecoration.none, // Fix: Prevent yellow underlines
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: baseColor.withOpacity(0.3), blurRadius: 2),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
          ],
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
      constraints: width == null ? const BoxConstraints(maxWidth: 300) : null,
      child: NeonButton(
        text: text,
        onPressed: onPressed,
        color: color,
        isPrimary: isPrimary,
        isCompact: false,
        fontSize: fontSize,
      ),
    );
  }
}

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
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap propagation to barrier
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 200),
              tween: Tween(begin: 0.8, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenSize.width * 0.85,
                  maxHeight: screenSize.height * 0.8,
                ),
                child: NeonCard(
                  backgroundColor: AppColors.background,
                  borderColor: AppColors.primary,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            style: AppTextStyles.header.copyWith(
                              color: titleColor ?? AppColors.primary,
                              fontSize: 22,
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (message != null) ...[
                          Text(
                            message!,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 15,
                              height: 1.5,
                            ),
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
                              const SizedBox(width: 12),
                              Expanded(child: actions[1]),
                            ],
                          )
                        else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: actions,
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
    );
  }
}

/// Helper function to show NeonDialog with proper settings
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
    barrierDismissible: false, // We handle this ourselves
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

/// A global scaffold that acts as the root wrapper for the app's pages.
/// It handles:
/// 1. Global Banner Ad display at the top.
/// 2. Android Back Button intercept (PopScope).
class AppScaffold extends StatelessWidget {
  final Widget child;
  final Widget? bannerAd;
  final VoidCallback? onBack; // If null, it assumes root and tries to exit
  final bool showBanner;

  const AppScaffold({
    super.key,
    required this.child,
    this.bannerAd,
    this.onBack,
    this.showBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // Force white text/icons
      child: PopScope(
        canPop: false, // Prevent default pop to handle it manually
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;
          if (onBack != null) {
            onBack!();
          } else {
            // If no back handler is provided (Root page), show exit dialog
            final langManager = LanguageManager.of(context, listen: false);
            bool exit =
                await showNeonDialog<bool>(
                  context: context,
                  title: langManager.translate('exit_game'),
                  titleColor: AppColors.secondary,
                  message: langManager.translate('exit_game_message'),
                  actions: [
                    NeonButton(
                      text: langManager.translate('cancel'),
                      isPrimary: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    NeonButton(
                      text: langManager.translate('quit'),
                      color: AppColors.secondary,
                      isPrimary: false,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ) ??
                false;

            if (exit) {
              SystemNavigator.pop();
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Global Banner Ad Slot
                if (showBanner && bannerAd != null)
                  Container(
                    color: AppColors.background,
                    width: double.infinity,
                    height: 50, // Standard Banner Height
                    alignment: Alignment.center,
                    child: bannerAd,
                  ),

                // Main Content
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
