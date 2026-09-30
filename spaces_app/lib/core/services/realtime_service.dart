import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/api_endpoints.dart';
import '../../data/services/auth_storage.dart';

class RealtimeEvent {
  final String event;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  RealtimeEvent({
    required this.event,
    required this.data,
    required this.timestamp,
  });

  @override
  String toString() => 'RealtimeEvent($event, $data)';
}

class RealtimeService {
  static final RealtimeService instance = RealtimeService._();
  RealtimeService._();

  final _eventController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventController.stream;

  http.Client? _client;
  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _reconnectTimer;
  int _retrySeconds = 3;

  bool get isConnected => _isConnected;

  void start() {
    _isDisposed = false;
    _connect();
  }

  void stop() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _client?.close();
    _client = null;
    _isConnected = false;
  }

  Future<void> _connect() async {
    if (_isDisposed) return;

    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    _client?.close();
    _client = http.Client();

    try {
      final uri = Uri.parse('${ApiEndpoints.realtimeEvents}?token=$token');
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final streamedResponse = await _client!.send(request);

      if (streamedResponse.statusCode != 200) {
        debugPrint('[Realtime] HTTP error: ${streamedResponse.statusCode}');
        _scheduleReconnect();
        return;
      }

      _isConnected = true;
      _retrySeconds = 3; // Reset backoff on successful connect
      debugPrint('[Realtime] Connected to SSE stream at ${uri.path}');

      String currentEvent = 'MESSAGE';
      final stringStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stringStream) {
        if (_isDisposed) break;

        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          // Event dispatch boundary
          currentEvent = 'MESSAGE';
          continue;
        }

        if (trimmed.startsWith(':')) {
          // Heartbeat comment
          continue;
        }

        if (trimmed.startsWith('event:')) {
          currentEvent = trimmed.substring(6).trim();
        } else if (trimmed.startsWith('data:')) {
          final rawData = trimmed.substring(5).trim();
          try {
            final parsed = jsonDecode(rawData);
            if (parsed is Map<String, dynamic>) {
              final eventObj = RealtimeEvent(
                event: currentEvent,
                data: parsed,
                timestamp: DateTime.now(),
              );
              _eventController.add(eventObj);
            }
          } catch (e) {
            debugPrint('[Realtime] Failed to parse JSON data: $rawData');
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('[Realtime] Connection error: $e');
      }
    } finally {
      _isConnected = false;
      if (!_isDisposed) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retrySeconds), () {
      _retrySeconds = (_retrySeconds * 2).clamp(3, 30);
      _connect();
    });
  }
}
