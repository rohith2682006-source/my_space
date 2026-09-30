import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/sharing_provider.dart';
import '../../../data/models/share_link_model.dart';

import '../../widgets/floating_header_bar.dart';
import '../../widgets/top_alert_bar.dart';

class MyLinksScreen extends StatefulWidget {
  const MyLinksScreen({super.key});

  @override
  State<MyLinksScreen> createState() => _MyLinksScreenState();
}

class _MyLinksScreenState extends State<MyLinksScreen> {
  String? _recentlyCopiedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SharingProvider>(context, listen: false).fetchMyLinks();
    });
  }

  void _copyLink(ShareLinkModel link) {
    Clipboard.setData(ClipboardData(text: link.shareUrl));
    setState(() => _recentlyCopiedId = link.id);
    TopAlertBar.showSuccess(context, 'Copied link for "${link.targetName}"');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _recentlyCopiedId = null);
    });
  }

  void _revokeLink(ShareLinkModel link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revoke Share Link?'),
        content: Text(
          'Anyone with this link will immediately lose access to "${link.targetName}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await Provider.of<SharingProvider>(context, listen: false).revokeLink(link.id);
      if (mounted) {
        if (success) {
          TopAlertBar.showTrash(context, 'Share link revoked');
        } else {
          TopAlertBar.showError(context, 'Failed to revoke link');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sharingProvider = Provider.of<SharingProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FloatingHeaderBar(
              showBackButton: true,
              title: 'My Share Links',
              subtitle: 'Active live shareable links',
              actions: [
                HeaderActionButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onTap: () => sharingProvider.fetchMyLinks(),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => sharingProvider.fetchMyLinks(),
                child: sharingProvider.isLoading && sharingProvider.myLinks.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : sharingProvider.myLinks.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: sharingProvider.myLinks.length,
                            itemBuilder: (context, index) {
                              final link = sharingProvider.myLinks[index];
                              return _buildLinkCard(link, isDark);
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
                child: Icon(Icons.link_rounded, size: 36, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No active share links',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'When you share files or spaces, you can track views, downloads, and manage security settings right here.',
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

  Widget _buildLinkCard(ShareLinkModel link, bool isDark) {
    final isCopied = _recentlyCopiedId == link.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withOpacity(0.85) : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder.withOpacity(0.6) : AppColors.lightBorder.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Target Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: link.targetType == 'space'
                        ? const Color(0xFF6366F1).withOpacity(0.12)
                        : AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      link.targetIcon ?? (link.targetType == 'space' ? '📁' : '📄'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Target Name and Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.targetName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              link.permission,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          if (link.hasPassword) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            link.targetType == 'space' ? 'Space Link' : 'File Link',
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
                // Revoke button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                  tooltip: 'Revoke link',
                  onPressed: () => _revokeLink(link),
                ),
              ],
            ),
            const Divider(height: 24),
            // URL Display & Copy
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      link.shareUrl,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _copyLink(link),
                  icon: Icon(
                    isCopied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 16,
                  ),
                  label: Text(isCopied ? 'Copied' : 'Copy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCopied ? AppColors.success : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Download / Views Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.download_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      link.maxDownloads != null
                          ? '${link.downloadCount} / ${link.maxDownloads} downloads'
                          : '${link.downloadCount} downloads',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  link.expiresAt != null
                      ? (link.isExpired ? 'Expired' : 'Expires in ${_formatDaysRemaining(link.expiresAt!)}')
                      : 'Never expires',
                  style: TextStyle(
                    fontSize: 11,
                    color: link.isExpired ? AppColors.error : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    fontWeight: link.isExpired ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDaysRemaining(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.inDays > 1) return '${diff.inDays} days';
    if (diff.inHours > 1) return '${diff.inHours} hours';
    return '${diff.inMinutes} minutes';
  }
}
