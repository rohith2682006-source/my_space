import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/native_file_service.dart';
import '../../../data/models/file_model.dart';
import '../../../providers/files_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/floating_header_bar.dart';
import '../../widgets/top_alert_bar.dart';
import '../spaces/file_detail_screen.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FilesProvider>(context, listen: false).fetchRecent();
    });
  }

  void _handleFileAction(String action, FileModel file) {
    if (action == 'open') {
      NativeFileService.openFileWithNativeApp(context, file);
    } else if (action == 'share' || action == 'share_file') {
      NativeFileService.shareOriginalFile(context, file);
    } else if (action == 'share_link') {
      NativeFileService.shareSecureLink(context, file);
    } else if (action == 'download') {
      NativeFileService.downloadOriginalFile(context, file);
    } else if (action == 'trash') {
      final filesProvider = Provider.of<FilesProvider>(context, listen: false);
      filesProvider.trashFile(file.id);
      TopAlertBar.showTrash(
        context,
        '"${file.name}" moved to Trash',
        onUndo: () => filesProvider.restoreFile(file.id),
      );
    } else if (action == 'reindex') {
      Provider.of<FilesProvider>(
        context,
        listen: false,
      ).reindexDocument(file.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filesProvider = Provider.of<FilesProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FloatingHeaderBar(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: 'Recent Activity',
              subtitle:
                  '${filesProvider.recentFiles.length} recently opened files',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await filesProvider.fetchRecent();
                },
                child: filesProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filesProvider.recentFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No recent files',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Files you open or upload will show up here',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: filesProvider.recentFiles.length,
                        itemBuilder: (context, index) {
                          final file = filesProvider.recentFiles[index];
                          return FileListItem(
                            file: file,
                            showSpaceBadge: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FileDetailScreen(file: file),
                              ),
                            ),
                            onFavoriteToggle: () =>
                                filesProvider.toggleFavorite(file),
                            onActionSelected: (action) =>
                                _handleFileAction(action, file),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
