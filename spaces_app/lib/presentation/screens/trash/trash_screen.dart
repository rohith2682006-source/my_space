import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_helper.dart';
import '../../../providers/files_provider.dart';
import '../../widgets/floating_header_bar.dart';
import '../../widgets/top_alert_bar.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FilesProvider>(context, listen: false).fetchTrash();
    });
  }

  void _confirmEmptyTrash() {
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
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Empty Trash',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete all files in Trash. This action cannot be undone.',
          style: TextStyle(height: 1.5),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<FilesProvider>(
                context,
                listen: false,
              );
              for (final file in List.from(provider.trashFiles)) {
                await provider.deletePermanently(file.id);
              }
              if (mounted) {
                TopAlertBar.showTrash(context, 'Trash emptied permanently');
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filesProvider = Provider.of<FilesProvider>(context);
    final trashFiles = filesProvider.trashFiles;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Floating Glass Header
            SliverToBoxAdapter(
              child: FloatingHeaderBar(
                showBackButton: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
                title: 'Trash Bin',
                subtitle:
                    '${trashFiles.length} items • Auto-clears after 30 days',
                actions: trashFiles.isNotEmpty
                    ? [
                        TextButton.icon(
                          onPressed: _confirmEmptyTrash,
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            'Empty',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ]
                    : null,
              ),
            ),

            // Info Banner
            if (trashFiles.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Trashed files can be restored. Swipe left to delete permanently.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
              ),

            // Files
            if (filesProvider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (trashFiles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 44,
                          color: AppColors.success,
                        ),
                      ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.elasticOut,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Trash is Empty',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleted items will appear here for recovery.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final file = trashFiles[index];
                    final catColor = FileHelper.getCategoryColor(file.category);
                    final catIcon = FileHelper.getCategoryIcon(file.category);

                    return Dismissible(
                      key: Key(file.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.error,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Delete Permanently?'),
                            content: Text(
                              '"${file.name}" will be gone forever.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (_) {
                        filesProvider.deletePermanently(file.id);
                        TopAlertBar.showTrash(
                          context,
                          '"${file.name}" permanently deleted',
                        );
                      },
                      child:
                          Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkCard
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: catColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        catIcon,
                                        color: catColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${FileHelper.formatBytes(file.size)} • ${FileHelper.timeAgo(file.createdAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.darkTextTertiary
                                                  : AppColors.lightTextTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Restore button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.restore_rounded,
                                        color: AppColors.success,
                                        size: 22,
                                      ),
                                      tooltip: 'Restore',
                                      onPressed: () async {
                                        final success = await filesProvider
                                            .restoreFile(file.id);
                                        if (mounted && success) {
                                          TopAlertBar.showSuccess(
                                            context,
                                            '"${file.name}" restored',
                                          );
                                        }
                                      },
                                    ),
                                    // Delete permanently
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_forever_rounded,
                                        color: AppColors.error,
                                        size: 22,
                                      ),
                                      tooltip: 'Delete Permanently',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: const Text(
                                              'Delete Forever?',
                                            ),
                                            content: Text(
                                              '"${file.name}" will be permanently removed.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.error,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await filesProvider.deletePermanently(
                                            file.id,
                                          );
                                          if (context.mounted) {
                                            TopAlertBar.showTrash(
                                              context,
                                              '"${file.name}" permanently deleted',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 200.ms, delay: (index * 40).ms)
                              .slideX(begin: 0.05),
                    );
                  }, childCount: trashFiles.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
