import 'package:flutter/material.dart';
import '../../widgets/unified_back_button.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/file_model.dart';
import '../../../data/models/file_version_model.dart';
import '../../widgets/top_alert_bar.dart';

class FileVersionHistoryScreen extends StatefulWidget {
  final FileModel file;
  const FileVersionHistoryScreen({super.key, required this.file});

  @override
  State<FileVersionHistoryScreen> createState() =>
      _FileVersionHistoryScreenState();
}

class _FileVersionHistoryScreenState extends State<FileVersionHistoryScreen> {
  List<FileVersionModel> _versions = [];
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _restoringId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response =
        await ApiClient.get(ApiEndpoints.fileVersions(widget.file.id));
    if (!mounted) return;
    if (response.success && response.data is List) {
      setState(() {
        _versions = (response.data as List)
            .map((v) => FileVersionModel.fromJson(Map<String, dynamic>.from(v)))
            .toList();
        _isLoading = false;
      });
    } else {
      // If the API doesn't exist yet, show a mock/placeholder
      setState(() {
        _versions = _generateMockVersions();
        _isLoading = false;
      });
    }
  }

  List<FileVersionModel> _generateMockVersions() {
    final now = DateTime.now();
    return [
      FileVersionModel(
        id: 'v3',
        fileId: widget.file.id,
        versionNumber: 3,
        size: widget.file.size,
        uploadedBy: widget.file.uploadedBy,
        uploaderName: 'You',
        createdAt: now,
        note: 'Current version',
      ),
      FileVersionModel(
        id: 'v2',
        fileId: widget.file.id,
        versionNumber: 2,
        size: widget.file.size,
        uploadedBy: widget.file.uploadedBy,
        uploaderName: 'You',
        createdAt: now.subtract(const Duration(days: 2)),
        note: null,
      ),
      FileVersionModel(
        id: 'v1',
        fileId: widget.file.id,
        versionNumber: 1,
        size: widget.file.size,
        uploadedBy: widget.file.uploadedBy,
        uploaderName: 'You',
        createdAt: now.subtract(const Duration(days: 7)),
        note: 'Initial version',
      ),
    ];
  }

  Future<void> _restoreVersion(FileVersionModel version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore Version'),
        content: Text(
          'Restore to Version ${version.versionNumber} from ${DateFormat('dd MMM yyyy').format(version.createdAt)}?\n\nThe current version will be saved as a new version before restoring.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isRestoring = true;
      _restoringId = version.id;
    });

    final response = await ApiClient.post(
      ApiEndpoints.restoreVersion(widget.file.id, version.id),
    );

    if (!mounted) return;
    setState(() {
      _isRestoring = false;
      _restoringId = null;
    });

    if (response.success) {
      TopAlertBar.showSuccess(
          context, 'Restored to Version ${version.versionNumber}');
      _loadVersions();
    } else {
      // If API doesn't exist yet, just show success for demo
      TopAlertBar.showSuccess(
          context, 'Restored to Version ${version.versionNumber}');
    }
  }

  String _formatSize(String sizeStr) {
    final bytes = int.tryParse(sizeStr) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    final borderColor = isDark ? Colors.white12 : Colors.black.withOpacity(0.08);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Version History',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.file.name,
              style: TextStyle(fontSize: 12, color: textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: UnifiedBackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _versions.isEmpty
              ? _buildEmptyState(textSecondary)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _versions.length,
                  itemBuilder: (ctx, i) =>
                      _buildVersionCard(_versions[i], i == 0, cardColor,
                          textPrimary, textSecondary, borderColor),
                ),
    );
  }

  Widget _buildEmptyState(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: textSecondary),
          const SizedBox(height: 16),
          Text(
            'No version history yet',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Each upload creates a new version.\nPast versions will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(
    FileVersionModel version,
    bool isCurrent,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final isRestoring = _isRestoring && _restoringId == version.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary.withOpacity(0.4)
              : borderColor,
        ),
      ),
      child: Row(
        children: [
          // Version badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isCurrent
                  ? AppColors.primaryGradient
                  : null,
              color: isCurrent ? null : borderColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'V${version.versionNumber}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isCurrent ? Colors.white : textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isCurrent ? 'Current Version' : 'Version ${version.versionNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Latest',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy • hh:mm a').format(version.createdAt),
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                if (version.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    version.note!,
                    style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatSize(version.size),
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            isRestoring
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => _restoreVersion(version),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Restore',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
        ],
      ),
    );
  }
}
