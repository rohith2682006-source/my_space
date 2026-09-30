import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../core/utils/desktop_integration.dart';
import '../../data/models/file_model.dart';
import '../../data/services/auth_storage.dart';
import '../../providers/files_provider.dart';
import 'top_alert_bar.dart';

class FileViewerModal extends StatefulWidget {
  final FileModel file;
  final int initialPdfPage;

  const FileViewerModal({
    super.key,
    required this.file,
    this.initialPdfPage = 1,
  });

  static void show(
    BuildContext context,
    FileModel file, {
    int initialPdfPage = 1,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      barrierDismissible: true,
      builder: (ctx) =>
          FileViewerModal(file: file, initialPdfPage: initialPdfPage),
    );
  }

  @override
  State<FileViewerModal> createState() => _FileViewerModalState();
}

class _FileViewerModalState extends State<FileViewerModal> {
  String? _authenticatedUrl;
  PdfController? _pdfController;
  String? _viewerError;
  int _currentPdfPage = 1;
  bool _isLoading = true;
  bool _isChangingAiAccess = false;
  bool _aiSearchEnabled = false;
  String _aiIndexStatus = 'NOT_INDEXED';

  @override
  void initState() {
    super.initState();
    _aiSearchEnabled = widget.file.aiSearchEnabled;
    _aiIndexStatus = widget.file.indexStatus;
    _loadAuthUrl();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadAuthUrl() async {
    final token = await AuthStorage.getAccessToken();
    if (widget.file.extension.toLowerCase() == 'pdf') {
      try {
        final response = await http.get(
          Uri.parse(ApiEndpoints.filePreview(widget.file.id)),
          headers: token == null ? {} : {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('PDF request failed');
        }
        final document = await PdfDocument.openData(response.bodyBytes);
        final page = widget.initialPdfPage.clamp(1, document.pagesCount);
        if (!mounted) {
          await document.close();
          return;
        }
        setState(() {
          _pdfController = PdfController(
            document: Future.value(document),
            initialPage: page,
          );
          _currentPdfPage = page;
          _isLoading = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _viewerError = 'Unable to load this PDF.';
            _isLoading = false;
          });
        }
      }
      return;
    }

    if (mounted) {
      setState(() {
        _authenticatedUrl =
            '${ApiEndpoints.filePreview(widget.file.id)}${token != null ? '?token=$token' : ''}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 750,
          minWidth: 340,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFA0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                // Top Header Bar
                _buildHeader(isDark),

                // Main Viewer Body
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildViewerContent(isDark),
                ),

                // Bottom Metadata & Actions Bar
                _buildFooter(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final file = widget.file;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC1E293B) : const Color(0xF2F8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FileHelper.getCategoryColor(
                file.category,
              ).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              FileHelper.getCategoryIcon(file.category),
              size: 20,
              color: FileHelper.getCategoryColor(file.category),
            ),
          ),
          const SizedBox(width: 12),
          // Title & size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      FileHelper.formatBytes(file.size),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.black26,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      file.extension.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FileHelper.getCategoryColor(file.category),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons
          _buildActionButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open in Desktop App',
            isDark: isDark,
            onTap: () {
              DesktopIntegration.openFileInDesktop(context, widget.file);
            },
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            icon: Icons.share_rounded,
            tooltip: 'Share File',
            isDark: isDark,
            onTap: () => DesktopIntegration.shareFile(context, widget.file),
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildViewerContent(bool isDark) {
    final file = widget.file;
    final cat = file.category.toUpperCase();

    // 1. Image Viewer (Direct inline zoomable render)
    if (cat == 'IMAGE' && _authenticatedUrl != null) {
      return Container(
        color: isDark ? const Color(0xFF070B14) : const Color(0xFFF1F5F9),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              _authenticatedUrl!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackCard(
                  icon: Icons.broken_image_rounded,
                  title: 'Unable to preview image directly',
                  subtitle: 'Click below to view with Desktop Image Viewer.',
                  isDark: isDark,
                );
              },
            ),
          ),
        ),
      );
    }

