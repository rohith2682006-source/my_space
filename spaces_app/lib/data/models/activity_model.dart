class ActivityModel {
  final String id;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? spaceName;
  final String? spaceIcon;
  final String? spaceColor;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  ActivityModel({
    required this.id,
    required this.action,
    this.targetType,
    this.targetId,
    this.spaceName,
    this.spaceIcon,
    this.spaceColor,
    this.metadata = const {},
    required this.createdAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    String? spaceName;
    String? spaceIcon;
    String? spaceColor;

    if (json['space'] is Map<String, dynamic>) {
      final s = json['space'] as Map<String, dynamic>;
      spaceName = s['name'];
      spaceIcon = s['icon'];
      spaceColor = s['color'];
    }

    return ActivityModel(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      targetType: json['targetType'],
      targetId: json['targetId'],
      spaceName: spaceName,
      spaceIcon: spaceIcon,
      spaceColor: spaceColor,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : {},
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get actionDescription {
    switch (action) {
      case 'FILE_UPLOADED':
        final name = metadata['name'] ?? metadata['fileName'] ?? 'file';
        return 'Uploaded "$name"';
      case 'FILE_RENAMED':
        final newName = metadata['newName'] ?? 'file';
        return 'Renamed file to "$newName"';
      case 'FILE_MOVED':
        final name = metadata['fileName'] ?? 'file';
        return 'Moved "$name"';
      case 'FILE_TRASHED':
        final name = metadata['fileName'] ?? 'file';
        return 'Moved "$name" to trash';
      case 'FILE_RESTORED':
        final name = metadata['fileName'] ?? 'file';
        return 'Restored "$name" from trash';
      case 'FILE_DELETED':
        final name = metadata['fileName'] ?? 'file';
        return 'Permanently deleted "$name"';
      case 'SPACE_CREATED':
        final name = metadata['name'] ?? spaceName ?? 'new space';
        return 'Created space "$name"';
      case 'SPACE_UPDATED':
        return 'Updated space settings';
      case 'SHARE_LINK_CREATED':
        return 'Created a real-time share link';
      case 'NOTE_CREATED':
        final title = metadata['title'] ?? 'note';
        return 'Created note "$title"';
      case 'LINK_CREATED':
        final title = metadata['title'] ?? 'link';
        return 'Bookmarked link "$title"';
      default:
        return action.replaceAll('_', ' ').toLowerCase();
    }
  }

  String get iconEmoji {
    switch (action) {
      case 'FILE_UPLOADED':
        return '📤';
      case 'FILE_RENAMED':
        return '✏️';
      case 'FILE_MOVED':
        return '📦';
      case 'FILE_TRASHED':
      case 'FILE_DELETED':
        return '🗑️';
      case 'FILE_RESTORED':
        return '♻️';
      case 'SPACE_CREATED':
        return '🚀';
      case 'SHARE_LINK_CREATED':
        return '🔗';
      case 'NOTE_CREATED':
        return '📝';
      case 'LINK_CREATED':
        return '🌐';
      default:
        return '⚡';
    }
  }
}
