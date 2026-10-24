import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'navigation_tab_controller.dart';
import 'unified_back_button.dart';

class FloatingHeaderBar extends StatelessWidget {
  final Widget? leading;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const FloatingHeaderBar({
    super.key,
    this.leading,
    this.showBackButton,
    this.onBackPressed,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabCtrl = NavigationTabController.of(context);
    final isSecondaryTab = tabCtrl != null && tabCtrl.currentIndex > 0;
    final canGoBack = showBackButton ??
        (onBackPressed != null || Navigator.canPop(context) || isSecondaryTab);

    void handleBack() {
      if (onBackPressed != null) {
        onBackPressed!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else if (isSecondaryTab) {
        tabCtrl.onSelectTab(0);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF130B2A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : AppColors.lightBorder,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
            child: Row(
              children: [
                if (canGoBack) ...[
                  UnifiedBackButton(onPressed: handleBack),
                  const SizedBox(width: 8),
                ],
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        );
  }
}

class HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final Color? color;

  const HeaderActionButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: color ?? (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
