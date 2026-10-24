import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen settings navigation helper.
/// Pushes settings screens directly onto the root navigator as full-screen animated pages,
/// avoiding nested Navigator conflicts with ThemeProvider rebuilds.
class SettingsContainerDialog {
  /// Opens the settings screen as a full-screen animated page.
  static Future<T?> show<T>(BuildContext context, Widget initialPage) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder<T>(
        pageBuilder: (ctx, animation, secondaryAnimation) => initialPage,
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }
}

/// The standard scaffold layout for every settings subpage.
/// Centers content within an optimal reading width on desktop (880px)
/// while providing full-width edge-to-edge responsiveness on mobile.
class SettingsScreenScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final List<Widget>? actions;

  const SettingsScreenScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.scrollable = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.canPop(context)) {
            Navigator.maybePop(context);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
            child: SafeArea(
              top: true,
              child: Column(
                children: [
                _SettingsHeader(
                  title: title,
                  subtitle: subtitle,
                  isDark: isDark,
                  canPop: canPop,
                  actions: actions,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: scrollable
                          ? SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: padding,
                              child: child,
                            )
                          : Padding(
                              padding: padding,
                              child: child,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isDark;
  final bool canPop;
  final List<Widget>? actions;

  const _SettingsHeader({
    required this.title,
    this.subtitle,
    required this.isDark,
    required this.canPop,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 68,
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
            .withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Back Button
                if (canPop)
                  _HeaderIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: 'Back',
                    isDark: isDark,
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.settings_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions and Close Button
                ...?actions,
                const SizedBox(width: 6),
                _HeaderCloseButton(isDark: isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isDark;

  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.isDark,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06))
                  : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCloseButton extends StatefulWidget {
  final bool isDark;
  const _HeaderCloseButton({required this.isDark});

  @override
  State<_HeaderCloseButton> createState() => _HeaderCloseButtonState();
}

class _HeaderCloseButtonState extends State<_HeaderCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close Settings (Esc)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () {
            final nav = Navigator.of(context, rootNavigator: true);
            if (nav.canPop()) {
              nav.popUntil((route) => route.isFirst);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08))
                  : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: widget.isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

