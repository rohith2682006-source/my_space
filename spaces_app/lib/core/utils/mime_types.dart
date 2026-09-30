/// Centralized MIME type resolver for all platforms.
/// Maps extensions to standardized MIME types and categories without duplication.
class MimeTypes {
  static const Map<String, String> _extensionToMime = {
    // Video
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'avi': 'video/x-msvideo',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm',
    'flv': 'video/x-flv',
    'wmv': 'video/x-ms-wmv',
    '3gp': 'video/3gpp',
    'ts': 'video/mp2t',

    // Presentations
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'odp': 'application/vnd.oasis.opendocument.presentation',
    'pps': 'application/vnd.ms-powerpoint',
    'ppsx': 'application/vnd.openxmlformats-officedocument.presentationml.slideshow',

    // Documents
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'odt': 'application/vnd.oasis.opendocument.text',
    'rtf': 'application/rtf',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'markdown': 'text/markdown',

    // Spreadsheets
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ods': 'application/vnd.oasis.opendocument.spreadsheet',
    'csv': 'text/csv',
    'tsv': 'text/tab-separated-values',

    // Audio
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'flac': 'audio/flac',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'wma': 'audio/x-ms-wma',

    // Images
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'bmp': 'image/bmp',
    'ico': 'image/x-icon',
    'tiff': 'image/tiff',

    // Archives
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',

    // Code & Structured Data
    'json': 'application/json',
    'xml': 'application/xml',
    'html': 'text/html',
    'htm': 'text/html',
    'css': 'text/css',
    'js': 'application/javascript',
    'dart': 'application/vnd.dart',
    'py': 'text/x-python',
    'sh': 'application/x-sh',
  };

  /// Lookup MIME type by file extension or full filename.
  /// Falls back to [fallback] or 'application/octet-stream' if unknown.
  static String lookupMime(String filenameOrExtension, {String? fallback}) {
    final ext = _extractExtension(filenameOrExtension).toLowerCase();
    return _extensionToMime[ext] ?? fallback ?? 'application/octet-stream';
  }

  /// Get best MIME type given both stored MIME and filename.
  static String resolveMime(String? storedMime, String filename) {
    if (storedMime != null &&
        storedMime.isNotEmpty &&
        storedMime != 'application/octet-stream' &&
        storedMime.contains('/')) {
      return storedMime;
    }
    return lookupMime(filename);
  }

  /// Check if the file is a playable video.
  static bool isVideo(String filenameOrExtension) {
    final mime = lookupMime(filenameOrExtension);
    return mime.startsWith('video/');
  }

  /// Check if the file is an audio track.
  static bool isAudio(String filenameOrExtension) {
    final mime = lookupMime(filenameOrExtension);
    return mime.startsWith('audio/');
  }

  /// Check if the file is a presentation (PowerPoint / Impress).
  static bool isPresentation(String filenameOrExtension) {
    final ext = _extractExtension(filenameOrExtension).toLowerCase();
    return {'ppt', 'pptx', 'odp', 'pps', 'ppsx'}.contains(ext);
  }

  /// Check if the file is a word processing document (Word / Writer).
  static bool isWordDocument(String filenameOrExtension) {
    final ext = _extractExtension(filenameOrExtension).toLowerCase();
    return {'doc', 'docx', 'odt', 'rtf'}.contains(ext);
  }

  /// Check if the file is an image.
  static bool isImage(String filenameOrExtension) {
    final mime = lookupMime(filenameOrExtension);
    return mime.startsWith('image/');
  }

  /// Check if the file is a PDF.
  static bool isPdf(String filenameOrExtension) {
    return _extractExtension(filenameOrExtension).toLowerCase() == 'pdf';
  }

  static String _extractExtension(String input) {
    if (!input.contains('.')) return input;
    final parts = input.split('.');
    return parts.last;
  }
}
