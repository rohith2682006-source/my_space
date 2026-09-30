import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class FileHelper {
  static String formatBytes(dynamic bytes) {
    if (bytes == null) return '0 B';
    final int b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = b.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(count >= 10 || i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  static IconData getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'DOCUMENT':
        return Icons.description_rounded;
      case 'IMAGE':
        return Icons.image_rounded;
      case 'VIDEO':
        return Icons.videocam_rounded;
      case 'AUDIO':
        return Icons.audiotrack_rounded;
      case 'ARCHIVE':
        return Icons.folder_zip_rounded;
      case 'CODE':
        return Icons.code_rounded;
      case 'NOTE':
        return Icons.edit_note_rounded;
      case 'LINK':
        return Icons.link_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'DOCUMENT':
        return AppColors.catDocument;
      case 'IMAGE':
        return AppColors.catImage;
      case 'VIDEO':
        return AppColors.catVideo;
      case 'AUDIO':
        return AppColors.catAudio;
      case 'ARCHIVE':
        return AppColors.catArchive;
      case 'CODE':
        return AppColors.catCode;
      case 'NOTE':
        return AppColors.catNote;
      case 'LINK':
        return AppColors.catLink;
      default:
        return AppColors.catOther;
    }
  }

  static String timeAgo(dynamic dateTime) {
    if (dateTime == null) return '';
    final DateTime dt = dateTime is DateTime
        ? dateTime
        : DateTime.tryParse(dateTime.toString()) ?? DateTime.now();

    final Duration diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }
}
