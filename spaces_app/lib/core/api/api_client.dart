import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';
import '../../data/services/auth_storage.dart';

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final String? errorCode;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
    required this.statusCode,
  });
}

class ApiClient {
  static final http.Client _client = http.Client();
  static void Function()? onUnauthorized;

  // Mutex: only ONE refresh call in flight at a time.
  // Backend uses token rotation - sending revoked token triggers theft cascade.
  static bool _isRefreshing = false;
  static Future<bool>? _refreshFuture;

  static Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await AuthStorage.getAccessToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (!isMultipart) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static Future<Map<String, String>> getHeaders({bool isMultipart = false}) async {
    return _getHeaders(isMultipart: isMultipart);
  }

  /// Hosted backends on free tiers (e.g. Render) sleep when idle and need up to
  /// ~60s to cold start. Wait generously and retry on gateway errors / timeouts.
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const int _maxAttempts = 3;

  static Future<http.Response> _withRetry(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final headers = await _getHeaders();
        final response = await send(headers).timeout(_requestTimeout);
        final isGatewayError = response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504;
        if (isGatewayError && attempt < _maxAttempts) {
          await Future.delayed(Duration(seconds: 3 * attempt));
          continue;
        }
        return response;
      } catch (e) {
        lastError = e;
        if (attempt < _maxAttempts) {
          await Future.delayed(Duration(seconds: 3 * attempt));
        }
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  /// Fire-and-forget ping to wake a sleeping backend as soon as the app opens.
  static Future<void> wakeUpServer() async {
    try {
      final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/v\d+/?$'), '');
      await _client.get(Uri.parse('$base/health')).timeout(const Duration(seconds: 70));
    } catch (_) {}
  }

  static const _networkError = 'Network error: Please check your connection';

  static Future<ApiResponse> get(String url) async {
    try {
      final response = await _withRetry((h) => _client.get(Uri.parse(url), headers: h));
      return await _handleResponse(response, () => get(url));
    } catch (e) {
      return ApiResponse(success: false, message: _networkError, statusCode: 0);
    }
  }

  static Future<ApiResponse> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final response = await _withRetry((h) => _client.post(Uri.parse(url), headers: h, body: body != null ? jsonEncode(body) : null));
      return await _handleResponse(response, () => post(url, body: body));
    } catch (e) {
      return ApiResponse(success: false, message: _networkError, statusCode: 0);
    }
  }

  static Future<ApiResponse> patch(String url, {Map<String, dynamic>? body}) async {
    try {
      final response = await _withRetry((h) => _client.patch(Uri.parse(url), headers: h, body: body != null ? jsonEncode(body) : null));
      return await _handleResponse(response, () => patch(url, body: body));
    } catch (e) {
      return ApiResponse(success: false, message: _networkError, statusCode: 0);
    }
  }

  static Future<ApiResponse> delete(String url) async {
    try {
      final response = await _withRetry((h) => _client.delete(Uri.parse(url), headers: h));
      return await _handleResponse(response, () => delete(url));
    } catch (e) {
      return ApiResponse(success: false, message: _networkError, statusCode: 0);
    }
  }


  static Future<ApiResponse> uploadFile({
    required String url,
    required List<int> bytes,
    required String filename,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final token = await AuthStorage.getAccessToken();
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      if (fields != null) request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _parseJsonResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: 'Failed to upload file: $e', statusCode: 0);
    }
  }

  static Future<ApiResponse> _handleResponse(http.Response response, Future<ApiResponse> Function() retryRequest) async {
    if (response.statusCode == 401) {
      final refreshed = await _refreshTokenOnce();
      if (refreshed) return retryRequest();
      onUnauthorized?.call();
    }
    return _parseJsonResponse(response);
  }

  static ApiResponse _parseJsonResponse(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: body['success'] ?? true, data: body['data'] ?? body, message: body['message'], statusCode: response.statusCode);
      } else {
        final errorObj = body['error'];
        final message = errorObj != null && errorObj['message'] != null ? errorObj['message'] : (body['message'] ?? 'An error occurred');
        final code = errorObj != null ? errorObj['code'] : null;
        return ApiResponse(success: false, message: message, errorCode: code, statusCode: response.statusCode);
      }
    } catch (_) {
      return ApiResponse(success: response.statusCode >= 200 && response.statusCode < 300, message: response.statusCode >= 400 ? 'Server error (${response.statusCode})' : null, statusCode: response.statusCode);
    }
  }

  static Future<bool> refreshToken() => _refreshTokenOnce();

  static Future<bool> _refreshTokenOnce() {
    if (_isRefreshing && _refreshFuture != null) return _refreshFuture!;
    _isRefreshing = true;
    _refreshFuture = _tryRefreshToken().whenComplete(() {
      _isRefreshing = false;
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  static Future<bool> _tryRefreshToken() async {
    try {
      String? refreshToken = await AuthStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        // Fallback to saved account's refresh token if active token was somehow lost
        final saved = await AuthStorage.getSavedAccounts();
        final acc = saved.firstWhere(
          (a) => a['refreshToken'] != null && a['refreshToken'].toString().isNotEmpty,
          orElse: () => {},
        );
        if (acc.isNotEmpty) {
          refreshToken = acc['refreshToken'].toString();
        }
      }

      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final res = await _client.post(
        Uri.parse(ApiEndpoints.refresh),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final tokens = data['data']?['tokens'] ?? data['tokens'];
        if (tokens != null) {
          await AuthStorage.saveTokens(
            accessToken: tokens['accessToken'],
            refreshToken: tokens['refreshToken'] ?? refreshToken,
          );
          return true;
        }
      } else if (res.statusCode == 401) {
        // Only invalidate if the backend explicitly rejected the refresh token as expired or invalid
        await AuthStorage.clearAll();
        return false;
      }
    } catch (_) {
      // Network error / offline: do NOT clear stored tokens!
    }
    return false;
  }
}
