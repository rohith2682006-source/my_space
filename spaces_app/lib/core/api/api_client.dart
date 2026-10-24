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

  static Future<Map<String, String>> _getHeaders({
    bool isMultipart = false,
  }) async {
    final token = await AuthStorage.getAccessToken();

    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Future<ApiResponse> get(String url) async {
    try {
      final headers = await _getHeaders();

      final response = await _client.get(
        Uri.parse(url),
        headers: headers,
      );

      return _handleResponse(response, () => get(url));
    } catch (e, stackTrace) {
      _logNetworkError('GET', url, e, stackTrace);

      return ApiResponse(
        success: false,
        message: 'Network error (${e.runtimeType}): $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> post(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(
        response,
        () => post(url, body: body),
      );
    } catch (e, stackTrace) {
      _logNetworkError('POST', url, e, stackTrace);

      return ApiResponse(
        success: false,
        message: 'Network error (${e.runtimeType}): $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> patch(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await _client.patch(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(
        response,
        () => patch(url, body: body),
      );
    } catch (e, stackTrace) {
      _logNetworkError('PATCH', url, e, stackTrace);

      return ApiResponse(
        success: false,
        message: 'Network error (${e.runtimeType}): $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> delete(String url) async {
    try {
      final headers = await _getHeaders();

      final response = await _client.delete(
        Uri.parse(url),
        headers: headers,
      );

      return _handleResponse(response, () => delete(url));
    } catch (e, stackTrace) {
      _logNetworkError('DELETE', url, e, stackTrace);

      return ApiResponse(
        success: false,
        message: 'Network error (${e.runtimeType}): $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> uploadFile({
    required String url,
    required List<int> bytes,
    required String filename,
    String fieldName = 'file',
  }) async {
    try {
      final token = await AuthStorage.getAccessToken();
      final uri = Uri.parse(url);

      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _parseJsonResponse(response);
    } catch (e, stackTrace) {
      _logNetworkError('UPLOAD', url, e, stackTrace);

      return ApiResponse(
        success: false,
        message: 'File upload failed (${e.runtimeType}): $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> _handleResponse(
    http.Response response,
    Future<ApiResponse> Function() retryRequest,
  ) async {
    if (response.statusCode == 401) {
      final refreshed = await _tryRefreshToken();

      if (refreshed) {
        return retryRequest();
      }

      onUnauthorized?.call();
    }

    return _parseJsonResponse(response);
  }

  static ApiResponse _parseJsonResponse(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return ApiResponse(
          success: body is Map
              ? (body['success'] ?? true) == true
              : true,
          data: body is Map
              ? (body['data'] ?? body)
              : body,
          message: body is Map ? body['message']?.toString() : null,
          statusCode: response.statusCode,
        );
      }

      final dynamic errorObj =
          body is Map ? body['error'] : null;

      final String message;

      if (errorObj is Map && errorObj['message'] != null) {
        message = errorObj['message'].toString();
      } else if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      } else {
        message = 'Request failed (${response.statusCode})';
      }

      final String? code =
          errorObj is Map && errorObj['code'] != null
              ? errorObj['code'].toString()
              : null;

      return ApiResponse(
        success: false,
        message: message,
        errorCode: code,
        statusCode: response.statusCode,
      );
    } catch (e, stackTrace) {
      _logNetworkError(
        'PARSE RESPONSE',
        'HTTP ${response.statusCode}',
        e,
        stackTrace,
      );

      return ApiResponse(
        success: response.statusCode >= 200 &&
            response.statusCode < 300,
        message: response.statusCode >= 400
            ? 'Server error (${response.statusCode})'
            : 'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  static Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await AuthStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await _client.post(
        Uri.parse(ApiEndpoints.refresh),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is! Map) {
          await AuthStorage.clearAll();
          return false;
        }

        final dynamic data = decoded['data'];
        final dynamic tokens =
            data is Map ? data['tokens'] : null;

        if (tokens is! Map ||
            tokens['accessToken'] == null ||
            tokens['refreshToken'] == null) {
          await AuthStorage.clearAll();
          return false;
        }

        await AuthStorage.saveTokens(
          accessToken: tokens['accessToken'].toString(),
          refreshToken: tokens['refreshToken'].toString(),
        );

        return true;
      }
    } catch (e, stackTrace) {
      _logNetworkError(
        'TOKEN REFRESH',
        ApiEndpoints.refresh,
        e,
        stackTrace,
      );
    }

    await AuthStorage.clearAll();
    return false;
  }

  static void _logNetworkError(
    String method,
    String url,
    Object error,
    StackTrace stackTrace,
  ) {
    print('========== API NETWORK ERROR ==========');
    print('Method: $method');
    print('URL: $url');
    print('Error type: ${error.runtimeType}');
    print('Error: $error');
    print('Stack trace: $stackTrace');
    print('=======================================');
  }
}
