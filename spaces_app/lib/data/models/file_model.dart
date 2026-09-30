import 'space_model.dart';

class FileModel {
  final String id;
  final String name;
  final String originalName;
  final String mimeType;
  final String extension;
  final String size;
  final String storageKey;
  final String? thumbnailKey;
  final String spaceId;
  final String uploadedBy;
  final String category;
  final bool isStarred;
  final String? content;
  final DateTime? openedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String indexStatus;
  final String? indexError;
  final bool aiSearchEnabled;
  final SpaceModel? space;
  final int? daysRemaining; // For trash files

  FileModel({
    required this.id,
    required this.name,
    required this.originalName,
    required this.mimeType,
    required this.extension,
    required this.size,
    required this.storageKey,
    this.thumbnailKey,
    required this.spaceId,
    required this.uploadedBy,
    required this.category,
    this.isStarred = false,
    this.content,
    this.openedAt,
    required this.createdAt,
    required this.updatedAt,
    this.indexStatus = 'NOT_INDEXED',
    this.indexError,
    this.aiSearchEnabled = false,
    this.space,
    this.daysRemaining,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      originalName: json['originalName'] ?? json['name'] ?? '',
      mimeType: json['mimeType'] ?? 'application/octet-stream',
      extension: json['extension'] ?? '',
      size: json['size']?.toString() ?? '0',
      storageKey: json['storageKey'] ?? '',
      thumbnailKey: json['thumbnailKey'],
      spaceId: json['spaceId'] ?? '',
      uploadedBy: json['uploadedBy'] ?? '',
      category: json['category'] ?? 'OTHER',
      isStarred: json['isStarred'] ?? false,
      content: json['content'],
      openedAt: json['openedAt'] != null
          ? DateTime.tryParse(json['openedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      indexStatus: json['indexStatus'] ?? 'NOT_INDEXED',
      indexError: json['indexError'],
      aiSearchEnabled: json['aiSearchEnabled'] == true,
      space: json['space'] != null ? SpaceModel.fromJson(json['space']) : null,
      daysRemaining: json['daysRemaining'] is int
          ? json['daysRemaining']
          : null,
    );
  }

  FileModel copyWith({
    bool? isStarred,
    String? name,
    String? indexStatus,
    String? indexError,
    bool? aiSearchEnabled,
  }) {
    return FileModel(
      id: id,
      name: name ?? this.name,
      originalName: originalName,
      mimeType: mimeType,
      extension: extension,
      size: size,
      storageKey: storageKey,
      thumbnailKey: thumbnailKey,
      spaceId: spaceId,
      uploadedBy: uploadedBy,
      category: category,
      isStarred: isStarred ?? this.isStarred,
      content: content,
      openedAt: openedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      indexStatus: indexStatus ?? this.indexStatus,
      indexError: indexError,
      aiSearchEnabled: aiSearchEnabled ?? this.aiSearchEnabled,
      space: space,
      daysRemaining: daysRemaining,
    );
  }
}
