import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class QuickAddSheet extends StatelessWidget {
  final VoidCallback onUploadFile;
  final VoidCallback onCreateNote;
  final VoidCallback onAddLink;

  const QuickAddSheet({
    super.key,
    required this.onUploadFile,
    required this.onCreateNote,
    required this.onAddLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add to Space',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildOption(
            context,
            icon: Icons.upload_file_rounded,
            color: AppColors.primary,
            title: 'Upload File',
            subtitle: 'PDFs, Documents, Media, Archives & more',
            onTap: () {
              Navigator.pop(context);
              onUploadFile();
            },
          ),
          _buildOption(
            context,
            icon: Icons.note_add_rounded,
            color: AppColors.catNote,
            title: 'Create Note',
            subtitle: 'Rich text or Markdown note',
            onTap: () {
              Navigator.pop(context);
              onCreateNote();
            },
          ),
          _buildOption(
            context,
            icon: Icons.add_link_rounded,
            color: AppColors.accent,
            title: 'Add Link',
            subtitle: 'Save a bookmark or web resource',
            onTap: () {
              Navigator.pop(context);
              onAddLink();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
