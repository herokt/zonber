import 'package:flutter/material.dart';

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
  final Widget? bannerAd; // Added bannerAd support

  const NeonScaffold({
    super.key,
    this.title,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.showBackButton = false,
    this.onBack,
    this.bannerAd,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Banner Ad Slot (Fixed Height 50 to prevent shifts)
            SizedBox(
              height: 50,
              width: double.infinity,
              child: bannerAd ?? const SizedBox(),
            ),
            if (title != null)
              NeonAppBar(
                title: title!,
                showBackButton: showBackButton,
                onBack: onBack,
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
  });

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
            // Neon Back Button (Icon Style)
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
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.header,
              textAlign: showBackButton ? TextAlign.left : TextAlign.center,
            ),
          ),
          if (showBackButton) const SizedBox(width: 44), // Balance spacing
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

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.isPrimary = true,
    this.isCompact = false,
    this.icon,
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
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                size: widget.isCompact ? 18 : 24,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: baseColor,
                  fontSize: widget.isCompact ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  shadows: [
                    Shadow(color: baseColor.withOpacity(0.3), blurRadius: 2),
                  ],
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
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

  const NeonMenuButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300),
      child: NeonButton(
        text: text,
        onPressed: onPressed,
        color: color,
        isPrimary: isPrimary,
        isCompact: false,
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

  const NeonDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: NeonCard(
        backgroundColor: AppColors.background.withOpacity(0.95),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTextStyles.header.copyWith(
                color: titleColor ?? AppColors.primary,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (message != null) ...[
              Text(
                message!,
                style: AppTextStyles.body.copyWith(fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
            if (content != null) ...[content!, const SizedBox(height: 24)],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: actions.map((action) {
                return Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: action,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
