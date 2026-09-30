import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/activity_provider.dart';
import '../../../data/models/activity_model.dart';
import '../../widgets/floating_header_bar.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ActivityProvider>(context, listen: false).fetchActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activityProvider = Provider.of<ActivityProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FloatingHeaderBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: 'Activity Feed',
              subtitle: 'Real-time audit log & timeline',
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () => activityProvider.fetchActivities(),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => activityProvider.fetchActivities(),
                child: activityProvider.isLoading && activityProvider.activities.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : activityProvider.activities.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: activityProvider.activities.length,
                    itemBuilder: (context, index) {
                      final item = activityProvider.activities[index];
                      return _buildActivityTile(item, isDark);
                    },
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              child: const Center(
                child: Icon(Icons.bolt_rounded, size: 36, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No activities yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your uploads, edits, shares, and space modifications will appear here in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(ActivityModel item, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  item.iconEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.actionDescription,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.spaceName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.spaceIcon ?? '📁'} ${item.spaceName}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatTimestamp(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}
