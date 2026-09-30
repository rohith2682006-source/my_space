class SpaceModel {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final String? coverUrl;
  final String ownerId;
  final bool isPrivate;
  final int fileCount;
  final String totalSize;
  final DateTime lastActivityAt;
  final DateTime createdAt;

  SpaceModel({
    required this.id,
    required this.name,
    this.description,
    this.icon = '📁',
    this.color = '#6366F1',
    this.coverUrl,
    required this.ownerId,
    this.isPrivate = true,
    this.fileCount = 0,
    this.totalSize = '0',
    required this.lastActivityAt,
    required this.createdAt,
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    return SpaceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'] ?? '📁',
      color: json['color'] ?? '#6366F1',
      coverUrl: json['coverUrl'],
      ownerId: json['ownerId'] ?? '',
      isPrivate: json['isPrivate'] ?? true,
      fileCount: json['fileCount'] is int
          ? json['fileCount']
          : int.tryParse(json['fileCount']?.toString() ?? '0') ?? 0,
      totalSize: json['totalSize']?.toString() ?? '0',
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.tryParse(json['lastActivityAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'coverUrl': coverUrl,
      'ownerId': ownerId,
      'isPrivate': isPrivate,
      'fileCount': fileCount,
      'totalSize': totalSize,
    };
  }
}
