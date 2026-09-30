import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Prepares a local sandbox file for native OS opening or native sharing.
/// Uses a dedicated subfolder per fileId so the filename matches the EXACT original filename.
Future<String> cacheFileForExternalUse(
  String fileId,
  String fileName,
  List<int> bytes,
) async {
  final temporaryDirectory = await getTemporaryDirectory();
  final baseDir = Directory(
    '${temporaryDirectory.path}${Platform.pathSeparator}spaces_cache',
  );
  await baseDir.create(recursive: true);

  // Dedicated subdirectory per fileId ensures exact original filename preservation
  final fileDir = Directory('${baseDir.path}${Platform.pathSeparator}$fileId');
  await fileDir.create(recursive: true);

  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final cachedFile = File('${fileDir.path}${Platform.pathSeparator}$safeName');
  await cachedFile.writeAsBytes(bytes, flush: true);

  // Background cleanup of stale cache files (> 24 hours old)
  _purgeOldCacheFiles(baseDir);

  return cachedFile.path;
}

/// Stream large files directly to disk without loading entire payload into RAM.
Future<String> streamFileToCache(
  String fileId,
  String fileName,
  http.StreamedResponse response, {
  void Function(double progress)? onProgress,
  int? totalBytes,
}) async {
  final temporaryDirectory = await getTemporaryDirectory();
  final baseDir = Directory(
    '${temporaryDirectory.path}${Platform.pathSeparator}spaces_cache',
  );
  await baseDir.create(recursive: true);

  final fileDir = Directory('${baseDir.path}${Platform.pathSeparator}$fileId');
  await fileDir.create(recursive: true);

  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final cachedFile = File('${fileDir.path}${Platform.pathSeparator}$safeName');

  final sink = cachedFile.openWrite();
  int received = 0;
  final total = totalBytes ?? response.contentLength;

  await for (final chunk in response.stream) {
    sink.add(chunk);
    received += chunk.length;
    if (total != null && total > 0 && onProgress != null) {
      onProgress(received / total);
    }
  }

  await sink.flush();
  await sink.close();

  _purgeOldCacheFiles(baseDir);

  return cachedFile.path;
}

void _purgeOldCacheFiles(Directory baseDir) {
  try {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    baseDir.list(recursive: false).listen((entity) {
      if (entity is Directory) {
        entity.stat().then((stat) {
          if (stat.modified.isBefore(cutoff)) {
            entity.delete(recursive: true).catchError((_) => entity);
          }
        }).catchError((_) {});
      }
    });
  } catch (_) {}
}