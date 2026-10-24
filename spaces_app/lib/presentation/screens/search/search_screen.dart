import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/unified_back_button.dart';
import '../../widgets/ambient_background.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/native_file_service.dart';
import '../../../providers/files_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/top_alert_bar.dart';
import '../spaces/space_detail_screen.dart';
import '../spaces/file_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSearchChanged(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        Provider.of<FilesProvider>(context, listen: false).search(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filesProvider = Provider.of<FilesProvider>(context);

    return AmbientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar (No border)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    const UnifiedBackButton(),
                    const SizedBox(width: 8),
                    Text(
                      'Universal search',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Search Input Field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF130B2A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : AppColors.lightBorder,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.06,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 24,
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                autofocus: false,
                                onChanged: _onSearchChanged,
                                onSubmitted: (val) {
                                  _debounce?.cancel();
                                  Provider.of<FilesProvider>(
                                    context,
                                    listen: false,
                                  ).search(val);
                                },
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search files, spaces, notes, links...',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                    fontSize: 15.5,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (_controller.text.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  _controller.clear();
                                  _onSearchChanged('');
                                },
                              ),
                          ],
                        ),
                      ),
              ),

              // Results or Empty Placeholder
              Expanded(
                child: filesProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _controller.text.trim().isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF130B2A)
                                : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.18)
                                      : AppColors.lightBorder,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.manage_search_rounded,
                                      size: 36,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Store it once. Find it instantly.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Search anything by file name, note text, or space name',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
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
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
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
                                    onUndo: () =>
                                        filesProvider.restoreFile(file.id),
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
    ),
  );
}
}
