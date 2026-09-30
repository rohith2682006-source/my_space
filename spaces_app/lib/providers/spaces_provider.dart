import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../data/models/space_model.dart';

class SpacesProvider extends ChangeNotifier {
  List<SpaceModel> _spaces = [];
  SpaceModel? _activeSpace;
  bool _isLoading = false;
  String? _errorMessage;

  List<SpaceModel> get spaces => _spaces;
  SpaceModel? get activeSpace => _activeSpace;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSpaces({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.spaces;
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeComponent(search)}';
    }

    final response = await ApiClient.get(url);
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data is List
          ? response.data
          : (response.data is Map && response.data['data'] is List ? response.data['data'] : []);
      _spaces = list.map((item) => SpaceModel.fromJson(item)).toList();
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

  Future<bool> createSpace({
    required String name,
    String? description,
    String icon = '📁',
    String color = '#6366F1',
    bool isPrivate = true,
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
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }

    final response = await ApiClient.post(
      ApiEndpoints.spaces,
      body: body,
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      final newSpace = SpaceModel.fromJson(response.data);
      _spaces.insert(0, newSpace);
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Failed to create Space';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSpace(
    String spaceId, {
    String? name,
    String? description,
    String? icon,
    String? color,
  }) async {
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name.trim();
    if (description != null) body['description'] = description.trim();
    if (icon != null) body['icon'] = icon;
    if (color != null) body['color'] = color;

    final response = await ApiClient.patch(
      ApiEndpoints.space(spaceId),
      body: body,
    );

    if (response.success && response.data != null) {
      final updated = SpaceModel.fromJson(response.data);
      final idx = _spaces.indexWhere((s) => s.id == spaceId);
      if (idx != -1) {
        _spaces[idx] = updated;
      }
      if (_activeSpace?.id == spaceId) {
        _activeSpace = updated;
      }
      notifyListeners();
      return true;
    }
    return false;
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
}
