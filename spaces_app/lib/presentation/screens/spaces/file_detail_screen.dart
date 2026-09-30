import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/native_file_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../data/models/file_model.dart';
import '../../../providers/files_provider.dart';
import '../../screens/search/deep_search_screen.dart';
import '../../widgets/top_alert_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────

class FileDetailScreen extends StatefulWidget {
  final FileModel file;
  const FileDetailScreen({super.key, required this.file});

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  late FileModel _file;
  bool _togglingAi = false;
  Timer? _pollTimer;
  StreamSubscription<RealtimeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _file = widget.file;

    // Listen to real-time events for this file
    _realtimeSub = RealtimeService.instance.events.listen((event) {
      if (!mounted) return;
      final eventFileId = event.data['fileId']?.toString();
      if (eventFileId != _file.id) return;

      if (event.event == 'FILE_RENAMED') {
        final newName = event.data['newName']?.toString();
        if (newName != null) {
          setState(() => _file = _file.copyWith(name: newName));
        }
      } else if (event.event == 'FILE_AI_ACCESS_CHANGED') {
        final enabled = event.data['aiSearchEnabled'] == true;
        final status =
            event.data['indexStatus']?.toString() ?? _file.indexStatus;
        setState(() =>
            _file = _file.copyWith(aiSearchEnabled: enabled, indexStatus: status));
      } else if (event.event == 'AI_READY' || event.event == 'AI_FAILED') {
        final status = event.data['status']?.toString() ??
            (event.event == 'AI_READY' ? 'READY' : 'FAILED');
        setState(() => _file = _file.copyWith(indexStatus: status));
        _pollTimer?.cancel();
      } else if (event.event == 'FILE_DELETED') {
        Navigator.pop(context);
      }
    });

