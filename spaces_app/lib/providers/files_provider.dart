import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/services/realtime_service.dart';
import '../data/models/file_model.dart';
import '../data/models/space_model.dart';
import '../data/models/storage_stats_model.dart';

class UploadItem {
  final String filename;
  final List<int> bytes;
  UploadItem({required this.filename, required this.bytes});
}

class FilesProvider extends ChangeNotifier {
  List<FileModel> _files = [];
  List<FileModel> _recentFiles = [];
  List<FileModel> _favoriteFiles = [];
  List<FileModel> _trashFiles = [];
  StorageStatsModel? _storageStats;

  // Search Results
  List<SpaceModel> _searchedSpaces = [];
  List<FileModel> _searchedFiles = [];

  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  String? _currentSpaceId;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;

  FilesProvider() {
    initRealtime();
  }

  List<FileModel> get files => _files;
  List<FileModel> get recentFiles => _recentFiles;
  List<FileModel> get favoriteFiles => _favoriteFiles;
  List<FileModel> get trashFiles => _trashFiles;
  StorageStatsModel? get storageStats => _storageStats;
  List<SpaceModel> get searchedSpaces => _searchedSpaces;
  List<FileModel> get searchedFiles => _searchedFiles;

  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get errorMessage => _errorMessage;

  Future<void> fetchFilesInSpace(
    String spaceId, {
    String? category,
    String? search,
    String sortBy = 'createdAt',
    String order = 'desc',
  }) async {
    _currentSpaceId = spaceId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url =
        '${ApiEndpoints.spaceFiles(spaceId)}?sortBy=$sortBy&order=$order';
    if (category != null && category.isNotEmpty && category != 'ALL') {
      url += '&category=$category';
    }
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }

