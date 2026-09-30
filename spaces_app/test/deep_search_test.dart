import 'package:flutter_test/flutter_test.dart';

class ChatSourceTestModel {
  final String id;
  final String name;
  final String spaceName;
  final DateTime updatedAt;
  final int citationNumber;
  final int? pageNumber;
  final String fileType;
  final String? excerpt;

  const ChatSourceTestModel({
    required this.id,
    required this.name,
    required this.spaceName,
    required this.updatedAt,
    required this.citationNumber,
    this.pageNumber,
    this.fileType = '',
    this.excerpt,
  });

  factory ChatSourceTestModel.fromJson(Map<String, dynamic> json) {
    return ChatSourceTestModel(
      id: json['id'] as String? ?? json['file_id'] as String? ?? '',
      name: json['name'] as String? ?? json['file_name'] as String? ?? 'Untitled',
      spaceName: json['spaceName'] as String? ?? json['space_name'] as String? ?? 'Space',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? json['updated_at'] as String? ?? '') ?? DateTime.now(),
      citationNumber: json['citationNumber'] as int? ?? json['id'] as int? ?? 1,
      pageNumber: json['pageNumber'] as int? ?? json['page_number'] as int?,
      fileType: json['fileType'] as String? ?? json['file_type'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
    );
  }
}

void main() {
  group('Deep Search Citation Tests', () {
    test('parses PDF citation with page number correctly', () {
      final json = {
        'id': 'file-123',
        'name': 'Cloud_Computing.pdf',
        'spaceName': 'Projects',
        'updatedAt': '2026-03-15T10:00:00.000Z',
        'citationNumber': 1,
        'pageNumber': 12,
        'fileType': 'pdf',
        'excerpt': 'Cloud resources scale dynamically according to workload.',
      };

      final source = ChatSourceTestModel.fromJson(json);

      expect(source.id, 'file-123');
      expect(source.name, 'Cloud_Computing.pdf');
      expect(source.spaceName, 'Projects');
      expect(source.citationNumber, 1);
      expect(source.pageNumber, 12);
      expect(source.fileType, 'pdf');
      expect(source.excerpt, contains('Cloud resources scale'));
    });

    test('parses Note citation without page number correctly', () {
      final json = {
        'id': 'note-456',
        'name': 'Architecture Notes',
        'spaceName': 'Engineering',
        'updatedAt': '2026-03-14T08:30:00.000Z',
        'citationNumber': 2,
        'pageNumber': null,
        'fileType': 'md',
        'excerpt': 'Microservices communicate asynchronously via events.',
      };

      final source = ChatSourceTestModel.fromJson(json);

      expect(source.id, 'note-456');
      expect(source.name, 'Architecture Notes');
      expect(source.spaceName, 'Engineering');
      expect(source.citationNumber, 2);
      expect(source.pageNumber, isNull);
      expect(source.fileType, 'md');
    });
  });
}