    // Poll for index status if INDEXING or QUEUED
    if (_file.indexStatus == 'INDEXING' || _file.indexStatus == 'QUEUED') {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _refreshIndexStatus();
    });
  }

  Future<void> _refreshIndexStatus() async {
    try {
      final resp = await ApiClient.get(
        ApiEndpoints.aiDocumentIndexStatus(_file.id),
      );
      if (!mounted || !resp.success || resp.data == null) return;
      final data = resp.data as Map<String, dynamic>;
      final status = data['indexStatus'] as String? ?? _file.indexStatus;
      setState(() {
        _file = _file.copyWith(indexStatus: status);
      });
      if (status == 'READY' || status == 'FAILED' || status == 'NOT_INDEXED') {
        _pollTimer?.cancel();
      }
    } catch (_) {}
  }

  Future<void> _toggleAiAccess(bool enable) async {
    if (_togglingAi) return;
    setState(() => _togglingAi = true);
    try {
      final resp = await ApiClient.patch(
        ApiEndpoints.fileAiAccess(_file.id),
        body: {'enabled': enable},
      );
      if (!mounted) return;
      if (!resp.success) {
        throw Exception(resp.message ?? 'Failed to update AI access');
      }
      setState(() {
        _file = _file.copyWith(
          aiSearchEnabled: enable,
          indexStatus: enable ? 'QUEUED' : _file.indexStatus,
        );
      });
      if (enable) _startPolling();
      TopAlertBar.showSuccess(
        context,
        enable ? 'AI Search enabled — indexing document' : 'AI Search disabled',
      );
    } catch (e) {
      if (!mounted) return;
      TopAlertBar.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _togglingAi = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _file.name,
          style: TextStyle(
              color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Deep Search with this file
          if (_file.aiSearchEnabled && _file.indexStatus == 'READY')
            IconButton(
              icon: ShaderMask(
                shaderCallback: (b) =>
                    AppColors.primaryGradient.createShader(b),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 22),
              ),
              tooltip: 'Deep Search this file',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeepSearchScreen(
                    initialQuery: 'Summarize ${_file.name}',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File icon hero
            _buildFileHero(isDark),
            const SizedBox(height: 24),
            // AI Access card
            _buildAiAccessCard(isDark),
            const SizedBox(height: 20),
            // File info card
            _buildInfoCard(isDark),
            const SizedBox(height: 20),
            // Actions
            _buildActions(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFileHero(bool isDark) {
    final color = _fileTypeColor;
    final icon = _fileTypeIcon;
    return Center(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withAlpha(80), width: 2),
            ),
            child: Icon(icon, color: color, size: 44),
          ),
          const SizedBox(height: 12),
          Text(
            _file.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatSize(_file.size),
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAccessCard(bool isDark) {
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final bool isIndexable = _isIndexable;
    final statusInfo = _indexStatusInfo;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _file.aiSearchEnabled
              ? AppColors.primary.withAlpha(100)
              : border,
        ),
        boxShadow: _file.aiSearchEnabled
            ? [
                BoxShadow(
                    color: AppColors.primary.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppColors.primaryGradient.createShader(b),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Search',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isIndexable
                          ? 'Enable to search this file with AI'
                          : 'This file type is not supported for AI Search',
                      style:
                          TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isIndexable)
                _togglingAi
                    ? const SizedBox(
                        width: 36,
                        height: 20,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : Switch(
                        value: _file.aiSearchEnabled,
                        onChanged: _toggleAiAccess,
                        activeColor: AppColors.primary,
                      ),
            ],
          ),

          if (isIndexable && _file.aiSearchEnabled) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Index status row
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusInfo.color,
                    shape: BoxShape.circle,
                    boxShadow: statusInfo.pulse
                        ? [
                            BoxShadow(
                              color: statusInfo.color.withAlpha(120),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusInfo.label,
                  style: TextStyle(
                    color: statusInfo.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (statusInfo.pulse)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            if (_file.indexStatus == 'FAILED') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Indexing failed. Try disabling and re-enabling AI Search.',
                      style:
                          TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (_file.indexStatus == 'READY') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DeepSearchScreen(
                            initialQuery:
                                'Summarize ${_file.name}')),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Deep Search this file'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File Info',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _infoRow('Type', _file.extension.toUpperCase(), textPrimary,
              textSecondary),
          _infoRow('Size', _formatSize(_file.size), textPrimary, textSecondary),
          _infoRow('Uploaded', _formatDate(_file.createdAt), textPrimary,
              textSecondary),
          _infoRow('Modified', _formatDate(_file.updatedAt), textPrimary,
              textSecondary),
        ],
      ),
    );
  }

  Widget _infoRow(
      String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _actionTile(
            icon: Icons.launch_rounded,
            label: 'Open File',
            subtitle: 'Open with default system application',
            color: AppColors.primary,
            onTap: () => NativeFileService.openFileWithNativeApp(context, _file),
          ),
          const Divider(height: 1),
          _actionTile(
            icon: Icons.share_rounded,
            label: 'Share File',
            subtitle: 'Send original file to apps (WhatsApp, Telegram, etc.)',
            color: AppColors.primary,
            onTap: () => NativeFileService.shareOriginalFile(context, _file),
          ),
          const Divider(height: 1),
          _actionTile(
            icon: Icons.link_rounded,
            label: 'Share Link',
            subtitle: 'Generate and send a secure share link',
            color: AppColors.primary,
            onTap: () => NativeFileService.shareSecureLink(context, _file),
          ),
          const Divider(height: 1),
          _actionTile(
            icon: Icons.download_rounded,
            label: 'Download',
            subtitle: 'Save a local copy to device Downloads',
            color: AppColors.primary,
            onTap: () => NativeFileService.downloadOriginalFile(context, _file),
          ),
          const Divider(height: 1),
          _actionTile(
            icon: Icons.edit_rounded,
            label: 'Rename',
            color: AppColors.primary,
            onTap: () => _showRenameDialog(),
          ),
          const Divider(height: 1),
          _actionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Move to Trash',
            color: AppColors.error,
            onTap: () async {
              final filesProvider =
                  Provider.of<FilesProvider>(context, listen: false);
              final success = await filesProvider.trashFile(_file.id);
              if (mounted && success) {
                Navigator.pop(context);
                TopAlertBar.showTrash(
                  context,
                  '"${_file.name}" moved to Trash',
                  onUndo: () => filesProvider.restoreFile(_file.id),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _file.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new filename'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _file.name) {
                final filesProvider =
                    Provider.of<FilesProvider>(context, listen: false);
                final success = await filesProvider.renameFile(_file.id, newName);
                if (mounted && success) {
                  setState(() => _file = _file.copyWith(name: newName));
                  Navigator.pop(ctx);
                  TopAlertBar.showSuccess(context, 'Renamed to "$newName"');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.6), size: 18),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color get _fileTypeColor {
    switch (_file.extension.toLowerCase()) {
      case 'pdf':
        return AppColors.catDocument;
      case 'docx':
      case 'doc':
        return AppColors.catNote;
      case 'txt':
      case 'md':
      case 'markdown':
        return AppColors.catCode;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return AppColors.catImage;
      default:
        return AppColors.catOther;
    }
  }

  IconData get _fileTypeIcon {
    switch (_file.extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      case 'txt':
      case 'md':
        return Icons.article_rounded;
      case 'png':
      case 'jpg':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  bool get _isIndexable {
    const indexable = {'pdf', 'docx', 'doc', 'txt', 'md', 'markdown'};
    return indexable.contains(_file.extension.toLowerCase());
  }

  _IndexStatusInfo get _indexStatusInfo {
    switch (_file.indexStatus) {
      case 'READY':
        return _IndexStatusInfo(
            label: 'AI Ready — Searchable', color: AppColors.success);
      case 'INDEXING':
        return _IndexStatusInfo(
            label: 'Indexing…', color: AppColors.primary, pulse: true);
      case 'QUEUED':
        return _IndexStatusInfo(
            label: 'Queued for indexing', color: AppColors.warning, pulse: true);
      case 'PROCESSING':
        return _IndexStatusInfo(
            label: 'Processing…', color: AppColors.primary, pulse: true);
      case 'FAILED':
        return _IndexStatusInfo(
            label: 'Indexing failed', color: AppColors.error);
      case 'OCR_REQUIRED':
        return _IndexStatusInfo(
            label: 'OCR required — not searchable', color: AppColors.warning);
      default:
        return _IndexStatusInfo(
            label: 'Not indexed', color: AppColors.darkTextTertiary);
    }
  }

  String _formatSize(String sizeStr) {
    final bytes = int.tryParse(sizeStr) ?? 0;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _IndexStatusInfo {
  final String label;
  final Color color;
  final bool pulse;
  const _IndexStatusInfo(
      {required this.label, required this.color, this.pulse = false});
}

