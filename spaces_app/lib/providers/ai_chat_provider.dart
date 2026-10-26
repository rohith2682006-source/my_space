import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class ChatSource {
  final String id;
  final String name;
  final String spaceId;
  final String spaceName;
  final DateTime updatedAt;
  final int citationNumber;
  final int? pageNumber;
  final String fileType;
  final String chunkId;
  final String excerpt;
  final String location;

  const ChatSource({
    required this.id,
    required this.name,
    this.spaceId = '',
    required this.spaceName,
    required this.updatedAt,
    required this.citationNumber,
    this.pageNumber,
    this.fileType = '',
    this.chunkId = '',
    this.excerpt = '',
    this.location = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'spaceId': spaceId,
        'spaceName': spaceName,
        'updatedAt': updatedAt.toIso8601String(),
        'citationNumber': citationNumber,
        'pageNumber': pageNumber,
        'fileType': fileType,
        'chunkId': chunkId,
        'excerpt': excerpt,
        'location': location,
      };

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      id: (json['id'] ?? json['file_id'] ?? json['fileId']) as String? ?? '',
      name: (json['name'] ?? json['file_name'] ?? json['fileName']) as String? ?? 'Untitled',
      spaceId: (json['spaceId'] ?? json['space_id']) as String? ?? '',
      spaceName: (json['spaceName'] ?? json['space_name']) as String? ?? 'Space',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      citationNumber: (json['citationNumber'] ?? json['citation_number']) as int? ?? 1,
      pageNumber: json['pageNumber'] ?? json['page_number'] as int?,
      fileType: (json['fileType'] ?? json['file_type']) as String? ?? '',
      chunkId: (json['chunkId'] ?? json['chunk_id']) as String? ?? '',
      excerpt: (json['excerpt'] ?? '') as String? ?? '',
      location: (json['location'] ?? '') as String? ?? '',
    );
  }
}

class AttachedFileInfo {
  final String id;
  final String name;
  final String spaceId;
  final String? spaceName;
  final String? fileType;

  const AttachedFileInfo({
    required this.id,
    required this.name,
    required this.spaceId,
    this.spaceName,
    this.fileType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'spaceId': spaceId,
        'spaceName': spaceName,
        'fileType': fileType,
      };

  factory AttachedFileInfo.fromJson(Map<String, dynamic> json) => AttachedFileInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        spaceId: json['spaceId'] as String? ?? '',
        spaceName: json['spaceName'] as String?,
        fileType: json['fileType'] as String?,
      );
}

class ChatMessage {
  final String id;
  String text;
  final bool isUser;
  List<ChatSource> sources;
  final Uint8List? imageBytes;
  final DateTime timestamp;
  String? feedback; // 'THUMBS_UP' | 'THUMBS_DOWN' | null
  bool isStreaming;
  String? statusMessage;
  Map<String, dynamic>? searchMetadata;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    List<ChatSource>? sources,
    this.imageBytes,
    DateTime? timestamp,
    this.feedback,
    this.isStreaming = false,
    this.statusMessage,
    this.searchMetadata,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        sources = sources ?? [],
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'sources': sources.map((s) => s.toJson()).toList(),
        'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
        'timestamp': timestamp.toIso8601String(),
        'feedback': feedback,
        'statusMessage': statusMessage,
        'searchMetadata': searchMetadata,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Uint8List? bytes;
    if (json['imageBytes'] != null && (json['imageBytes'] as String).isNotEmpty) {
      try {
        bytes = base64Decode(json['imageBytes'] as String);
      } catch (_) {}
    }
    final rawSources = json['sources'] as List? ?? [];
    return ChatMessage(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      sources: rawSources
          .whereType<Map>()
          .map((s) => ChatSource.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      imageBytes: bytes,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      feedback: json['feedback'] as String?,
      isStreaming: false,
      statusMessage: json['statusMessage'] as String?,
      searchMetadata: json['searchMetadata'] != null
          ? Map<String, dynamic>.from(json['searchMetadata'] as Map)
          : null,
    );
  }
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  String mode; // 'chat' or 'deep'

