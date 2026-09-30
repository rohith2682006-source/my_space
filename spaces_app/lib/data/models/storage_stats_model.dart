class StorageStatsModel {
  final String totalUsedBytes;
  final String storageLimitBytes;
  final double usagePercentage;
  final Map<String, String> breakdown;

  StorageStatsModel({
    required this.totalUsedBytes,
    required this.storageLimitBytes,
    required this.usagePercentage,
    required this.breakdown,
  });

  factory StorageStatsModel.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['breakdown'] as Map<String, dynamic>? ?? {};
    final Map<String, String> parsedBreakdown = {};
    rawBreakdown.forEach((key, val) {
      parsedBreakdown[key] = val.toString();
    });

    return StorageStatsModel(
      totalUsedBytes: json['totalUsedBytes']?.toString() ?? '0',
      storageLimitBytes: json['storageLimitBytes']?.toString() ?? '5368709120',
      usagePercentage: (json['usagePercentage'] is num)
          ? (json['usagePercentage'] as num).toDouble()
          : 0.0,
      breakdown: parsedBreakdown,
    );
  }
}
