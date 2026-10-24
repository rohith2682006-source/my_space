import 'package:flutter/material.dart';
import '../../presentation/widgets/top_alert_bar.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../data/models/space_model.dart';
import '../../providers/spaces_provider.dart';

class SpaceCard extends StatelessWidget {
  final SpaceModel space;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const SpaceCard({
    super.key,
    required this.space,
    required this.onTap,
    this.onMoreTap,
  });

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = _parseColor(space.color);
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 480;

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : AppColors.lightBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: EdgeInsets.all(isNarrow ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Space Icon in colored container
                Container(
                  width: isNarrow ? 44 : 54,
                  height: isNarrow ? 44 : 54,
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cardColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    space.icon,
                    style: TextStyle(fontSize: isNarrow ? 22 : 28),
                  ),
                ),
                // Privacy / More
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!space.isPrivate) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Shared',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                        ),
                        tooltip: 'Space Options',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (val) {
                          if (val == 'share') {
                            onMoreTap?.call();
                          } else if (val == 'delete') {
                            _confirmDelete(context);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.share_outlined,
                                  size: 18,
                                  color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Share Space',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                SizedBox(width: 10),
                                Text('Delete Space', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Space Name
            Text(
              space.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // Description (if present)
            if (space.description != null && space.description!.isNotEmpty)
              Text(
                space.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            const SizedBox(height: 12),
            // Meta Row (File count & Size)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${space.fileCount} ${space.fileCount == 1 ? 'file' : 'files'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  FileHelper.timeAgo(space.lastActivityAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Space?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${space.name}" and all of its contents? This cannot be undone.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await Provider.of<SpacesProvider>(context, listen: false)
                  .deleteSpace(space.id);
              if (context.mounted && success) {
                TopAlertBar.showSuccess(context, 'Space "${space.name}" deleted');
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
