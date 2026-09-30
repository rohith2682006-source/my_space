class ShareLinkModel {
  final String id;
  final String token;
  final String permission;
  final bool hasPassword;
  final DateTime? expiresAt;
  final int? maxDownloads;
  final int downloadCount;
  final String shareUrl;
  final String? downloadUrl;
  final String targetType;
  final String targetName;
  final String? targetIcon;
  final DateTime createdAt;

  ShareLinkModel({
    required this.id,
    required this.token,
    required this.permission,
    this.hasPassword = false,
    this.expiresAt,
    this.maxDownloads,
    this.downloadCount = 0,
    required this.shareUrl,
    this.downloadUrl,
    required this.targetType,
    required this.targetName,
    this.targetIcon,
    required this.createdAt,
  });

  factory ShareLinkModel.fromJson(Map<String, dynamic> json) {
    String targetType = 'file';
    String targetName = 'Item';
    String? targetIcon;

    if (json['target'] is Map<String, dynamic>) {
      final target = json['target'] as Map<String, dynamic>;
      targetType = target['type'] ?? (target['icon'] != null ? 'space' : 'file');
      targetName = target['name'] ?? 'Shared Item';
      targetIcon = target['icon'];
    }

    final token = json['token'] ?? '';
    final defaultUrl = 'http://localhost:3000/share/$token';

    return ShareLinkModel(
      id: json['id'] ?? '',
      token: token,
      permission: json['permission'] ?? 'VIEW',
      hasPassword: json['hasPassword'] ?? false,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      maxDownloads: json['maxDownloads'] != null
          ? int.tryParse(json['maxDownloads'].toString())
          : null,
      downloadCount: json['downloadCount'] != null
          ? int.tryParse(json['downloadCount'].toString()) ?? 0
          : 0,
      shareUrl: json['shareUrl'] ?? defaultUrl,
      downloadUrl: json['downloadUrl'],
      targetType: targetType,
      targetName: targetName,
      targetIcon: targetIcon,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isLimitReached {
    if (maxDownloads == null) return false;
    return downloadCount >= maxDownloads!;
  }
}
