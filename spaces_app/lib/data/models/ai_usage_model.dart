class AiOperationStat {
  final String operation;
  final int count;

  AiOperationStat({required this.operation, required this.count});

  factory AiOperationStat.fromJson(Map<String, dynamic> json) {
    return AiOperationStat(
      operation: json['operation'] ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AiUsageModel {
  final int balance;
  final int totalUsedCredits;
  final int totalQueries;
  final int monthlyQueries;
  final int totalTokens;
  final double estimatedCostUsd;
  final List<AiOperationStat> operationsBreakdown;
  final List<dynamic> recentQueries;

  AiUsageModel({
    required this.balance,
    required this.totalUsedCredits,
    required this.totalQueries,
    required this.monthlyQueries,
    required this.totalTokens,
    required this.estimatedCostUsd,
    required this.operationsBreakdown,
    required this.recentQueries,
  });

  factory AiUsageModel.fromJson(Map<String, dynamic> json) {
    final ops = (json['operationsBreakdown'] as List<dynamic>?)
            ?.map((e) => AiOperationStat.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AiUsageModel(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      totalUsedCredits: (json['totalUsedCredits'] as num?)?.toInt() ?? 0,
      totalQueries: (json['totalQueries'] as num?)?.toInt() ?? 0,
      monthlyQueries: (json['monthlyQueries'] as num?)?.toInt() ?? 0,
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      estimatedCostUsd: (json['estimatedCostUsd'] as num?)?.toDouble() ?? 0.0,
      operationsBreakdown: ops,
      recentQueries: json['recentQueries'] as List<dynamic>? ?? [],
    );
  }
}
