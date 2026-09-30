import 'package:http/http.dart' as http;

Future<String> cacheFileForExternalUse(
  String fileId,
  String fileName,
  List<int> bytes,
) async {
  throw UnsupportedError('Local file caching is unavailable on this platform.');
}

Future<String> streamFileToCache(
  String fileId,
  String fileName,
  http.StreamedResponse response, {
  void Function(double progress)? onProgress,
  int? totalBytes,
}) async {
  throw UnsupportedError('Local file streaming is unavailable on this platform.');
}