  ChatSession({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    this.mode = 'chat',
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title = title ?? 'New Chat',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'mode': mode,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List? ?? [];
    return ChatSession(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'New Chat',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMessages
          .whereType<Map>()
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      mode: json['mode'] as String? ?? 'chat',
    );
  }
}

class AiChatProvider extends ChangeNotifier {
  static const String _storageKey = 'spaces_ai_chat_sessions_v2';
  static const String _activeIdKey = 'spaces_ai_chat_active_session_id';

  final List<ChatSession> _sessions = [];
  String? _activeSessionId;
  bool _isSending = false;
  String? _errorMessage;
  String _searchMode = 'chat'; // default to normal chat
  bool _isInitialized = false;

  // RAG Scope: 'ALL', 'SPACE', or 'FILE'
  String? _selectedSpaceId;
  String? _selectedSpaceName;
  String? _selectedFileId;
  String? _selectedFileName;

  // Scoped Attachments
  String? _attachedSpaceId;
  String? _attachedSpaceName;
  int _attachedSpaceFileCount = 0;
  final List<AttachedFileInfo> _attachedFiles = [];
  static final http.Client _sharedHttpClient = http.Client();
  http.Client? _activeStreamClient;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  String get searchMode => _searchMode;
  bool get isInitialized => _isInitialized;

  String? get selectedSpaceId => _selectedSpaceId;
  String? get selectedSpaceName => _selectedSpaceName;
  String? get selectedFileId => _selectedFileId;
  String? get selectedFileName => _selectedFileName;

  String? get attachedSpaceId => _attachedSpaceId ?? _selectedSpaceId;
  String? get attachedSpaceName => _attachedSpaceName ?? _selectedSpaceName;
  int get attachedSpaceFileCount => _attachedSpaceFileCount;
  List<AttachedFileInfo> get attachedFiles => List.unmodifiable(_attachedFiles);
  bool get hasAttachments => attachedSpaceId != null || _attachedFiles.isNotEmpty;

  String get scopeDescription {
    if (_attachedSpaceId != null && _attachedSpaceName != null) {
      final countStr = _attachedSpaceFileCount > 0 ? ' ($_attachedSpaceFileCount files)' : '';
      return 'Folder: $_attachedSpaceName$countStr';
    }
    if (_attachedFiles.isNotEmpty) {
      if (_attachedFiles.length == 1) {
        return 'File: ${_attachedFiles.first.name}';
      }
      return '${_attachedFiles.length} files attached';
    }
    if (_selectedFileId != null && _selectedFileName != null) {
      return 'File: $_selectedFileName';
    }
    if (_selectedSpaceId != null && _selectedSpaceName != null) {
      return 'Folder: $_selectedSpaceName';
    }
    return 'Private Chat (No files accessible)';
  }

  void attachSpace({required String spaceId, required String spaceName, int fileCount = 0}) {
    _attachedSpaceId = spaceId;
    _attachedSpaceName = spaceName;
    _attachedSpaceFileCount = fileCount;
    _selectedSpaceId = spaceId;
    _selectedSpaceName = spaceName;
    notifyListeners();
  }

  void removeAttachedSpace() {
    _attachedSpaceId = null;
    _attachedSpaceName = null;
    _attachedSpaceFileCount = 0;
    _selectedSpaceId = null;
    _selectedSpaceName = null;
    notifyListeners();
  }

  void attachFile(AttachedFileInfo file) {
    if (!_attachedFiles.any((f) => f.id == file.id)) {
      _attachedFiles.add(file);
      _selectedFileId = file.id;
      _selectedFileName = file.name;
      notifyListeners();
    }
  }

  void attachFiles(List<AttachedFileInfo> files) {
    for (final f in files) {
      if (!_attachedFiles.any((existing) => existing.id == f.id)) {
        _attachedFiles.add(f);
      }
    }
    if (_attachedFiles.isNotEmpty) {
      _selectedFileId = _attachedFiles.first.id;
      _selectedFileName = _attachedFiles.first.name;
    }
    notifyListeners();
  }

