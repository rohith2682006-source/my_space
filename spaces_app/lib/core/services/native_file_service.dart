import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../theme/app_colors.dart';
import '../utils/file_cache_stub.dart' if (dart.library.io) '../utils/file_cache_io.dart';
import '../utils/desktop_integration_stub.dart'
    if (dart.library.js_interop) '../utils/desktop_integration_web.dart';
import '../utils/mime_types.dart';
import '../../data/models/file_model.dart';
import '../../data/services/auth_storage.dart';
import '../../presentation/widgets/top_alert_bar.dart';

/// Centralized platform abstraction for native file operations:
/// - Opening files with the OS registered default applications
/// - Sharing original files through native OS share sheets (WhatsApp, Telegram, etc.)
/// - Generating and sharing secure web links
/// - Streaming large files with minimal RAM usage
class NativeFileService {
  /// Opens the file using the device's native registered application.
  /// (e.g. VLC / Media Player for MP4, PowerPoint for PPTX, Word for DOCX, Acrobat for PDF)
  static Future<void> openFileWithNativeApp(
    BuildContext context,
    FileModel file,
  ) async {
    // 1. Note handling
    if (file.category == 'NOTE') {
      _showNoteDialog(context, file);
      return;
    }

    // 2. Link handling
    if (file.category == 'LINK' && file.content != null) {
      final uri = Uri.tryParse(file.content!);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          TopAlertBar.showError(context, 'Could not launch URL: ${file.content}');
        }
      }
      return;
    }

    // 3. Web environment
    if (kIsWeb) {
      final token = await AuthStorage.getAccessToken();
      final previewUrl =
          '${ApiEndpoints.filePreview(file.id)}${token != null ? '?token=$token' : ''}';
      try {
        openFileInWeb(previewUrl, file.name);
      } catch (_) {
        final uri = Uri.parse(previewUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 4. Native Desktop / Mobile (Windows, macOS, Linux, Android, iOS)
    _showPreparingNotice(context, 'Opening "${file.name}" with default app...');

    try {
      final localPath = await _fetchAndCacheFile(file);
      final mimeType = MimeTypes.resolveMime(file.mimeType, file.name);

      final result = await OpenFilex.open(localPath, type: mimeType);

      if (context.mounted) {
        switch (result.type) {
          case ResultType.done:
            // Successfully handed off to OS
            break;
          case ResultType.noAppToOpen:
            _showNoAppFoundDialog(context, file, localPath);
            break;
          case ResultType.permissionDenied:
            TopAlertBar.showError(
              context,
              'Permission denied by operating system to open "${file.name}".',
            );
            break;
          case ResultType.fileNotFound:
            TopAlertBar.showError(
              context,
              'Could not find cached file on disk.',
            );
            break;
          case ResultType.error:
            _showNoAppFoundDialog(context, file, localPath);
            break;
        }
      }

    } catch (e) {
      if (context.mounted) {
        TopAlertBar.showError(
          context,
          'Unable to open "${file.name}". Error: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  /// Shares the ACTUAL ORIGINAL FILE through the native platform share sheet.
  /// The target app (WhatsApp, Telegram, Outlook, Quick Share, etc.) receives the genuine file.
  /// NEVER falls back to downloading the file.
  static Future<void> shareOriginalFile(
    BuildContext context,
    FileModel file, {
    Rect? sharePositionOrigin,
  }) async {
    // 1. Text notes & links
    if (file.category == 'NOTE' || file.category == 'LINK') {
      final text = file.content?.isNotEmpty == true ? file.content! : file.name;
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: file.name,
          title: file.name,
          sharePositionOrigin: sharePositionOrigin,
          downloadFallbackEnabled: false,
        ),
      );
      return;
    }

    _showPreparingNotice(context, 'Preparing "${file.name}" for sharing...');

    try {
      final mimeType = MimeTypes.resolveMime(file.mimeType, file.name);

      if (kIsWeb) {
        // On Web, check if browser supports Web Share with files
        // Explicitly set downloadFallbackEnabled: false so it NEVER silently downloads the file!
        final bytes = await _fetchFileBytes(file);
        final sharedXFile = XFile.fromData(
          bytes,
          mimeType: mimeType,
          name: file.name,
        );

        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [sharedXFile],
              subject: file.name,
              title: file.name,
              sharePositionOrigin: sharePositionOrigin,
              downloadFallbackEnabled: false, // CRITICAL: NEVER download on share!
            ),
          );
        } catch (_) {
          // Browser cannot share raw files to local apps: offer Share Link instead of downloading
          if (context.mounted) {
            _showWebShareFallbackDialog(context, file);
          }
        }
        return;
      }

      // 2. Native Desktop / Mobile (Windows, macOS, Linux, Android, iOS)
      // Caches file under spaces_cache/<fileId>/<exactFileName>
      final localPath = await _fetchAndCacheFile(file);
      final sharedXFile = XFile(
        localPath,
        mimeType: mimeType,
        name: file.name,
      );

      // On Windows Desktop, this summons the native Windows 10/11 Share Sheet
      // (IDataTransferManagerInterop::ShowShareUIForWindow) with the authentic file.
      await SharePlus.instance.share(
        ShareParams(
          files: [sharedXFile],
          subject: file.name,
          title: file.name,
          sharePositionOrigin: sharePositionOrigin,
          downloadFallbackEnabled: false, // CRITICAL: NEVER download on share!
        ),
      );
    } catch (e) {
      if (context.mounted) {
        if (kIsWeb) {
          _showWebShareFallbackDialog(context, file);
        } else {
          TopAlertBar.showError(
            context,
            'Unable to invoke native share sheet for "${file.name}". ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }
    }
  }

  /// Generates or resolves a secure shareable link for this file.
  /// (Distinct from sharing the actual file).
  static Future<void> shareSecureLink(
    BuildContext context,
    FileModel file,
  ) async {
    _showPreparingNotice(context, 'Generating secure share link...');

    try {
      final response = await ApiClient.post(
        ApiEndpoints.shareLinks,
        body: {
          'fileId': file.id,
          'allowDownload': true,
        },
      );

      if (!context.mounted) return;

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String? ?? '';
        final fullShareUrl = _buildFullShareUrl(token);

        _showShareLinkDialog(context, file, fullShareUrl);
      } else {
        TopAlertBar.showError(
          context,
          response.message ?? 'Failed to generate secure share link.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        TopAlertBar.showError(
          context,
          'Error generating link: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  /// Downloads the original file to the user's device.
  static Future<void> downloadOriginalFile(
    BuildContext context,
    FileModel file,
  ) async {
    if (kIsWeb) {
      final token = await AuthStorage.getAccessToken();
      final downloadUrl =
          '${ApiEndpoints.fileDownload(file.id)}${token != null ? '?token=$token' : ''}';
      final uri = Uri.parse(downloadUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    _showPreparingNotice(context, 'Downloading "${file.name}"...');

    try {
      final localPath = await _fetchAndCacheFile(file);
      if (context.mounted) {
        TopAlertBar.showSuccess(
          context,
          'Saved "${file.name}" to cache: $localPath',
        );
      }
    } catch (e) {
      if (context.mounted) {
        TopAlertBar.showError(
          context,
          'Failed to download "${file.name}": $e',
        );
      }
    }
  }

  // ─── Private Helpers ────────────────────────────────────────────────────────

  static Future<String> _fetchAndCacheFile(FileModel file) async {
    final token = await AuthStorage.getAccessToken();
    final client = http.Client();

    try {
      final request = http.Request(
        'GET',
        Uri.parse(ApiEndpoints.filePreview(file.id)),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamedResponse = await client.send(request);
      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        throw Exception(
          'Backend returned HTTP ${streamedResponse.statusCode}',
        );
      }

      return await streamFileToCache(
        file.id,
        file.name,
        streamedResponse,
        totalBytes: int.tryParse(file.size),
      );
    } finally {
      client.close();
    }
  }

  static Future<Uint8List> _fetchFileBytes(FileModel file) async {
    final token = await AuthStorage.getAccessToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.filePreview(file.id)),
      headers: token == null ? {} : {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('File download failed with code ${response.statusCode}');
    }
    return response.bodyBytes;
  }


  static String _buildFullShareUrl(String token) {
    const base = ApiEndpoints.baseUrl;
    final uri = Uri.parse(base);
    final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$origin/share/$token';
  }

  static void _showPreparingNotice(BuildContext context, String message) {
    TopAlertBar.showInfo(
      context,
      message,
      icon: Icons.sync_rounded,
    );
  }

  static void _showNoAppFoundDialog(
    BuildContext context,
    FileModel file,
    String localPath,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 24),
            SizedBox(width: 10),
            Text('No Compatible App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'No application installed on your device was found to open .${file.extension.toUpperCase()} files.\n\nYou can install a compatible app (e.g. VLC, Office, or PDF reader) or share the file to another device.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Share File Instead'),
            onPressed: () {
              Navigator.pop(ctx);
              shareOriginalFile(context, file);
            },
          ),
        ],
      ),
    );
  }

  static void _showWebShareFallbackDialog(
    BuildContext context,
    FileModel file,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.share_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Share Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Direct app-to-app sharing (WhatsApp, Outlook, Telegram, etc.) is handled by the native Windows Desktop or Mobile App.\n\nIn web browsers, you can generate a secure share link to send this file.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Share Link'),
            onPressed: () {
              Navigator.pop(ctx);
              shareSecureLink(context, file);
            },
          ),
        ],
      ),
    );
  }

  static void _showShareLinkDialog(
    BuildContext context,
    FileModel file,
    String shareUrl,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.link_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Share Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anyone with this secure link can view "${file.name}":',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: SelectableText(
                shareUrl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shareUrl));
              Navigator.pop(ctx);
              TopAlertBar.showSuccess(context, 'Link copied to clipboard!');
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Send Link'),
            onPressed: () {
              Navigator.pop(ctx);
              SharePlus.instance.share(
                ShareParams(
                  text: 'Check out "${file.name}": $shareUrl',
                  subject: file.name,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static void _showNoteDialog(BuildContext context, FileModel file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(
            file.content ?? 'Empty note',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
            onPressed: () {
              if (file.content != null) {
                Clipboard.setData(ClipboardData(text: file.content!));
                TopAlertBar.showSuccess(context, 'Note copied');
              }
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