    if (file.extension.toLowerCase() == 'pdf') {
      if (_pdfController == null) {
        return _buildFallbackCard(
          icon: Icons.picture_as_pdf_rounded,
          title: _viewerError ?? 'Unable to preview PDF',
          subtitle: 'Check your connection and try opening this file again.',
          isDark: isDark,
        );
      }

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: _currentPdfPage > 1
                    ? () => _pdfController!.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      )
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _pdfController!.pageListenable,
                builder: (context, page, _) => Text(
                  'Page $page of ${_pdfController!.pagesCount ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: _currentPdfPage < (_pdfController!.pagesCount ?? 1)
                    ? () => _pdfController!.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      )
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Expanded(
            child: PdfView(
              controller: _pdfController!,
              onPageChanged: (page) => setState(() => _currentPdfPage = page),
              onDocumentError: (_) =>
                  setState(() => _viewerError = 'Unable to render this PDF.'),
            ),
          ),
        ],
      );
    }

    // 2. Note / Code / Text Preview
    if (cat == 'NOTE' ||
        [
          'txt',
          'md',
          'dart',
          'js',
          'ts',
          'json',
          'py',
          'html',
          'css',
          'xml',
        ].contains(file.extension.toLowerCase())) {
      final content = file.content ?? 'No text content available.';
      return Container(
        color: isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              height: 1.6,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            ),
          ),
        ),
      );
    }

    // 3. Audio Player Preview
    if (cat == 'AUDIO') {
      return Container(
        color: isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.catAudio.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.audiotrack_rounded,
                  size: 46,
                  color: AppColors.catAudio,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                file.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Audio Track • ${FileHelper.formatBytes(file.size)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  DesktopIntegration.openFileInDesktop(context, widget.file);
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Play in Desktop Player'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catAudio,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Video Preview
    if (cat == 'VIDEO') {
      return Container(
        color: isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.catVideo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 54,
                  color: AppColors.catVideo,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                file.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Video File • ${FileHelper.formatBytes(file.size)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  DesktopIntegration.openFileInDesktop(context, widget.file);
                },
                icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                label: const Text('Play Fullscreen in Desktop Player'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catVideo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. PDF & Documents or Other files
    return Container(
      color: isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC),
      child: Center(
        child: _buildFallbackCard(
          icon: FileHelper.getCategoryIcon(file.category),
          title: file.name,
          subtitle:
              '${file.category} (${file.extension.toUpperCase()}) • ${FileHelper.formatBytes(file.size)}',
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildFallbackCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FileHelper.getCategoryColor(
                widget.file.category,
              ).withOpacity(0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 42,
              color: FileHelper.getCategoryColor(widget.file.category),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              DesktopIntegration.openFileInDesktop(context, widget.file);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open in Native Desktop App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final file = widget.file;
    final supportedForAi = const {
      'pdf',
      'txt',
      'md',
      'markdown',
    }.contains(file.extension.toLowerCase());
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC1E293B) : const Color(0xF2F8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Search',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      !supportedForAi
                          ? 'Not available for this file type yet'
                          : _aiSearchEnabled
                          ? 'AI can search this file. Status: ${_aiIndexStatus == 'PROCESSING' ? 'INDEXING' : _aiIndexStatus}'
                          : 'Enabling processes this file for AI search',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),
              if (_isChangingAiAccess)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: _aiSearchEnabled,
                  onChanged: supportedForAi ? _changeAiAccess : null,
                ),
            ],
          ),
          if (file.category == 'NOTE')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Note', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  if (file.content != null) {
                    Clipboard.setData(ClipboardData(text: file.content!));
                    TopAlertBar.showSuccess(
                      context,
                      'Note copied to clipboard',
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeAiAccess(bool enabled) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable AI Search?'),
          content: const Text(
            'The file content will be sent to the AI service for processing and indexing so Deep Search can find information in it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isChangingAiAccess = true);
    final success = await context.read<FilesProvider>().setAiSearchAccess(
      widget.file.id,
      enabled,
    );
    if (!mounted) return;
    setState(() {
      _isChangingAiAccess = false;
      if (success) {
        _aiSearchEnabled = enabled;
        _aiIndexStatus = enabled ? 'PROCESSING' : 'DISABLED';
      }
    });
    if (!success) {
      TopAlertBar.showError(context, 'Could not update AI Search access.');
    } else if (!enabled) {
      TopAlertBar.showSuccess(
        context,
        'AI Search access disabled for this file.',
      );
    } else {
      _pollAiIndexStatus();
    }
  }

  Future<void> _pollAiIndexStatus() async {
    for (var attempt = 0; attempt < 30; attempt += 1) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !_aiSearchEnabled) return;
      final response = await ApiClient.get(
        ApiEndpoints.aiDocumentIndexStatus(widget.file.id),
      );
      if (!response.success || response.data is! Map) return;
      final status = response.data['indexStatus'] as String? ?? 'FAILED';
      setState(() => _aiIndexStatus = status);
      if (!{'PROCESSING', 'INDEXING', 'UPLOADING'}.contains(status)) return;
    }
  }
}