  void removeAttachedFile(String fileId) {
    _attachedFiles.removeWhere((f) => f.id == fileId);
    if (_attachedFiles.isNotEmpty) {
      _selectedFileId = _attachedFiles.last.id;
      _selectedFileName = _attachedFiles.last.name;
    } else {
      _selectedFileId = null;
      _selectedFileName = null;
    }
    notifyListeners();
  }

  void clearAllAttachments() {
    _attachedSpaceId = null;
    _attachedSpaceName = null;
    _attachedSpaceFileCount = 0;
    _attachedFiles.clear();
    _selectedSpaceId = null;
    _selectedSpaceName = null;
    _selectedFileId = null;
    _selectedFileName = null;
    notifyListeners();
  }

  void setScope({
    String? spaceId,
    String? spaceName,
    String? fileId,
    String? fileName,
  }) {
    _selectedSpaceId = spaceId;
    _selectedSpaceName = spaceName;
    _selectedFileId = fileId;
    _selectedFileName = fileName;
    notifyListeners();
  }

  void clearScope() {
    _selectedSpaceId = null;
    _selectedSpaceName = null;
    _selectedFileId = null;
    _selectedFileName = null;
    _attachedSpaceId = null;
    _attachedSpaceName = null;
    _attachedSpaceFileCount = 0;
    _attachedFiles.clear();
    notifyListeners();
  }

  ChatSession get currentSession {
    if (_activeSessionId != null) {
      final found = _sessions.indexWhere((s) => s.id == _activeSessionId);
      if (found != -1) return _sessions[found];
    }
    if (_sessions.isNotEmpty) {
      _activeSessionId = _sessions.first.id;
      return _sessions.first;
    }
    final newSession = ChatSession(mode: _searchMode);
    _sessions.insert(0, newSession);
    _activeSessionId = newSession.id;
    return newSession;
  }

  List<ChatMessage> get currentMessages => currentSession.messages;

  AiChatProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_storageKey);

