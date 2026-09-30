import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../data/models/plan_model.dart';
import '../data/models/subscription_model.dart';

class PlansProvider extends ChangeNotifier {
  List<PlanModel> _plans = [];
  SubscriptionModel? _currentSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<PlanModel> get plans => _plans;
  SubscriptionModel? get currentSubscription => _currentSubscription;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PlanModel? get activePlan => _currentSubscription?.plan;

  Future<void> fetchPlans() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.get(ApiEndpoints.billingPlans);
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data is List
          ? response.data
          : (response.data is Map && response.data['data'] is List ? response.data['data'] : []);
      _plans = list.map((item) => PlanModel.fromJson(item)).toList();
    } else {
      _errorMessage = response.message ?? 'Failed to load plans';
    }
    notifyListeners();
  }

  Future<void> fetchCurrentSubscription() async {
    final response = await ApiClient.get(ApiEndpoints.billingSubscription);
    if (response.success && response.data != null) {
      final data = response.data is Map<String, dynamic> ? response.data : null;
      if (data != null && data['subscription'] != null) {
        _currentSubscription = SubscriptionModel.fromJson(data['subscription']);
      }
    }
    notifyListeners();
  }

  Future<bool> upgradePlan(String planId, {String billingCycle = 'monthly'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Create order
    final orderRes = await ApiClient.post(ApiEndpoints.billingOrders, body: {
      'planId': planId,
      'billingCycle': billingCycle,
    });

    if (!orderRes.success || orderRes.data == null) {
      _isLoading = false;
      _errorMessage = orderRes.message ?? 'Failed to create subscription order';
      notifyListeners();
      return false;
    }

    final orderData = orderRes.data as Map<String, dynamic>;
    final orderId = orderData['orderId'] ?? '';

    // 2. Verify payment (in test mode, mock signature)
    final verifyRes = await ApiClient.post(ApiEndpoints.billingVerify, body: {
      'planId': planId,
      'razorpayOrderId': orderId,
      'razorpayPaymentId': 'pay_${DateTime.now().millisecondsSinceEpoch}',
      'razorpaySignature': 'mock_signature_dev',
    });

    _isLoading = false;

    if (verifyRes.success) {
      await fetchCurrentSubscription();
      return true;
    } else {
      _errorMessage = verifyRes.message ?? 'Payment verification failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelSubscription() async {
    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.post(ApiEndpoints.billingCancel, body: {});
    _isLoading = false;

    if (response.success) {
      await fetchCurrentSubscription();
      return true;
    } else {
      _errorMessage = response.message ?? 'Failed to cancel subscription';
      notifyListeners();
      return false;
    }
  }
}