    final response = await ApiClient.get(url);
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data is List
          ? response.data
          : (response.data is Map && response.data['data'] is List
                ? response.data['data']
                : []);
      _files = list.map((item) => FileModel.fromJson(item)).toList();
    } else {
      _errorMessage = response.message ?? 'Failed to load files';
    }
    notifyListeners();
  }

  Future<bool> uploadFile({
    required String spaceId,
    required List<int> bytes,
    required String filename,
  }) async {
    _isUploading = true;
    _uploadProgress = 0.2;
    notifyListeners();

    final response = await ApiClient.uploadFile(
      url: ApiEndpoints.uploadFile(spaceId),
      bytes: bytes,
      filename: filename,
    );

    _uploadProgress = 1.0;
    _isUploading = false;

    if (response.success && response.data != null) {
      final uploadedFile = FileModel.fromJson(response.data);
      _files.insert(0, uploadedFile);
      notifyListeners();
      if (_isIndexable(uploadedFile) &&
          uploadedFile.indexStatus == 'PROCESSING') {
        _pollIndexStatus(uploadedFile.id);
      }
      return true;
    } else {
      _errorMessage = response.message ?? 'Upload failed';
      notifyListeners();
      return false;
    }
  }

  Future<int> uploadMultipleFiles({
    required String spaceId,
    required List<UploadItem> items,
  }) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    var successCount = 0;
    final total = items.length;

    for (var index = 0; index < total; index += 1) {
      final item = items[index];
      final response = await ApiClient.uploadFile(
        url: ApiEndpoints.uploadFile(spaceId),
        bytes: item.bytes,
        filename: item.filename,
      );
      if (response.success && response.data != null) {
        final uploadedFile = FileModel.fromJson(response.data);
        _files.insert(0, uploadedFile);
        if (_isIndexable(uploadedFile) &&
            uploadedFile.indexStatus == 'PROCESSING') {
          _pollIndexStatus(uploadedFile.id);
        }
        successCount += 1;
      }
      _uploadProgress = (index + 1) / total;
      notifyListeners();
    }

    _isUploading = false;
    _uploadProgress = 0.0;
    notifyListeners();
    return successCount;
  }

  Future<bool> createNoteOrLink({
    required String spaceId,
    required String name,
    required String type, // 'NOTE' | 'LINK'
    required String content,
  }) async {
    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.post(
      ApiEndpoints.createNoteOrLink,
      body: {
        'spaceId': spaceId,
        'name': name.trim(),
        'type': type,
        'content': content.trim(),
      },
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      final newFile = FileModel.fromJson(response.data);
      _files.insert(0, newFile);
      notifyListeners();
      if (type == 'NOTE' && newFile.indexStatus == 'PROCESSING') {
        _pollIndexStatus(newFile.id);
      }
      return true;
    }
    return false;
  }

  bool _isIndexable(FileModel file) => const {
    'pdf',
    'txt',
    'md',
    'markdown',
  }.contains(file.extension.toLowerCase());

  Future<void> reindexDocument(String fileId) async {
    _updateIndexStatus(fileId, 'PROCESSING', null);
    final response = await ApiClient.post(
      ApiEndpoints.aiReindexDocument(fileId),
    );
    if (!response.success) {
      _updateIndexStatus(fileId, 'FAILED', response.message);
      return;
    }
    await _pollIndexStatus(fileId);
  }

  Future<int> reindexExistingDocuments() async {
    final queuedFileIds = <String>{};
    for (var batch = 0; batch < 5; batch += 1) {
      final response = await ApiClient.post(
        ApiEndpoints.aiReindexExisting,
        body: {'excludeFileIds': queuedFileIds.toList()},
      );
      if (!response.success || response.data is! Map) {
        throw Exception(
          response.message ?? 'Unable to start document indexing.',
        );
      }
      final nextIds = (response.data['queuedFileIds'] as List? ?? [])
          .cast<String>();
      if (nextIds.isEmpty) break;
      queuedFileIds.addAll(nextIds);
      for (final fileId in nextIds) {
        _pollIndexStatus(fileId);
      }
    }
    return queuedFileIds.length;
  }

  Future<void> _pollIndexStatus(String fileId) async {
    for (var attempt = 0; attempt < 30; attempt += 1) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final response = await ApiClient.get(
        ApiEndpoints.aiDocumentIndexStatus(fileId),
      );
      if (!response.success || response.data is! Map) return;
      final status = response.data['indexStatus'] as String? ?? 'FAILED';
      final error = response.data['indexError'] as String?;
      _updateIndexStatus(fileId, status, error);
      if (!{'PROCESSING', 'INDEXING', 'UPLOADING'}.contains(status)) return;
    }
  }

  Future<bool> setAiSearchAccess(String fileId, bool enabled) async {
    final response = await ApiClient.patch(
      ApiEndpoints.fileAiAccess(fileId),
      body: {'enabled': enabled},
    );
    if (!response.success || response.data is! Map) return false;

    final data = response.data as Map;
    _updateAiSearchState(
      fileId,
      enabled,
      data['indexStatus'] as String? ?? (enabled ? 'PROCESSING' : 'DISABLED'),
    );
    if (enabled) _pollIndexStatus(fileId);
    return true;
  }

  void _updateAiSearchState(String fileId, bool enabled, String status) {
    FileModel update(FileModel file) => file.id == fileId
        ? file.copyWith(aiSearchEnabled: enabled, indexStatus: status)
        : file;
    _files = _files.map(update).toList();
    _recentFiles = _recentFiles.map(update).toList();
    _favoriteFiles = _favoriteFiles.map(update).toList();
    _searchedFiles = _searchedFiles.map(update).toList();
    notifyListeners();
  }

  void _updateIndexStatus(String fileId, String status, String? error) {
    FileModel update(FileModel file) => file.id == fileId
        ? file.copyWith(indexStatus: status, indexError: error)
        : file;
    _files = _files.map(update).toList();
    _recentFiles = _recentFiles.map(update).toList();
    _favoriteFiles = _favoriteFiles.map(update).toList();
    _searchedFiles = _searchedFiles.map(update).toList();
    notifyListeners();
  }

  Future<void> toggleFavorite(FileModel file) async {
    final originalState = file.isStarred;
    final updated = file.copyWith(isStarred: !originalState);

    // Optimistic UI update
    final index = _files.indexWhere((f) => f.id == file.id);
    if (index != -1) {
      _files[index] = updated;
    }
    final favIdx = _favoriteFiles.indexWhere((f) => f.id == file.id);
    if (originalState && favIdx != -1) {
      _favoriteFiles.removeAt(favIdx);
    } else if (!originalState) {
      _favoriteFiles.insert(0, updated);
    }
    notifyListeners();

    final response = await ApiClient.post(ApiEndpoints.fileFavorite(file.id));
    if (!response.success) {
      // Revert if failed
      if (index != -1) _files[index] = file;
      notifyListeners();
    }
  }

  Future<bool> trashFile(String fileId) async {
    final response = await ApiClient.post(ApiEndpoints.fileTrash(fileId));
    if (response.success) {
      _files.removeWhere((f) => f.id == fileId);
      _recentFiles.removeWhere((f) => f.id == fileId);
      _favoriteFiles.removeWhere((f) => f.id == fileId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> restoreFile(String fileId) async {
    final response = await ApiClient.post(ApiEndpoints.fileRestore(fileId));
    if (response.success) {
      _trashFiles.removeWhere((f) => f.id == fileId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deletePermanently(String fileId) async {
    final response = await ApiClient.delete(ApiEndpoints.filePermanent(fileId));
    if (response.success) {
      _trashFiles.removeWhere((f) => f.id == fileId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> renameFile(String fileId, String newName) async {
    final response = await ApiClient.patch(
      ApiEndpoints.fileRename(fileId),
      body: {'name': newName.trim()},
    );

    if (response.success && response.data != null) {
      final updated = FileModel.fromJson(response.data);
      final idx = _files.indexWhere((f) => f.id == fileId);
      if (idx != -1) {
        _files[idx] = updated;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> moveFile(String fileId, String targetSpaceId) async {
    final response = await ApiClient.patch(
      ApiEndpoints.fileMove(fileId),
      body: {'targetSpaceId': targetSpaceId},
    );

    if (response.success) {
      _files.removeWhere((f) => f.id == fileId);
      _recentFiles.removeWhere((f) => f.id == fileId);
      _favoriteFiles.removeWhere((f) => f.id == fileId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> fetchRecent() async {
    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.get(ApiEndpoints.recent);
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data;
      _recentFiles = list.map((item) => FileModel.fromJson(item)).toList();
    }
    notifyListeners();
  }

  Future<void> fetchFavorites() async {
    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.get(ApiEndpoints.favorites);
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data;
      _favoriteFiles = list.map((item) => FileModel.fromJson(item)).toList();
    }
    notifyListeners();
  }

  Future<void> fetchTrash() async {
    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.get(ApiEndpoints.trash);
    _isLoading = false;

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data;
      _trashFiles = list.map((item) => FileModel.fromJson(item)).toList();
    }
    notifyListeners();
  }

  Future<void> fetchStorageStats() async {
    final response = await ApiClient.get(ApiEndpoints.storage);
    if (response.success && response.data != null) {
      _storageStats = StorageStatsModel.fromJson(response.data);
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchedSpaces = [];
      _searchedFiles = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final response = await ApiClient.get(
      '${ApiEndpoints.search}?q=${Uri.encodeComponent(query.trim())}',
    );
    _isLoading = false;

    if (response.success && response.data != null && response.data is Map) {
      final data = response.data;
      final List<dynamic> spacesList = data['spaces'] is List
          ? data['spaces']
          : [];
      final List<dynamic> filesList = data['files'] is List
          ? data['files']
          : (data['files'] is Map && data['files']['data'] is List
                ? data['files']['data']
                : []);

      _searchedSpaces = spacesList.map((s) => SpaceModel.fromJson(s)).toList();
      _searchedFiles = filesList.map((f) => FileModel.fromJson(f)).toList();
    }
    notifyListeners();
  }

  // ─── Realtime Event Handlers ───────────────────────────────────────────────

  void initRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription =
        RealtimeService.instance.events.listen(_handleRealtimeEvent);
    RealtimeService.instance.start();
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    switch (event.event) {
      case 'FILE_UPLOADED':
        final spaceId = event.data['spaceId']?.toString();
        if (_currentSpaceId == null || _currentSpaceId == spaceId) {
          final fileId = event.data['fileId']?.toString();
          if (fileId != null && !_files.any((f) => f.id == fileId)) {
            try {
              final newFile = FileModel(
                id: fileId,
                name: event.data['name'] ?? '',
                originalName: event.data['originalName'] ?? event.data['name'] ?? '',
                mimeType: event.data['mimeType'] ?? 'application/octet-stream',
                extension: event.data['extension'] ?? '',
                size: event.data['size']?.toString() ?? '0',
                storageKey: '',
                spaceId: spaceId ?? '',
                uploadedBy: '',
                category: event.data['category'] ?? 'OTHER',
                createdAt: DateTime.tryParse(event.data['createdAt'] ?? '') ??
                    DateTime.now(),
                updatedAt: DateTime.now(),
                aiSearchEnabled: event.data['aiSearchEnabled'] == true,
                indexStatus: event.data['indexStatus'] ?? 'NOT_INDEXED',
              );
              _files.insert(0, newFile);
              notifyListeners();
            } catch (_) {}
          }
        }
        break;

      case 'FILE_RENAMED':
        final fileId = event.data['fileId']?.toString();
        final newName = event.data['newName']?.toString();
        if (fileId != null && newName != null) {
          _updateFileInLists(fileId, (f) => f.copyWith(name: newName));
        }
        break;

      case 'FILE_MOVED':
        final fileId = event.data['fileId']?.toString();
        final targetSpaceId = event.data['targetSpaceId']?.toString();
        if (fileId != null &&
            _currentSpaceId != null &&
            _currentSpaceId != targetSpaceId) {
          _files.removeWhere((f) => f.id == fileId);
          notifyListeners();
        }
        break;

      case 'FILE_DELETED':
        final fileId = event.data['fileId']?.toString();
        if (fileId != null) {
          _files.removeWhere((f) => f.id == fileId);
          _recentFiles.removeWhere((f) => f.id == fileId);
          _favoriteFiles.removeWhere((f) => f.id == fileId);
          notifyListeners();
        }
        break;

      case 'FILE_RESTORED':
        final fileId = event.data['fileId']?.toString();
        if (fileId != null) {
          _trashFiles.removeWhere((f) => f.id == fileId);
          notifyListeners();
        }
        break;

      case 'FILE_AI_ACCESS_CHANGED':
        final fileId = event.data['fileId']?.toString();
        final enabled = event.data['aiSearchEnabled'] == true;
        final status = event.data['indexStatus']?.toString() ??
            (enabled ? 'QUEUED' : 'NOT_INDEXED');
        if (fileId != null) {
          _updateFileInLists(
            fileId,
            (f) => f.copyWith(aiSearchEnabled: enabled, indexStatus: status),
          );
        }
        break;

      case 'AI_READY':
      case 'AI_FAILED':
        final fileId = event.data['fileId']?.toString();
        final status = event.data['status']?.toString() ??
            (event.event == 'AI_READY' ? 'READY' : 'FAILED');
        if (fileId != null) {
          _updateFileInLists(fileId, (f) => f.copyWith(indexStatus: status));
        }
        break;
    }
  }

  void _updateFileInLists(
    String fileId,
    FileModel Function(FileModel) updater,
  ) {
    bool changed = false;
    final fileIdx = _files.indexWhere((f) => f.id == fileId);
    if (fileIdx != -1) {
      _files[fileIdx] = updater(_files[fileIdx]);
      changed = true;
    }
    final recentIdx = _recentFiles.indexWhere((f) => f.id == fileId);
    if (recentIdx != -1) {
      _recentFiles[recentIdx] = updater(_recentFiles[recentIdx]);
      changed = true;
    }
    final favIdx = _favoriteFiles.indexWhere((f) => f.id == fileId);
    if (favIdx != -1) {
      _favoriteFiles[favIdx] = updater(_favoriteFiles[favIdx]);
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