      if (dataStr != null && dataStr.isNotEmpty) {
        final List decoded = jsonDecode(dataStr);
        _sessions.clear();
        for (final item in decoded) {
          if (item is Map) {
            _sessions.add(ChatSession.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      if (_sessions.isEmpty) {
        final initialSession = ChatSession(mode: _searchMode);
        _sessions.add(initialSession);
        _activeSessionId = initialSession.id;
      } else {
        // ChatGPT format: Always start with a fresh new chat when opening the app.
        // If the top session is already empty, use it. Otherwise, insert a new session at index 0.
        if (_sessions.first.messages.isEmpty) {
          _activeSessionId = _sessions.first.id;
        } else {
          final newChat = ChatSession(mode: _searchMode);
          _sessions.insert(0, newChat);
          _activeSessionId = newChat.id;
        }
        _searchMode = currentSession.mode;
      }
    } catch (e) {
      debugPrint('Error loading AI chat sessions: $e');
      if (_sessions.isEmpty) {
        final initialSession = ChatSession(mode: _searchMode);
        _sessions.add(initialSession);
        _activeSessionId = initialSession.id;
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = jsonEncode(_sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, dataStr);
      if (_activeSessionId != null) {
        await prefs.setString(_activeIdKey, _activeSessionId!);
      }
    } catch (e) {
      debugPrint('Error saving AI chat sessions: $e');
    }
  }

  void setSearchMode(String mode) {
    _searchMode = mode;
    currentSession.mode = mode;
    _saveToStorage();
    notifyListeners();
  }

  void startNewChat({String? initialMode}) {
    if (currentMessages.isEmpty) {
      if (initialMode != null) setSearchMode(initialMode);
      return;
    }
    final mode = initialMode ?? _searchMode;
    final newSession = ChatSession(mode: mode);
    _sessions.insert(0, newSession);
    _activeSessionId = newSession.id;
    _searchMode = mode;
    _errorMessage = null;
    _saveToStorage();
    notifyListeners();
  }

  void loadSession(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _activeSessionId = sessionId;
      _searchMode = _sessions[index].mode;
      _errorMessage = null;
      _saveToStorage();
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _sessions.removeAt(index);
      if (_activeSessionId == sessionId) {
        if (_sessions.isNotEmpty) {
          _activeSessionId = _sessions.first.id;
          _searchMode = currentSession.mode;
        } else {
          final fresh = ChatSession(mode: _searchMode);
          _sessions.add(fresh);
          _activeSessionId = fresh.id;
        }
      }
      await _saveToStorage();
      notifyListeners();
    }
  }

  Future<void> clearAllSessions() async {
    _sessions.clear();
    final fresh = ChatSession(mode: _searchMode);
    _sessions.add(fresh);
    _activeSessionId = fresh.id;
    _errorMessage = null;
    await _saveToStorage();
    notifyListeners();
  }

  void stopGeneration() {
    if (_isSending && _activeStreamClient != null) {
      _activeStreamClient?.close();
      _activeStreamClient = null;
    }
    if (currentMessages.isNotEmpty && currentMessages.last.isStreaming) {
      currentMessages.last.isStreaming = false;
    }
    _isSending = false;
    notifyListeners();
    _saveToStorage();
  }

  Future<bool> sendFeedback({
    required String messageId,
    required String rating, // 'THUMBS_UP' | 'THUMBS_DOWN'
  }) async {
    final session = currentSession;
    final msgIndex = session.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return false;

    final targetMsg = session.messages[msgIndex];
    String question = 'General query';
    if (msgIndex > 0 && session.messages[msgIndex - 1].isUser) {
      question = session.messages[msgIndex - 1].text;
    }

    final chunkIds = targetMsg.sources.map((s) => s.chunkId).where((c) => c.isNotEmpty).toList();
    final spaceId = targetMsg.sources.isNotEmpty && targetMsg.sources.first.spaceId.isNotEmpty
        ? targetMsg.sources.first.spaceId
        : (_selectedSpaceId ?? 'all');

    // Optimistically update locally
    targetMsg.feedback = rating;
    notifyListeners();
    await _saveToStorage();

    try {
      final res = await ApiClient.post(
        ApiEndpoints.aiFeedback,
        body: {
          'spaceId': spaceId,
          'question': question,
          'answer': targetMsg.text,
          'rating': rating,
          'chunkIds': chunkIds,
        },
      );
      return res.success;
    } catch (e) {
      debugPrint('Error sending feedback: $e');
      return false;
    }
  }

  Future<bool> sendMessage(
    String text, {
    Uint8List? imageBytes,
    void Function(int remainingCredits)? onCreditsUpdated,
    void Function()? onCreditsExhausted,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return false;

    _isSending = true;
    _errorMessage = null;

    final session = currentSession;
    final userMsg = ChatMessage(
      text: trimmed,
      isUser: true,
      imageBytes: imageBytes,
    );

    session.messages.add(userMsg);
    session.updatedAt = DateTime.now();

    if (session.title == 'New Chat' || session.title.isEmpty) {
      session.title = trimmed.length > 35
          ? '${trimmed.substring(0, 35).trim()}...'
          : trimmed;
    }

    notifyListeners();
    await _saveToStorage();

    // Prepare assistant placeholder message for streaming
    final assistantMsg = ChatMessage(
      text: '',
      isUser: false,
      isStreaming: true,
    );
    session.messages.add(assistantMsg);
    notifyListeners();

    try {
      final history = session.messages
          .take(session.messages.length - 2) // exclude user and assistant placeholder
          .skip((session.messages.length - 2 - 12).clamp(0, 12))
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      final List<String> spaceIds = [];
      if (_attachedSpaceId != null) {
        spaceIds.add(_attachedSpaceId!);
      } else if (_selectedSpaceId != null) {
        spaceIds.add(_selectedSpaceId!);
      }
      for (final af in _attachedFiles) {
        if (af.spaceId.isNotEmpty && !spaceIds.contains(af.spaceId)) {
          spaceIds.add(af.spaceId);
        }
      }

      final List<String> fileIds = _attachedFiles.map((f) => f.id).toList();
      if (_selectedFileId != null && !fileIds.contains(_selectedFileId!)) {
        fileIds.add(_selectedFileId!);
      }

      final Map<String, dynamic> requestBody = {
        'message': trimmed,
        'history': history,
        'spaceIds': spaceIds,
        if (fileIds.isNotEmpty) 'fileIds': fileIds,
        if (fileIds.length == 1) 'fileId': fileIds.first,
      };

      if (imageBytes != null) {
        requestBody['imageBase64'] = base64Encode(imageBytes);
        requestBody['imageMimeType'] = 'image/jpeg';
      }

      // Check if streaming is supported for this mode
      final bool useStreaming = imageBytes == null; // Vision uses non-stream endpoint

      // Sub-second general chat route: directly stream from nearest Google edge without multi-hop cloud delay
      final bool isGeneralChat = spaceIds.isEmpty &&
          fileIds.isEmpty &&
          imageBytes == null &&
          session.mode == 'chat';

      if (isGeneralChat) {
        final directSuccess = await _fallbackDirectGeminiChat(
          session: session,
          assistantMsg: assistantMsg,
          prompt: trimmed,
        );

        if (directSuccess && assistantMsg.text.trim().isNotEmpty) {
          assistantMsg.isStreaming = false;
          _errorMessage = null;
          _isSending = false;
          session.updatedAt = DateTime.now();
          await _saveToStorage();
          notifyListeners();
          return true;
        }
      }

      if (useStreaming) {
        final headers = await ApiClient.getHeaders();
        final request = http.Request(
          'POST',
          Uri.parse(session.mode == 'chat'
              ? ApiEndpoints.aiChatStream
              : ApiEndpoints.aiDeepSearchStream),
        );
        request.headers.addAll(headers);
        request.body = jsonEncode(requestBody);

        _activeStreamClient = http.Client();
        var streamedResponse = await _activeStreamClient!
            .send(request)
            .timeout(const Duration(seconds: 7));

        if (streamedResponse.statusCode == 401) {
          final refreshed = await ApiClient.refreshToken();
          if (refreshed) {
            final newHeaders = await ApiClient.getHeaders();
            final retryRequest = http.Request('POST', request.url);
            retryRequest.headers.addAll(newHeaders);
            retryRequest.body = request.body;
            streamedResponse = await _activeStreamClient!
                .send(retryRequest)
                .timeout(const Duration(seconds: 7));
          }
        }

        if (streamedResponse.statusCode != 200) {
          debugPrint('[AI STREAM] Stream returned status ${streamedResponse.statusCode}. Falling back to standard AI API...');
          notifyListeners();

          final fallbackResponse = await ApiClient.post(
            session.mode == 'chat'
                ? ApiEndpoints.aiChat
                : ApiEndpoints.aiDeepSearch,
            body: requestBody,
          );

          if (fallbackResponse.success && fallbackResponse.data != null) {
            final respData = fallbackResponse.data;
            if (respData is Map) {
              assistantMsg.text = (respData['reply'] ?? respData['text'] ?? respData['answer'] ?? respData['message'] ?? '').toString();
              if (respData['sources'] is List) {
                assistantMsg.sources = (respData['sources'] as List)
                    .whereType<Map>()
                    .map((s) => ChatSource.fromJson(Map<String, dynamic>.from(s)))
                    .toList();
              } else if (respData['citations'] is List) {
                assistantMsg.sources = (respData['citations'] as List)
                    .whereType<Map>()
                    .map((s) => ChatSource.fromJson(Map<String, dynamic>.from(s)))
                    .toList();
              }
            } else {
              assistantMsg.text = respData.toString();
            }
            assistantMsg.statusMessage = null;
            assistantMsg.isStreaming = false;
            _isSending = false;
            _errorMessage = null;
            notifyListeners();
            return true;
          }
        }

        final lineStream = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lineStream) {
          if (!_isSending) break; // cancelled via stopGeneration

          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty || !trimmedLine.startsWith('data:')) continue;

          final jsonStr = trimmedLine.replaceFirst('data:', '').trim();
          if (jsonStr.isEmpty) continue;

          try {
            final data = jsonDecode(jsonStr);
            if (data is Map) {
              if (data['event'] == 'status' && data['message'] != null) {
                assistantMsg.statusMessage = data['message'] as String;
                notifyListeners();
              }
              if (data['text'] != null) {
                assistantMsg.text += data['text'] as String;
                notifyListeners();
              }
              if (data['citations'] is List) {
                final rawCitations = data['citations'] as List;
                assistantMsg.sources = rawCitations
                    .whereType<Map>()
                    .map((s) => ChatSource.fromJson(Map<String, dynamic>.from(s)))
                    .toList();
                notifyListeners();
              }
              if (data['done'] == true && data['search_metadata'] is Map) {
                assistantMsg.searchMetadata =
                    Map<String, dynamic>.from(data['search_metadata'] as Map);
                assistantMsg.statusMessage = null; // Clear live status on completion
                notifyListeners();
              }
            }
          } catch (_) {
            // Non-json chunk or partial line
          }
        }
      } else {
        // Fallback or Vision non-stream request
        final response = await ApiClient.post(
          session.mode == 'chat'
              ? ApiEndpoints.aiChat
              : ApiEndpoints.aiDeepSearch,
          body: requestBody,
        );

        final data = response.data;
        if (!response.success) {
          final msg = response.message ?? 'The assistant could not respond.';
          _errorMessage = msg;
          if (response.statusCode == 402 || msg.toLowerCase().contains('credit')) {
            onCreditsExhausted?.call();
          }
          session.messages.remove(assistantMsg);
          _isSending = false;
          notifyListeners();
          return false;
        }

        final reply = data is Map ? (data['reply'] ?? data['answer']) : null;
        final rawSources = data is Map && data['sources'] is List
            ? data['sources'] as List
            : const [];

        assistantMsg.text = reply is String ? reply : '';
        assistantMsg.sources = rawSources
            .whereType<Map>()
            .map((s) => ChatSource.fromJson(Map<String, dynamic>.from(s)))
            .toList();

        if (data is Map && data['remainingCredits'] != null && onCreditsUpdated != null) {
          onCreditsUpdated(data['remainingCredits'] as int);
        }
      }

      // If empty reply after streaming or error occurred, trigger resilient fallback API and Direct Gemini
      if (assistantMsg.text.trim().isEmpty) {
        debugPrint('[AI CHAT] Primary stream returned empty. Attempting standard AI API fallback...');
        try {
          final fallbackResponse = await ApiClient.post(
            session.mode == 'chat'
                ? ApiEndpoints.aiChat
                : ApiEndpoints.aiDeepSearch,
            body: requestBody,
          );
          if (fallbackResponse.success && fallbackResponse.data != null) {
            final respData = fallbackResponse.data;
            if (respData is Map) {
              assistantMsg.text = (respData['reply'] ?? respData['text'] ?? respData['answer'] ?? respData['message'] ?? '').toString();
              if (respData['sources'] is List) {
                assistantMsg.sources = (respData['sources'] as List)
                    .whereType<Map>()
                    .map((s) => ChatSource.fromJson(Map<String, dynamic>.from(s)))
                    .toList();
              }
            } else {
              assistantMsg.text = respData.toString();
            }
          }
        } catch (_) {}

        if (assistantMsg.text.trim().isEmpty) {
          debugPrint('[AI CHAT] Fallback API empty. Triggering resilient Direct Gemini fallback...');
          await _fallbackDirectGeminiChat(
            session: session,
            assistantMsg: assistantMsg,
            prompt: text,
          );
        }

        if (assistantMsg.text.trim().isNotEmpty) {
          _errorMessage = null;
        } else if (_attachedFiles.isEmpty && _attachedSpaceId == null && _selectedSpaceId == null) {
          assistantMsg.text = "I'm here to chat or answer questions. How can I help you today?";
          _errorMessage = null;
        } else {
          assistantMsg.text = "I couldn't find that in your files. Try rephrasing or make sure the relevant file is uploaded to this space.";
          _errorMessage = null;
        }
      } else {
        _errorMessage = null;
      }

      assistantMsg.isStreaming = false;
      session.updatedAt = DateTime.now();
      _isSending = false;
      _activeStreamClient = null;
      await _saveToStorage();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AI Chat Error: $e');
      // If error occurs and message is empty, try direct fallback before giving up
      if (assistantMsg.text.isEmpty) {
        try {
          final recovered = await _fallbackDirectGeminiChat(
            session: session,
            assistantMsg: assistantMsg,
            prompt: text,
          );
          if (recovered && assistantMsg.text.trim().isNotEmpty) {
            _errorMessage = null;
            assistantMsg.isStreaming = false;
            session.updatedAt = DateTime.now();
            _isSending = false;
            _activeStreamClient = null;
            await _saveToStorage();
            notifyListeners();
            return true;
          }
        } catch (_) {}
        session.messages.remove(assistantMsg);
        _errorMessage = 'Network error: $e';
      } else {
        assistantMsg.isStreaming = false;
      }
      _isSending = false;
      _activeStreamClient = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _fallbackDirectGeminiChat({
    required ChatSession session,
    required ChatMessage assistantMsg,
    required String prompt,
  }) async {
    const geminiKey = String.fromEnvironment('GEMINI_API_KEY');
    final models = [
      'gemini-3.5-flash-lite',
      'gemini-3.1-flash-lite',
      'gemini-3.5-flash',
      'gemini-3.8-flash',
      'gemini-flash-latest',
    ];

    final contents = <Map<String, dynamic>>[];
    final recent = session.messages
        .where((m) => m != assistantMsg && m.text.trim().isNotEmpty)
        .toList();
    final windowed = recent.length > 6 ? recent.sublist(recent.length - 6) : recent;

    for (final m in windowed) {
      contents.add({
        'role': m.isUser ? 'user' : 'model',
        'parts': [{'text': m.text}],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [{'text': prompt}],
    });

    String systemText = 'You are Spaces AI, an intelligent, empathetic, and thoughtful conversational assistant for the Spaces platform. Answer helpfully, warmly, and clearly.';
    if (attachedSpaceName != null) {
      systemText += '\n[Attached Knowledge Context]\nThe user is currently interacting with the folder "$attachedSpaceName" ($attachedSpaceFileCount files inside).';
    }
    if (attachedFiles.isNotEmpty) {
      systemText += '\nAttached Files: ${attachedFiles.map((f) => f.name).join(', ')}.';
    }
    if (attachedSpaceName != null || attachedFiles.isNotEmpty) {
      systemText += '\nIf the user asks questions about their folder or files, address them directly and informatively using this context.';
    }

    final payload = {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemText}
        ]
      }
    };

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=$geminiKey',
        );
        final request = http.Request('POST', url)
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(payload);
        final streamed = await _sharedHttpClient.send(request).timeout(const Duration(seconds: 5));

        if (streamed.statusCode == 200) {
          assistantMsg.statusMessage = null;
          final lines = streamed.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter());

          await for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('data:')) {
              final jsonStr = trimmed.substring(5).trim();
              if (jsonStr.isEmpty) continue;
              try {
                final d = jsonDecode(jsonStr);
                final text = d['candidates']?[0]?['content']?['parts']?[0]?['text'];
                if (text is String && text.isNotEmpty) {
                  assistantMsg.text += text;
                  notifyListeners();
                }
              } catch (_) {}
            }
          }

          if (assistantMsg.text.trim().isNotEmpty) {
            assistantMsg.isStreaming = false;
            return true;
          }
        }
      } catch (e) {
        debugPrint('[DIRECT GEMINI FALLBACK] Failed model $model: $e');
      }
    }
    return false;
  }
}
