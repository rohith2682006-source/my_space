import 'package:flutter/material.dart';

class UnifiedBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const UnifiedBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return IconButton(
      tooltip: 'Back',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 40,
        minHeight: 40,
      ),
      icon: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      onPressed: onPressed ?? () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}
