import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../data/models/activity_model.dart';

class ActivityProvider extends ChangeNotifier {
  List<ActivityModel> _activities = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ActivityModel> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchActivities({int limit = 40}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.get('${ApiEndpoints.activities}?limit=$limit');
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data is List ? response.data : [];
      _activities = list.map((item) => ActivityModel.fromJson(item)).toList();
    } else {
      _errorMessage = response.message ?? 'Failed to load activity feed';
    }
    notifyListeners();
  }

  Future<List<ActivityModel>> fetchSpaceActivities(String spaceId, {int limit = 30}) async {
    final response = await ApiClient.get('${ApiEndpoints.spaceActivities(spaceId)}?limit=$limit');
    if (response.success && response.data != null) {
      final List<dynamic> list = response.data is List ? response.data : [];
      return list.map((item) => ActivityModel.fromJson(item)).toList();
    }
    return [];
  }
}
