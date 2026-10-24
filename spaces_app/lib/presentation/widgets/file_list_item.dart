import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../data/models/file_model.dart';

class FileListItem extends StatelessWidget {
  final FileModel file;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final void Function(String action)? onActionSelected;
  final bool showSpaceBadge;

  const FileListItem({
    super.key,
    required this.file,
    required this.onTap,
    required this.onFavoriteToggle,
    this.onActionSelected,
    this.showSpaceBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catColor = FileHelper.getCategoryColor(file.category);
    final catIcon = FileHelper.getCategoryIcon(file.category);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white)
                    .withValues(alpha: isDark ? 0.22 : 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Category Icon Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(catIcon, color: catColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  // Name & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              FileHelper.formatBytes(file.size),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '•',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              FileHelper.timeAgo(file.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary,
                              ),
                            ),
                            if (showSpaceBadge && file.space != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  file.space!.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                            if (_isIndexable(file)) ...[
                              const SizedBox(width: 10),
                              _buildIndexStatus(file),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Star Button
                  IconButton(
                    icon: Icon(
                      file.isStarred
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: file.isStarred
                          ? Colors.amber
                          : (isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary),
                      size: 22,
                    ),
                    onPressed: onFavoriteToggle,
                  ),
                  // More Menu
                  if (onActionSelected != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                        size: 20,
                      ),
                      onSelected: onActionSelected,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.launch_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Open File'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share_file',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Share File'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Download'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'move',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_move_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Move to Space'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'versions',
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Version History'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'trash',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Move to Trash',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isIndexable(FileModel file) => const {
    'pdf',
    'pptx',
    'ppt',
    'docx',
    'doc',
    'txt',
    'md',
    'markdown',
    'csv',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'mp4',
    'webm',
    'mov',
    'mp3',
    'wav',
    'm4a',
  }.contains(file.extension.toLowerCase());

  Widget _buildIndexStatus(FileModel file) {
    final status = file.indexStatus.toUpperCase();
    final (label, icon, color) = switch (status) {
      'READY' => (
        'Ready',
        Icons.check_circle_outline_rounded,
        AppColors.success,
      ),
      'PROCESSING' || 'INDEXING' || 'UPLOADING' => (
        'Indexing',
        Icons.hourglass_top_rounded,
        AppColors.primary,
      ),
      'PENDING' || 'QUEUED' => (
        'Pending',
        Icons.schedule_rounded,
        AppColors.lightTextSecondary,
      ),
      'OCR_REQUIRED' => (
        'OCR required',
        Icons.document_scanner_outlined,
        AppColors.warning,
      ),
      'FAILED' => ('Retry', Icons.refresh_rounded, AppColors.error),
      _ => ('Index', Icons.search_rounded, AppColors.lightTextSecondary),
    };
    final retryable = status == 'FAILED' || status == 'NOT_INDEXED';


    return Tooltip(
      message: file.indexError ?? 'Index status: $label',
      child: InkWell(
        onTap: retryable ? () => onActionSelected?.call('reindex') : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'PROCESSING' ||
                  status == 'INDEXING' ||
                  status == 'UPLOADING')
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
