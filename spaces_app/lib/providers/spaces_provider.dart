import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../data/models/space_model.dart';

class SpacesProvider extends ChangeNotifier {
  List<SpaceModel> _spaces = [];
  SpaceModel? _activeSpace;
  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _unlockedSpaceIds = {};

  SpacesProvider() {
    _loadCachedSpaces();
  }

  Future<void> _loadCachedSpaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_spaces_list');
      if (cachedJson != null && cachedJson.isNotEmpty && _spaces.isEmpty) {
        final List<dynamic> list = jsonDecode(cachedJson);
        _spaces = list.map((item) => SpaceModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  List<SpaceModel> get spaces => _spaces;
  SpaceModel? get activeSpace => _activeSpace;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isSpaceUnlocked(String spaceId) => _unlockedSpaceIds.contains(spaceId);

  void unlockSpace(String spaceId) {
    _unlockedSpaceIds.add(spaceId);
    notifyListeners();
  }

  void lockSpace(String spaceId) {
    _unlockedSpaceIds.remove(spaceId);
    notifyListeners();
  }

  Future<void> fetchSpaces({String? search}) async {
    if (_spaces.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    String url = ApiEndpoints.spaces;
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeComponent(search)}';
    }

    final response = await ApiClient.get(url);
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data is List
          ? response.data
          : (response.data is Map && response.data['data'] is List
                ? response.data['data']
                : []);
      _spaces = list.map((item) => SpaceModel.fromJson(item)).toList();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_spaces_list', jsonEncode(list));
      } catch (_) {}
    } else {
      _errorMessage = response.message ?? 'Failed to load Spaces';
    }
    notifyListeners();
  }

  Future<SpaceModel?> getSpaceById(String spaceId) async {
    final response = await ApiClient.get(ApiEndpoints.space(spaceId));
    if (response.success && response.data != null) {
      _activeSpace = SpaceModel.fromJson(response.data);
      notifyListeners();
      return _activeSpace;
    }
    return null;
  }

  void setActiveSpace(SpaceModel space) {
    _activeSpace = space;
    notifyListeners();
  }

  Future<SpaceModel?> createSpace({
    required String name,
    String? description,
    String icon = '📁',
    String color = '#6366F1',
    bool isPrivate = true,
    String? password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final Map<String, dynamic> body = {
      'name': name.trim(),
      'icon': icon,
      'color': color,
      'isPrivate': isPrivate,
    };
    if (isPrivate && password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }

    final response = await ApiClient.post(ApiEndpoints.spaces, body: body);

    _isLoading = false;

    if (response.success && response.data != null) {
      final newSpace = SpaceModel.fromJson(response.data);
      _spaces.insert(0, newSpace);
      notifyListeners();
      return newSpace;
    } else {
      _errorMessage = response.message ?? 'Failed to create Space';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateSpace(
    String spaceId, {
    String? name,
    String? description,
    String? icon,
    String? color,
    String? password,
  }) async {
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name.trim();
    if (description != null) body['description'] = description.trim();
    if (icon != null) body['icon'] = icon;
    if (color != null) body['color'] = color;
    if (password != null) body['password'] = password;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.patch(
      ApiEndpoints.space(spaceId),
      body: body,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => ApiResponse(
        success: false,
        message: 'Request timed out. Please try again.',
        statusCode: 0,
      ),
    );

    _isLoading = false;

    if (response.success) {
      if (response.data != null) {
        try {
          final Map<String, dynamic> dataMap = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : Map<String, dynamic>.from(response.data as Map);
          final updated = SpaceModel.fromJson(dataMap);
          final idx = _spaces.indexWhere((s) => s.id == spaceId);
          if (idx != -1) {
            _spaces[idx] = updated;
          }
          if (_activeSpace?.id == spaceId) {
            _activeSpace = updated;
          }
        } catch (_) {
          // Model deserialization fallback: server update succeeded
        }
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Failed to update space';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSpace(String spaceId) async {
    final response = await ApiClient.delete(ApiEndpoints.space(spaceId));
    if (response.success) {
      _spaces.removeWhere((s) => s.id == spaceId);
      if (_activeSpace?.id == spaceId) {
        _activeSpace = null;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> verifySpacePassword(String spaceId, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response =
        await ApiClient.post(
          '${ApiEndpoints.spaces}/$spaceId/verify-password',
          body: {'password': password},
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => ApiResponse(
            success: false,
            message: 'Verification timed out. Please try again.',
            statusCode: 0,
          ),
        );

    _isLoading = false;

    if (response.success) {
      _unlockedSpaceIds.add(spaceId);
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Incorrect password';
      notifyListeners();
      return false;
    }
  }
}
