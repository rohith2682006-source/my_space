class AiCreditBalanceModel {
  final String id;
  final String userId;
  final int balance;
  final int totalUsed;
  final DateTime periodStart;
  final DateTime periodEnd;

  AiCreditBalanceModel({
    required this.id,
    required this.userId,
    required this.balance,
    required this.totalUsed,
    required this.periodStart,
    required this.periodEnd,
  });

  factory AiCreditBalanceModel.fromJson(Map<String, dynamic> json) {
    return AiCreditBalanceModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      totalUsed: (json['totalUsed'] as num?)?.toInt() ?? 0,
      periodStart: json['periodStart'] != null
          ? DateTime.tryParse(json['periodStart'].toString()) ?? DateTime.now()
          : DateTime.now(),
      periodEnd: json['periodEnd'] != null
          ? DateTime.tryParse(json['periodEnd'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'balance': balance,
      'totalUsed': totalUsed,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
    };
  }
}

class AiCreditTransactionModel {
  final String id;
  final String? requestId;
  final String operation;
  final int creditsChange;
  final int creditsBefore;
  final int creditsAfter;
  final String? description;
  final DateTime createdAt;

  AiCreditTransactionModel({
    required this.id,
    this.requestId,
    required this.operation,
    required this.creditsChange,
    required this.creditsBefore,
    required this.creditsAfter,
    this.description,
    required this.createdAt,
  });

  bool get isDeduction => creditsChange < 0;

  factory AiCreditTransactionModel.fromJson(Map<String, dynamic> json) {
    return AiCreditTransactionModel(
      id: json['id'] ?? '',
      requestId: json['requestId'],
      operation: json['operation'] ?? '',
      creditsChange: (json['creditsChange'] as num?)?.toInt() ?? 0,
      creditsBefore: (json['creditsBefore'] as num?)?.toInt() ?? 0,
      creditsAfter: (json['creditsAfter'] as num?)?.toInt() ?? 0,
      description: json['description'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
