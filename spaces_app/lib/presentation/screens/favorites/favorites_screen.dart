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

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FilesProvider>(context, listen: false).fetchFavorites();
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
                  color: Colors.amber.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              title: 'Favorites',
              subtitle: '${filesProvider.favoriteFiles.length} starred items',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await filesProvider.fetchFavorites();
                },
                child: filesProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filesProvider.favoriteFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                size: 36,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No favorites yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Star important files to quickly access them here',
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
                        itemCount: filesProvider.favoriteFiles.length,
                        itemBuilder: (context, index) {
                          final file = filesProvider.favoriteFiles[index];
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
