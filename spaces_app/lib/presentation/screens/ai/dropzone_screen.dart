import 'package:flutter/material.dart';
import '../../widgets/unified_back_button.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/files_provider.dart';
import '../../../providers/spaces_provider.dart';
import '../../widgets/top_alert_bar.dart';

class DropzoneScreen extends StatefulWidget {
  const DropzoneScreen({super.key});

  @override
  State<DropzoneScreen> createState() => _DropzoneScreenState();
}

class _DropzoneScreenState extends State<DropzoneScreen>
    with TickerProviderStateMixin {
  final List<_DropzoneFile> _inbox = [];
  bool _isOrganizing = false;
  bool _organized = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      for (final f in result.files) {
        if (f.bytes != null) {
          _inbox.add(
            _DropzoneFile(
              name: f.name,
              size: f.size,
              bytes: f.bytes!,
              suggestedSpace: null,
              status: _FileStatus.pending,
            ),
          );
        }
      }
      _organized = false;
    });
  }

  Future<void> _organizeWithAi() async {
    if (_inbox.isEmpty) return;
    setState(() {
      _isOrganizing = true;
      _organized = false;
    });

    final spacesProvider = Provider.of<SpacesProvider>(context, listen: false);
    final spaces = spacesProvider.spaces;

    // Simulate AI analysis (UI only - backend not ready)
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Assign spaces based on file extension heuristic (simulated AI)
    for (final file in _inbox) {
      final ext = file.name.split('.').last.toLowerCase();
      String? suggestedSpaceId;
      String? suggestedSpaceName;

      if (spaces.isNotEmpty) {
        // Simple heuristic matching space names to file types
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
          final match = spaces.firstWhere(
            (s) =>
                s.name.toLowerCase().contains('photo') ||
                s.name.toLowerCase().contains('image') ||
                s.name.toLowerCase().contains('media'),
            orElse: () => spaces.first,
          );
          suggestedSpaceId = match.id;
          suggestedSpaceName = match.name;
        } else if (['pdf', 'doc', 'docx', 'txt', 'md'].contains(ext)) {
          final match = spaces.firstWhere(
            (s) =>
                s.name.toLowerCase().contains('doc') ||
                s.name.toLowerCase().contains('work') ||
                s.name.toLowerCase().contains('file'),
            orElse: () => spaces.first,
          );
          suggestedSpaceId = match.id;
          suggestedSpaceName = match.name;
        } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
          final match = spaces.firstWhere(
            (s) =>
                s.name.toLowerCase().contains('video') ||
                s.name.toLowerCase().contains('media'),
            orElse: () => spaces.first,
          );
          suggestedSpaceId = match.id;
          suggestedSpaceName = match.name;
        } else {
          suggestedSpaceId = spaces.first.id;
          suggestedSpaceName = spaces.first.name;
        }
      }

      file.suggestedSpace = suggestedSpaceName ?? 'General';
      file.suggestedSpaceId = suggestedSpaceId;
      file.status = _FileStatus.suggested;
    }

    setState(() {
      _isOrganizing = false;
      _organized = true;
    });
  }

  Future<void> _uploadAll() async {
    final filesProvider = Provider.of<FilesProvider>(context, listen: false);
    int successCount = 0;

    for (final file in _inbox) {
      if (file.status == _FileStatus.suggested &&
          file.suggestedSpaceId != null) {
        setState(() => file.status = _FileStatus.uploading);
        final success = await filesProvider.uploadFile(
          spaceId: file.suggestedSpaceId!,
          bytes: file.bytes,
          filename: file.name,
        );
        setState(() {
          file.status = success ? _FileStatus.done : _FileStatus.failed;
          if (success) successCount++;
        });
      }
    }

    if (mounted) {
      if (successCount > 0) {
        TopAlertBar.showSuccess(
          context,
          'Auto-organized $successCount files into your Spaces!',
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(
              () => _inbox.removeWhere((f) => f.status == _FileStatus.done),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark
        ? Colors.white12
        : Colors.black.withOpacity(0.08);

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
              'AI Dropzone',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              'Dump files. AI organizes them.',
              style: TextStyle(fontSize: 11, color: textSecondary),
            ),
          ],
        ),
        leading: UnifiedBackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Drop Zone target
                  GestureDetector(
                    onTap: _pickFiles,
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (ctx, child) => Transform.scale(
                        scale: _inbox.isEmpty ? _pulse.value : 1.0,
                        child: child,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (b) =>
                                  AppColors.primaryGradient.createShader(b),
                              child: const Icon(
                                Icons.cloud_upload_rounded,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tap to dump files',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Drop anything — photos, docs, videos, PDFs\nAI will sort them automatically',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status / AI badge
                  if (_inbox.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_inbox.length} file${_inbox.length > 1 ? 's' : ''} in inbox',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _inbox.clear();
                            _organized = false;
                          }),
                          child: Text(
                            'Clear all',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action buttons
                  if (_inbox.isNotEmpty && !_organized) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isOrganizing ? null : _organizeWithAi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isOrganizing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          _isOrganizing
                              ? 'AI is analyzing your files...'
                              : 'Organize with AI',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_organized) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'AI has sorted your files. Review suggestions below.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _uploadAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text(
                          'Upload All to Suggested Spaces',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // File list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildFileCard(
                  _inbox[i],
                  isDark,
                  cardColor,
                  textPrimary,
                  textSecondary,
                  borderColor,
                ),
                childCount: _inbox.length,
              ),
            ),
          ),

          // Empty hint
          if (_inbox.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '💡 Tip: Dump screenshots, downloads, and random files here. The AI will figure out where to put them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileCard(
    _DropzoneFile file,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    Color statusColor = AppColors.primary;
    IconData statusIcon = Icons.pending_rounded;
    String statusLabel = 'Pending';

    switch (file.status) {
      case _FileStatus.suggested:
        statusColor = AppColors.accent;
        statusIcon = Icons.auto_awesome_rounded;
        statusLabel = file.suggestedSpace ?? 'Analyzing...';
        break;
      case _FileStatus.uploading:
        statusColor = AppColors.warning;
        statusIcon = Icons.cloud_upload_rounded;
        statusLabel = 'Uploading...';
        break;
      case _FileStatus.done:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Done';
        break;
      case _FileStatus.failed:
        statusColor = AppColors.error;
        statusIcon = Icons.error_rounded;
        statusLabel = 'Failed';
        break;
      case _FileStatus.pending:
        statusColor = textSecondary;
        statusIcon = Icons.hourglass_empty_rounded;
        statusLabel = 'Waiting for AI';
        break;
    }

    final ext = file.name.split('.').last.toLowerCase();
    final fileIcon = _getFileIcon(ext);
    final fileIconColor = _getFileColor(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fileIconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(fileIcon, size: 20, color: fileIconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (file.status == _FileStatus.uploading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
              onPressed: () => setState(() => _inbox.remove(file)),
            ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx', 'txt', 'md'].contains(ext)) {
      return Icons.description_rounded;
    }
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
      return Icons.video_file_rounded;
    }
    if (['mp3', 'wav', 'aac'].contains(ext)) return Icons.audio_file_rounded;
    if (['zip', 'rar', '7z', 'tar'].contains(ext)) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String ext) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) {
      return AppColors.catImage;
    }
    if (['pdf'].contains(ext)) return AppColors.catDocument;
    if (['doc', 'docx', 'txt', 'md'].contains(ext)) {
      return AppColors.catDocument;
    }
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) return AppColors.catVideo;
    if (['mp3', 'wav', 'aac'].contains(ext)) return AppColors.catAudio;
    if (['zip', 'rar', '7z', 'tar'].contains(ext)) return AppColors.catArchive;
    return AppColors.catOther;
  }
}

// ── Models ───────────────────────────────────────────────────────────────────

enum _FileStatus { pending, suggested, uploading, done, failed }

class _DropzoneFile {
  final String name;
  final int size;
  final List<int> bytes;
  String? suggestedSpace;
  String? suggestedSpaceId;
  _FileStatus status;

  _DropzoneFile({
    required this.name,
    required this.size,
    required this.bytes,
    this.suggestedSpace,
    required this.status,
  });
}
