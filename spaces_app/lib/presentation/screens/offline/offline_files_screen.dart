import 'package:flutter/material.dart';
import '../../widgets/unified_back_button.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/file_model.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/top_alert_bar.dart';

class OfflineFilesScreen extends StatefulWidget {
  const OfflineFilesScreen({super.key});

  @override
  State<OfflineFilesScreen> createState() => _OfflineFilesScreenState();
}

class _OfflineFilesScreenState extends State<OfflineFilesScreen> {
  List<FileModel> _pinnedFiles = [];
  bool _isLoading = true;
  int _pendingActions = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final files = await OfflineCacheService.instance.getAllPinnedFiles();
    final pending = await OfflineCacheService.instance.pendingActionsCount();
    if (!mounted) return;
    setState(() {
      _pinnedFiles = files;
      _pendingActions = pending;
      _isLoading = false;
    });
  }

  Future<void> _unpinFile(FileModel file) async {
    await OfflineCacheService.instance.toggleFilePin(file.id, false);
    if (mounted) {
      setState(() => _pinnedFiles.removeWhere((f) => f.id == file.id));
      TopAlertBar.showInfo(context, '"${file.name}" removed from offline storage');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor =
        isDark ? Colors.white12 : Colors.black.withOpacity(0.08);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Offline Files',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: UnifiedBackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // Pending sync banner
                  if (_pendingActions > 0)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sync_rounded,
                                color: AppColors.warning, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$_pendingActions action(s) waiting to sync when you reconnect',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Stats row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          _buildStatChip(
                            '${_pinnedFiles.length}',
                            'Files Offline',
                            Icons.download_done_rounded,
                            AppColors.primary,
                            cardColor,
                            textPrimary,
                            textSecondary,
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            _pendingActions.toString(),
                            'Pending Sync',
                            Icons.cloud_sync_rounded,
                            _pendingActions > 0
                                ? AppColors.warning
                                : AppColors.success,
                            cardColor,
                            textPrimary,
                            textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Info header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        _pinnedFiles.isEmpty
                            ? ''
                            : 'Pinned files are available even without internet',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Files list
                  _pinnedFiles.isEmpty
                      ? SliverFillRemaining(child: _buildEmpty(textSecondary))
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final file = _pinnedFiles[i];
                                return Dismissible(
                                  key: ValueKey(file.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.wifi_off_rounded,
                                        color: AppColors.error),
                                  ),
                                  onDismissed: (_) => _unpinFile(file),
                                  child: FileListItem(
                                    file: file,
                                    onTap: () {},
                                    onFavoriteToggle: () {},
                                    onActionSelected: (action) {
                                      if (action == 'remove_offline') {
                                        _unpinFile(file);
                                      }
                                    },
                                  ),
                                );
                              },
                              childCount: _pinnedFiles.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatChip(
    String value,
    String label,
    IconData icon,
    Color accentColor,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: accentColor),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: textSecondary),
            const SizedBox(height: 20),
            Text(
              'No Offline Files',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pin files for offline access by long-pressing them in any Space.\nPinned files are available even without internet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
