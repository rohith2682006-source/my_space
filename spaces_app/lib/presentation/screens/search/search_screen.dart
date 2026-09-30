import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/native_file_service.dart';
import '../../../providers/files_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/floating_header_bar.dart';
import '../../widgets/top_alert_bar.dart';
import '../spaces/space_detail_screen.dart';
import '../spaces/file_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    Provider.of<FilesProvider>(context, listen: false).search(query);
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
            // Floating Glass Header
            FloatingHeaderBar(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.saved_search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: 'Universal Search',
              subtitle: 'Spaces, files, notes, and links',
            ),

            // Floating Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xCC1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.08),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: false,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search files, spaces, notes, links...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _controller.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            // Results or Empty Placeholder
            Expanded(
              child: filesProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _controller.text.trim().isEmpty
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
                              Icons.manage_search_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Store it once. Find it instantly.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Search anything by file name, note text, or space name',
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
                  : (filesProvider.searchedSpaces.isEmpty &&
                        filesProvider.searchedFiles.isEmpty)
                  ? Center(
                      child: Text(
                        'No results found for "${_controller.text}"',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Matched Spaces
                        if (filesProvider.searchedSpaces.isNotEmpty) ...[
                          const Text(
                            'SPACES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...filesProvider.searchedSpaces.map((space) {
                            return ListTile(
                              leading: Text(
                                space.icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                              title: Text(
                                space.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text('${space.fileCount} files'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SpaceDetailScreen(space: space),
                                  ),
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 20),
                        ],

                        // Matched Files
                        if (filesProvider.searchedFiles.isNotEmpty) ...[
                          const Text(
                            'FILES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...filesProvider.searchedFiles.map((file) {
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
                              onActionSelected: (action) {
                                if (action == 'open') {
                                  NativeFileService.openFileWithNativeApp(
                                    context,
                                    file,
                                  );
                                } else if (action == 'share' ||
                                    action == 'share_file') {
                                  NativeFileService.shareOriginalFile(
                                    context,
                                    file,
                                  );
                                } else if (action == 'share_link') {
                                  NativeFileService.shareSecureLink(
                                    context,
                                    file,
                                  );
                                } else if (action == 'download') {
                                  NativeFileService.downloadOriginalFile(
                                    context,
                                    file,
                                  );
                                } else if (action == 'trash') {
                                  filesProvider.trashFile(file.id);
                                  TopAlertBar.showTrash(
                                    context,
                                    '"${file.name}" moved to Trash',
                                    onUndo: () => filesProvider.restoreFile(file.id),
                                  );
                                } else if (action == 'reindex') {
                                  filesProvider.reindexDocument(file.id);
                                }
                              },
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
