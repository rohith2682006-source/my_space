import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TopAlertBar {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    bool isSuccess = true,
    bool isError = false,
    Color? customColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    // Remove any active top bar first
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _TopAlertWidget(
        message: message,
        icon: icon ??
            (isError
                ? Icons.error_outline_rounded
                : (isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded)),
        isSuccess: isSuccess,
        isError: isError,
        customColor: customColor,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void showSuccess(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, icon: icon ?? Icons.check_circle_rounded, isSuccess: true);
  }

  static void showInfo(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, icon: icon ?? Icons.info_outline_rounded, isSuccess: false);
  }

  static void showError(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, icon: icon ?? Icons.error_outline_rounded, isSuccess: false, isError: true);
  }

  /// Compact animated alert specifically for deleting/trashing operations with optional Undo
  static void showTrash(
    BuildContext context,
    String message, {
    VoidCallback? onUndo,
  }) {
    show(
      context,
      message: message,
      icon: Icons.delete_outline_rounded,
      isSuccess: false,
      isError: true,
      customColor: const Color(0xFFEF4444),
      actionLabel: onUndo != null ? 'Undo' : null,
      onAction: onUndo,
      duration: const Duration(milliseconds: 3200),
    );
  }
}

class _TopAlertWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final bool isSuccess;
  final bool isError;
  final Color? customColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopAlertWidget({
    required this.message,
    required this.icon,
    required this.isSuccess,
    required this.isError,
    this.customColor,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopAlertWidget> createState() => _TopAlertWidgetState();
}

class _TopAlertWidgetState extends State<_TopAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _slideAnimation = Tween<double>(begin: -45.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    final Color accentColor = widget.customColor ??
        (widget.isError
            ? AppColors.error
            : (widget.isSuccess ? AppColors.success : AppColors.primary));

    return Positioned(
      top: topPadding > 0 ? topPadding + 8 : 16,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (ctx, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                _controller.reverse().then((_) {
                  if (mounted) widget.onDismiss();
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xE818181B)
                          : const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.14)
                            : Colors.black.withOpacity(0.08),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.40 : 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 14,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            widget.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null && widget.onAction != null) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              _controller.reverse().then((_) {
                                if (mounted) {
                                  widget.onDismiss();
                                  widget.onAction!();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        ],
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
