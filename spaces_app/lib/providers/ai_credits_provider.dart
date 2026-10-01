import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../data/models/ai_credit_model.dart';
import '../data/models/ai_usage_model.dart';

class AiCreditsProvider extends ChangeNotifier {
  AiCreditBalanceModel? _balance;
  List<AiCreditTransactionModel> _history = [];
  AiUsageModel? _usageStats;
  bool _isLoading = false;
  String? _errorMessage;

  AiCreditBalanceModel? get balance => _balance;
  List<AiCreditTransactionModel> get history => _history;
  AiUsageModel? get usageStats => _usageStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get currentCredits => 999999; // Unlimited credits for free version

  Future<void> fetchBalance() async {
    final response = await ApiClient.get(ApiEndpoints.aiCreditsBalance);
    if (response.success && response.data != null) {
      _balance = AiCreditBalanceModel.fromJson(response.data);
      notifyListeners();
    }
  }

  void updateBalanceLocally(int newBalance) {
    if (_balance != null) {
      _balance = AiCreditBalanceModel(
        id: _balance!.id,
        userId: _balance!.userId,
        balance: newBalance,
        totalUsed: _balance!.totalUsed,
        periodStart: _balance!.periodStart,
        periodEnd: _balance!.periodEnd,
      );
      notifyListeners();
    }
  }

  Future<void> fetchHistory() async {
    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.get(ApiEndpoints.aiCreditsHistory);
    _isLoading = false;

    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final list = data['transactions'] as List<dynamic>? ?? [];
      _history = list.map((e) => AiCreditTransactionModel.fromJson(e)).toList();
    } else {
      _errorMessage = response.message ?? 'Failed to load credit history';
    }
    notifyListeners();
  }

  Future<void> fetchUsageStats() async {
    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.get(ApiEndpoints.aiUsageStats);
    _isLoading = false;

    if (response.success && response.data != null) {
      _usageStats = AiUsageModel.fromJson(response.data);
    } else {
      _errorMessage = response.message ?? 'Failed to load usage statistics';
    }
    notifyListeners();
  }

  Future<bool> buyCredits(int credits, int priceInr) async {
    _isLoading = true;
    notifyListeners();

    final orderRes = await ApiClient.post(ApiEndpoints.billingCreditsBuy, body: {
      'credits': credits,
      'priceInr': priceInr,
    });

    if (!orderRes.success || orderRes.data == null) {
      _isLoading = false;
      _errorMessage = orderRes.message ?? 'Failed to initiate purchase';
      notifyListeners();
      return false;
    }

    final orderData = orderRes.data as Map<String, dynamic>;
    final orderId = orderData['orderId'] ?? '';

    // Verify credits purchase
    final verifyRes = await ApiClient.post(ApiEndpoints.billingCreditsVerify, body: {
      'orderId': orderId,
      'paymentId': 'pay_credit_${DateTime.now().millisecondsSinceEpoch}',
      'signature': 'mock_signature_credit',
      'credits': credits,
    });

    _isLoading = false;

    if (verifyRes.success) {
      await fetchBalance();
      await fetchHistory();
      return true;
    } else {
      _errorMessage = verifyRes.message ?? 'Credit purchase verification failed';
      notifyListeners();
      return false;
    }
  }
}
