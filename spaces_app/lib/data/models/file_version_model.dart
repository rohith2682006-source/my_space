class FileVersionModel {
  final String id;
  final String fileId;
  final int versionNumber;
  final String size;
  final String uploadedBy;
  final String? uploaderName;
  final DateTime createdAt;
  final String? note;

  FileVersionModel({
    required this.id,
    required this.fileId,
    required this.versionNumber,
    required this.size,
    required this.uploadedBy,
    this.uploaderName,
    required this.createdAt,
    this.note,
  });

  factory FileVersionModel.fromJson(Map<String, dynamic> json) {
    return FileVersionModel(
      id: json['id'] ?? '',
      fileId: json['fileId'] ?? '',
      versionNumber: json['versionNumber'] is int
          ? json['versionNumber']
          : int.tryParse(json['versionNumber']?.toString() ?? '1') ?? 1,
      size: json['size']?.toString() ?? '0',
      uploadedBy: json['uploadedBy'] ?? '',
      uploaderName: json['uploaderName'] ?? json['uploader']?['firstName'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: json['note'],
    );
  }
}
