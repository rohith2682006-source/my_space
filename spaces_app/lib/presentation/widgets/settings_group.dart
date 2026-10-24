import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A cohesive, professional grouped settings container inspired by modern
/// desktop and mobile operating systems (Apple, Raycast, Linear).
/// Removes disconnected floating cards in favor of unified grouped sections.
class SettingsGroup extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsGroup({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 24),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null && header!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 8),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B1233).withValues(alpha: 0.75)
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.6)
                    : AppColors.lightBorder,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 58,
                        endIndent: 0,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null && footer!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 8),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An interactive, polished row inside a [SettingsGroup].
class SettingsRow extends StatefulWidget {
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showChevron;

  const SettingsRow({
    super.key,
    this.leading,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
  });

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canTap = widget.onTap != null;

    final titleColor = widget.isDestructive
        ? AppColors.error
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    final effectiveIconColor = widget.isDestructive
        ? AppColors.error
        : (widget.iconColor ?? AppColors.primary);

    Widget leadingWidget;
    if (widget.leading != null) {
      leadingWidget = widget.leading!;
    } else if (widget.icon != null) {
      leadingWidget = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: effectiveIconColor.withValues(alpha: isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: 19,
            color: effectiveIconColor,
          ),
        ),
      );
    } else {
      leadingWidget = const SizedBox(width: 8);
    }

    Widget trailingWidget;
    if (widget.trailing != null) {
      trailingWidget = widget.trailing!;
    } else if (widget.showChevron && canTap) {
      trailingWidget = AnimatedSlide(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        offset: _isHovered ? const Offset(0.15, 0) : Offset.zero,
        child: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.30),
        ),
      );
    } else {
      trailingWidget = const SizedBox.shrink();
    }

    return MouseRegion(
      cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: canTap ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: canTap ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: canTap ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          color: _isPressed
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06))
              : _isHovered
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03))
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              leadingWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2.5),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 12.2,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailingWidget,
            ],
          ),
        ),
      ),
    );
  }
}
