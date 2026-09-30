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

  static Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await AuthStorage.getAccessToken();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<ApiResponse> get(String url) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(url), headers: headers);
      return _handleResponse(response, () => get(url));
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your connection',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response, () => post(url, body: body));
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your connection',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> patch(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.patch(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response, () => patch(url, body: body));
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your connection',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> delete(String url) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(Uri.parse(url), headers: headers);
      return _handleResponse(response, () => delete(url));
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your connection',
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

      if (token != null) {
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
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to upload file: $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse> _handleResponse(
    http.Response response,
    Future<ApiResponse> Function() retryRequest,
  ) async {
    // If 401 Unauthorized, try to refresh token once
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: body['success'] ?? true,
          data: body['data'] ?? body,
          message: body['message'],
          statusCode: response.statusCode,
        );
      } else {
        final errorObj = body['error'];
        final message = errorObj != null && errorObj['message'] != null
            ? errorObj['message']
            : (body['message'] ?? 'An error occurred');
        final code = errorObj != null ? errorObj['code'] : null;

        return ApiResponse(
          success: false,
          message: message,
          errorCode: code,
          statusCode: response.statusCode,
        );
      }
    } catch (_) {
      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: response.statusCode >= 400 ? 'Server error (${response.statusCode})' : null,
        statusCode: response.statusCode,
      );
    }
  }

  static Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await AuthStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final res = await _client.post(
        Uri.parse(ApiEndpoints.refresh),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final tokens = data['data']['tokens'];
        await AuthStorage.saveTokens(
          accessToken: tokens['accessToken'],
          refreshToken: tokens['refreshToken'],
        );
        return true;
      }
    } catch (_) {
      // Refresh failed
    }
    await AuthStorage.clearAll();
    return false;
  }
}
