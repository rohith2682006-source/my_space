import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_helper.dart';
import '../../../providers/files_provider.dart';
import '../../widgets/floating_header_bar.dart';
import '../plans/plans_screen.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  void _loadStorageData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fp = Provider.of<FilesProvider>(context, listen: false);
      fp.fetchStorageStats();
      fp.fetchTrash();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filesProvider = Provider.of<FilesProvider>(context);
    final stats = filesProvider.storageStats;

    final totalUsed = stats != null ? FileHelper.formatBytes(stats.totalUsedBytes) : '0 B';
    final storageLimit = stats != null ? FileHelper.formatBytes(stats.storageLimitBytes) : '5 GB';
    final usagePercent = stats?.usagePercentage ?? 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FloatingHeaderBar(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: AppColors.accent, size: 20),
              ),
              title: 'Storage & Analytics',
              subtitle: '$totalUsed of $storageLimit used',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _loadStorageData(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              // Storage Gauge Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cloud Storage',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Free Plan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (usagePercent / 100).clamp(0.01, 1.0),
                        minHeight: 10,
                        backgroundColor: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$totalUsed of $storageLimit used',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '${usagePercent.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Category Breakdown Title
              const Text(
                'STORAGE BREAKDOWN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),

              // Categories Grid
              if (stats != null) ...[
                _buildCategoryRow('Documents', stats.breakdown['documents'], AppColors.catDocument, Icons.description_rounded),
                _buildCategoryRow('Images', stats.breakdown['images'], AppColors.catImage, Icons.image_rounded),
                _buildCategoryRow('Videos', stats.breakdown['videos'], AppColors.catVideo, Icons.videocam_rounded),
                _buildCategoryRow('Audio', stats.breakdown['audio'], AppColors.catAudio, Icons.audiotrack_rounded),
                _buildCategoryRow('Notes', stats.breakdown['notes'], AppColors.catNote, Icons.edit_note_rounded),
                _buildCategoryRow('Links', stats.breakdown['links'], AppColors.catLink, Icons.link_rounded),
                _buildCategoryRow('Archives & Other', stats.breakdown['archives'], AppColors.catArchive, Icons.folder_zip_rounded),
              ],

              const SizedBox(height: 28),

              // Trash Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TRASH & RECOVERY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    'Retained 30 Days',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (filesProvider.trashFiles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          size: 32,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trash is empty',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filesProvider.trashFiles.map((file) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FileHelper.getCategoryIcon(file.category),
                          color: FileHelper.getCategoryColor(file.category),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${FileHelper.formatBytes(file.size)} • ${file.daysRemaining ?? 30} days left',
                                style: const TextStyle(fontSize: 11, color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.restore_from_trash_rounded, size: 20),
                          tooltip: 'Restore',
                          onPressed: () async {
                            await filesProvider.restoreFile(file.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('File restored')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
                          tooltip: 'Delete Forever',
                          onPressed: () async {
                            await filesProvider.deletePermanently(file.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Permanently deleted')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 28),

              // Upgrade Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade to Spaces Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get 500 GB storage, AI semantic search, version history, and unlimited collaboration.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PlansScreen()),
                        );
                      },
                      child: const Text('View Plans'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ],
  ),
),
);
}

  Widget _buildCategoryRow(String title, String? bytes, Color color, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formatted = FileHelper.formatBytes(bytes);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
