import 'plan_model.dart';

class SubscriptionModel {
  final String id;
  final String userId;
  final String planId;
  final String status;
  final String billingPeriod;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? cancelledAt;
  final PlanModel? plan;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    required this.billingPeriod,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.cancelledAt,
    this.plan,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isCancelled => cancelledAt != null || status == 'CANCELLED';

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      planId: json['planId'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      billingPeriod: json['billingPeriod'] ?? 'MONTHLY',
      currentPeriodStart: json['currentPeriodStart'] != null
          ? DateTime.tryParse(json['currentPeriodStart'].toString()) ?? DateTime.now()
          : DateTime.now(),
      currentPeriodEnd: json['currentPeriodEnd'] != null
          ? DateTime.tryParse(json['currentPeriodEnd'].toString()) ?? DateTime.now()
          : DateTime.now(),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : null,
      plan: json['plan'] != null ? PlanModel.fromJson(json['plan']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planId': planId,
      'status': status,
      'billingPeriod': billingPeriod,
      'currentPeriodStart': currentPeriodStart.toIso8601String(),
      'currentPeriodEnd': currentPeriodEnd.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'plan': plan?.toJson(),
    };
  }
}
