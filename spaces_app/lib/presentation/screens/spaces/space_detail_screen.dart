import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/utils/desktop_integration.dart';
import '../../../core/services/native_file_service.dart';
import '../../../data/models/space_model.dart';
import '../../../data/models/file_model.dart';
import '../../../providers/files_provider.dart';
import '../../../providers/spaces_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/quick_add_sheet.dart';
import '../../widgets/top_alert_bar.dart';
import '../sharing/share_dialog.dart';
import 'file_detail_screen.dart';

class SpaceDetailScreen extends StatefulWidget {
  final SpaceModel space;

  const SpaceDetailScreen({super.key, required this.space});

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final String _sortBy = 'createdAt';
  final String _order = 'desc';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'label': 'All', 'value': 'ALL'},
    {'label': 'Documents', 'value': 'DOCUMENT'},
    {'label': 'Images', 'value': 'IMAGE'},
    {'label': 'Videos', 'value': 'VIDEO'},
    {'label': 'Notes', 'value': 'NOTE'},
    {'label': 'Links', 'value': 'LINK'},
    {'label': 'Archives', 'value': 'ARCHIVE'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFiles() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FilesProvider>(context, listen: false).fetchFilesInSpace(
        widget.space.id,
        category: _selectedCategory,
        search: _searchQuery,
        sortBy: _sortBy,
        order: _order,
      );
    });
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final validFiles = result.files.where((f) => f.bytes != null).toList();
      if (validFiles.isEmpty) return;

      final filesProvider = Provider.of<FilesProvider>(context, listen: false);

      if (validFiles.length == 1) {
        final file = validFiles.first;
        final success = await filesProvider.uploadFile(
          spaceId: widget.space.id,
          bytes: file.bytes!,
          filename: file.name,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Uploaded "${file.name}"'
                    : (filesProvider.errorMessage ?? 'Upload failed'),
              ),
              backgroundColor: success ? AppColors.success : AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        // Multi-file batch upload
        final items = validFiles
            .map((f) => UploadItem(filename: f.name, bytes: f.bytes!))
            .toList();

        final uploadedCount = await filesProvider.uploadMultipleFiles(
          spaceId: widget.space.id,
          items: items,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Uploaded $uploadedCount of ${validFiles.length} files to ${widget.space.name}',
              ),
              backgroundColor: uploadedCount > 0
                  ? AppColors.success
                  : AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _showCreateNoteDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Note Title',
                hintText: 'e.g. DBMS Lecture Notes',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Note Content',
                hintText: 'Write in markdown or plain text...',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isNotEmpty) {
                final filesProvider = Provider.of<FilesProvider>(
                  context,
                  listen: false,
                );
                await filesProvider.createNoteOrLink(
                  spaceId: widget.space.id,
                  name: titleController.text.trim(),
                  type: 'NOTE',
                  content: contentController.text.trim(),
                );
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showAddLinkDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title / Label',
                hintText: 'e.g. Course Portal',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isNotEmpty &&
                  urlController.text.trim().isNotEmpty) {
                final filesProvider = Provider.of<FilesProvider>(
                  context,
                  listen: false,
                );
                await filesProvider.createNoteOrLink(
                  spaceId: widget.space.id,
                  name: titleController.text.trim(),
                  type: 'LINK',
                  content: urlController.text.trim(),
                );
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save Link'),
          ),
        ],
      ),
    );
  }

  void _showQuickAdd() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickAddSheet(
        onUploadFile: _pickAndUploadFile,
        onCreateNote: _showCreateNoteDialog,
        onAddLink: _showAddLinkDialog,
      ),
    );
  }

  void _showShareDialog() {
    DesktopIntegration.shareViaDesktopApps(
      context,
      title: widget.space.name,
      text: 'Access "${widget.space.name}" on Spaces',
      shareUrl:
          '${ApiEndpoints.baseUrl.replaceAll('/api/v1', '')}/shared/space/${widget.space.id}',
    );
  }

  void _handleFileAction(String action, FileModel file) async {
    final filesProvider = Provider.of<FilesProvider>(context, listen: false);

    switch (action) {
      case 'open':
        NativeFileService.openFileWithNativeApp(context, file);
        break;
      case 'share':
      case 'share_file':
        NativeFileService.shareOriginalFile(context, file);
        break;
      case 'share_link':
        NativeFileService.shareSecureLink(context, file);
        break;
      case 'download':
        NativeFileService.downloadOriginalFile(context, file);
        break;
      case 'rename':
        _showRenameDialog(file);
        break;
      case 'move':
        _showMoveDialog(file);
        break;
      case 'trash':
        final success = await filesProvider.trashFile(file.id);
        if (mounted && success) {
          TopAlertBar.showTrash(
            context,
            '"${file.name}" moved to Trash',
            onUndo: () => filesProvider.restoreFile(file.id),
          );
        }
        break;
      case 'reindex':
        await filesProvider.reindexDocument(file.id);
        break;
    }
  }

  void _showMoveDialog(FileModel file) {
    final spacesProvider = Provider.of<SpacesProvider>(context, listen: false);
    final targetSpaces =
        spacesProvider.spaces.where((s) => s.id != widget.space.id).toList();

    if (targetSpaces.isEmpty) {
      TopAlertBar.showInfo(context, 'No other spaces available to move to');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Space'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targetSpaces.length,
            itemBuilder: (_, i) {
              final sp = targetSpaces[i];
              return ListTile(
                leading: const Icon(Icons.folder_rounded),
                title: Text(sp.name),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await Provider.of<FilesProvider>(
                    context,
                    listen: false,
                  ).moveFile(file.id, sp.id);
                  if (mounted && success) {
                    TopAlertBar.showSuccess(
                      context,
                      'Moved "${file.name}" to ${sp.name}',
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileModel file) {
    final controller = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await Provider.of<FilesProvider>(
                  context,
                  listen: false,
                ).renameFile(file.id, newName);
                if (mounted) {
                  Navigator.pop(ctx);
                  TopAlertBar.showSuccess(context, 'Renamed to "$newName"');
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spaceColor = _parseHex(widget.space.color);
    final filesProvider = Provider.of<FilesProvider>(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible Space Header
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Space',
                onPressed: _showShareDialog,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More options',
                onSelected: (val) async {
                  if (val == 'advanced_share') {
                    showDialog(
                      context: context,
                      builder: (_) => ShareDialog(space: widget.space),
                    );
                  } else if (val == 'delete_space') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Delete this Space?'),
                        content: Text(
                          'Are you sure you want to delete "${widget.space.name}" and all of its files?',
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
                    if (confirm == true && mounted) {
                      await Provider.of<SpacesProvider>(
                        context,
                        listen: false,
                      ).deleteSpace(widget.space.id);
                      if (mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'advanced_share',
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Share Link Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete_space',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete Space',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: 56,
                bottom: 16,
                right: 16,
              ),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: spaceColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.space.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.space.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      spaceColor.withOpacity(isDark ? 0.3 : 0.15),
                      isDark ? AppColors.darkBackground : Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // Search & Filter Toolbar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Floating Search Bar inside space
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xCC1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.black.withOpacity(0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        _searchQuery = val;
                        _loadFiles();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search in ${widget.space.name}...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _loadFiles();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category Filter Chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final cat = _categories[idx];
                        final isSelected = _selectedCategory == cat['value'];
                        return FilterChip(
                          label: Text(cat['label']!),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat['value']!);
                            _loadFiles();
                          },
                          backgroundColor: isDark
                              ? AppColors.darkCard
                              : const Color(0xFFF1F5F9),
                          selectedColor: spaceColor.withOpacity(0.2),
                          checkmarkColor: spaceColor,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? spaceColor
                                : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? spaceColor
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Uploading banner if active
          if (filesProvider.isUploading)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Uploading to Space...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Files List / Empty State
          if (filesProvider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filesProvider.files.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: spaceColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.folder_open_rounded,
                          size: 36,
                          color: spaceColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No matches found'
                            : 'Nothing here yet',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try searching with another keyword'
                            : 'Add files, notes, or links to keep everything together.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Content'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: spaceColor,
                        ),
                        onPressed: _showQuickAdd,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final file = filesProvider.files[index];
                  return FileListItem(
                    file: file,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FileDetailScreen(file: file),
                      ),
                    ),
                    onFavoriteToggle: () => filesProvider.toggleFavorite(file),
                    onActionSelected: (act) => _handleFileAction(act, file),
                  );
                }, childCount: filesProvider.files.length),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickAdd,
        backgroundColor: spaceColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
