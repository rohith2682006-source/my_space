import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'file_cache_stub.dart' if (dart.library.io) 'file_cache_io.dart';
import '../api/api_endpoints.dart';
import '../../data/services/auth_storage.dart';
import '../../data/models/file_model.dart';
import '../theme/app_colors.dart';
import 'desktop_integration_stub.dart'
    if (dart.library.js_interop) 'desktop_integration_web.dart';

import '../../presentation/widgets/top_alert_bar.dart';

import '../services/native_file_service.dart';

class DesktopIntegration {
  /// Opens a file in the user's native desktop application in real-time without downloading
  static Future<void> openFileInDesktop(
    BuildContext context,
    FileModel file,
  ) async {
    await NativeFileService.openFileWithNativeApp(context, file);
  }

  static Future<void> shareFile(BuildContext context, FileModel file) async {
    await NativeFileService.shareOriginalFile(context, file);
  }

  static Future<Uint8List> _fetchFileBytes(FileModel file) async {
    final token = await AuthStorage.getAccessToken();
    final response = await http.get(
      Uri.parse(ApiEndpoints.filePreview(file.id)),
      headers: token == null ? {} : {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('File request failed with status ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// Triggers the native OS share sheet (Windows/Mac desktop apps)
  static Future<void> shareViaDesktopApps(
    BuildContext context, {
    required String title,
    required String text,
    required String shareUrl,
  }) async {
    bool sharedWithNative = false;

    if (kIsWeb) {
      try {
        sharedWithNative = await shareInWeb(title, text, shareUrl);
      } catch (e) {
        sharedWithNative = false;
      }
    }

    // If native share was not triggered or cancelled, show Desktop App Selection Sheet
    if (!sharedWithNative && context.mounted) {
      _showDesktopShareModal(context, title: title, text: text, url: shareUrl);
    }
  }

  static void _showNoteDialog(BuildContext context, FileModel file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.catNote.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: AppColors.catNote,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 350, maxWidth: 450),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              file.content?.isNotEmpty == true ? file.content! : 'Empty note.',
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Content'),
            onPressed: () {
              if (file.content != null) {
                Clipboard.setData(ClipboardData(text: file.content!));
                TopAlertBar.showSuccess(context, 'Note copied to clipboard');
              }
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

  static void _showDesktopShareModal(
    BuildContext context, {
    required String title,
    required String text,
    required String url,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share with Desktop Apps',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Pick any installed app to send in realtime',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Desktop apps row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAppIcon(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email App',
                  color: const Color(0xFFEA4335),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final mailUri = Uri.parse(
                      'mailto:?subject=${Uri.encodeComponent(title)}&body=${Uri.encodeComponent('$text\n\n$url')}',
                    );
                    await launchUrl(mailUri);
                  },
                ),
                _buildAppIcon(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final waUri = Uri.parse(
                      'https://api.whatsapp.com/send?text=${Uri.encodeComponent('$title - $url')}',
                    );
                    await launchUrl(
                      waUri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                _buildAppIcon(
                  icon: Icons.send_rounded,
                  label: 'Telegram',
                  color: const Color(0xFF0088CC),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final tgUri = Uri.parse(
                      'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(title)}',
                    );
                    await launchUrl(
                      tgUri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                _buildAppIcon(
                  icon: Icons.copy_rounded,
                  label: 'Copy Link',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Link copied to clipboard!'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAppIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
