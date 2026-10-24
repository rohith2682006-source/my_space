import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;
  final bool? isDark;

  const AmbientBackground({
    super.key,
    required this.child,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    // 120 FPS hardware-accelerated solid background with zero radial gradient composition overhead.
    // Pure creamy white for light mode (#F6F4EE) and deep matte for dark mode.
    return RepaintBoundary(
      child: ColoredBox(
        color: effectiveIsDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: child,
      ),
    );
  }
}
