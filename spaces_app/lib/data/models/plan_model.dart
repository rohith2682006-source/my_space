class PlanModel {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final int storageLimitBytes;
  final int maxFileSize;
  final int maxSpaces;
  final double priceMonthly;
  final double priceYearly;
  final bool isActive;
  final int aiCreditsMonthly;
  final int quickSearchLimit;
  final int deepSearchLimit;
  final int aiEnabledFileLimit;

  PlanModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.storageLimitBytes,
    required this.maxFileSize,
    required this.maxSpaces,
    required this.priceMonthly,
    required this.priceYearly,
    this.isActive = true,
    required this.aiCreditsMonthly,
    required this.quickSearchLimit,
    required this.deepSearchLimit,
    required this.aiEnabledFileLimit,
  });

  String get storageFormatted {
    final gb = storageLimitBytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(0)} GB';
    final mb = storageLimitBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      description: json['description'] ?? '',
      storageLimitBytes: (json['storageLimitBytes'] as num?)?.toInt() ?? 0,
      maxFileSize: (json['maxFileSize'] as num?)?.toInt() ?? 0,
      maxSpaces: (json['maxSpaces'] as num?)?.toInt() ?? 0,
      priceMonthly: (json['priceMonthly'] as num?)?.toDouble() ?? 0.0,
      priceYearly: (json['priceYearly'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] ?? true,
      aiCreditsMonthly: (json['aiCreditsMonthly'] as num?)?.toInt() ?? 0,
      quickSearchLimit: (json['quickSearchLimit'] as num?)?.toInt() ?? 0,
      deepSearchLimit: (json['deepSearchLimit'] as num?)?.toInt() ?? 0,
      aiEnabledFileLimit: (json['aiEnabledFileLimit'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'description': description,
      'storageLimitBytes': storageLimitBytes,
      'maxFileSize': maxFileSize,
      'maxSpaces': maxSpaces,
      'priceMonthly': priceMonthly,
      'priceYearly': priceYearly,
      'isActive': isActive,
      'aiCreditsMonthly': aiCreditsMonthly,
      'quickSearchLimit': quickSearchLimit,
      'deepSearchLimit': deepSearchLimit,
      'aiEnabledFileLimit': aiEnabledFileLimit,
    };
  }
}
