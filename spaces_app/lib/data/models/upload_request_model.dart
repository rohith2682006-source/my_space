class UploadRequestModel {
  final String id;
  final String title;
  final String? description;
  final String spaceId;
  final String spaceName;
  final String token;
  final String uploadUrl;
  final DateTime? expiresAt;
  final int filesReceived;
  final bool isActive;
  final DateTime createdAt;

  UploadRequestModel({
    required this.id,
    required this.title,
    this.description,
    required this.spaceId,
    required this.spaceName,
    required this.token,
    required this.uploadUrl,
    this.expiresAt,
    this.filesReceived = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory UploadRequestModel.fromJson(Map<String, dynamic> json) {
    return UploadRequestModel(
      id: json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Upload Request',
      description: json['description'],
      spaceId: json['spaceId'] ?? '',
      spaceName: json['spaceName'] ?? json['space']?['name'] ?? '',
      token: json['token'] ?? '',
      uploadUrl: json['uploadUrl'] ?? json['url'] ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      filesReceived: json['filesReceived'] is int
          ? json['filesReceived']
          : int.tryParse(json['filesReceived']?.toString() ?? '0') ?? 0,
      isActive: json['isActive'] ?? json['active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'spaceId': spaceId,
        'token': token,
        'expiresAt': expiresAt?.toIso8601String(),
        'filesReceived': filesReceived,
        'isActive': isActive,
      };

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}
