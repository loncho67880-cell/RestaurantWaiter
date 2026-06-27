import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:restaurantwaiter/domain/models/table_session_snapshot.dart';
import 'package:signalr_netcore/ihub_protocol.dart';
import 'package:signalr_netcore/signalr_client.dart';

class TableSessionRealtimeService {
  TableSessionRealtimeService({required String apiBaseUrl})
      : _hubUrl = _buildHubUrl(apiBaseUrl);

  final String _hubUrl;
  HubConnection? _connection;
  String? _accessToken;
  final Map<String, int> _sessionRefCounts = {};
  final Map<String, StreamController<TableSessionSnapshot>> _controllers = {};
  final Map<String, TableSessionSnapshot> _lastSnapshots = {};
  final Map<String, VoidCallback> _refreshCallbacks = {};

  static const _sessionEvents = [
    'CartUpdated',
    'ParticipantJoined',
    'ParticipantConfirmed',
    'TableFinalized',
    'SessionConfirmed',
  ];

  static String _buildHubUrl(String apiBaseUrl) {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return '$base/hubs/table-sessions';
  }

  String _normalizeId(String id) => id.toLowerCase().trim();

  Stream<TableSessionSnapshot> updatesFor(String sessionId) {
    return _controllerFor(sessionId).stream;
  }

  TableSessionSnapshot? latestSnapshot(String sessionId) {
    return _lastSnapshots[_normalizeId(sessionId)];
  }

  void setRefreshCallback(String sessionId, VoidCallback callback) {
    _refreshCallbacks[_normalizeId(sessionId)] = callback;
  }

  void clearRefreshCallback(String sessionId) {
    _refreshCallbacks.remove(_normalizeId(sessionId));
  }

  Future<void> watchSession({
    required String sessionId,
    required String accessToken,
  }) async {
    final normalizedId = _normalizeId(sessionId);
    _accessToken = accessToken;
    await _ensureConnected();
    _sessionRefCounts[normalizedId] = (_sessionRefCounts[normalizedId] ?? 0) + 1;
    if (_sessionRefCounts[normalizedId] == 1) {
      await _connection!.invoke('JoinSession', args: [sessionId]);
      if (kDebugMode) {
        debugPrint('[TableSessionRealtime] Joined session $sessionId');
      }
    }
  }

  Future<void> unwatchSession(String sessionId) async {
    final normalizedId = _normalizeId(sessionId);
    final count = _sessionRefCounts[normalizedId];
    if (count == null) return;

    if (count <= 1) {
      _sessionRefCounts.remove(normalizedId);
      _refreshCallbacks.remove(normalizedId);
      if (_connection?.state == HubConnectionState.Connected) {
        try {
          await _connection!.invoke('LeaveSession', args: [sessionId]);
        } catch (e, stack) {
          debugPrint('[TableSessionRealtime] LeaveSession failed: $e\n$stack');
        }
      }
    } else {
      _sessionRefCounts[normalizedId] = count - 1;
    }

    if (_sessionRefCounts.isEmpty) {
      await _stopConnection();
    }
  }

  Future<void> dispose() async {
    for (final sessionId in _sessionRefCounts.keys.toList()) {
      _sessionRefCounts[sessionId] = 1;
      await unwatchSession(sessionId);
    }
    await _stopConnection();
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    _lastSnapshots.clear();
    _refreshCallbacks.clear();
  }

  StreamController<TableSessionSnapshot> _controllerFor(String sessionId) {
    return _controllers.putIfAbsent(
      _normalizeId(sessionId),
      () => StreamController<TableSessionSnapshot>.broadcast(),
    );
  }

  Future<void> _ensureConnected() async {
    if (_connection?.state == HubConnectionState.Connected) return;

    await _stopConnection();

    final token = _accessToken ?? '';
    final headers = MessageHeaders()
      ..setHeaderValue('ngrok-skip-browser-warning', 'true')
      ..setHeaderValue('User-Agent', 'RestaurantWaiter/1.0');

    _connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            headers: headers,
            skipNegotiation: false,
            requestTimeout: 30000,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.onreconnected(({connectionId}) async {
      if (kDebugMode) {
        debugPrint('[TableSessionRealtime] Reconnected ($connectionId)');
      }
      await _rejoinSessions();
      _scheduleRefresh('reconnected');
    });

    _connection!.onclose(({error}) {
      if (kDebugMode) {
        debugPrint('[TableSessionRealtime] Connection closed: $error');
      }
    });

    for (final eventName in _sessionEvents) {
      _connection!.on(eventName, (arguments) {
        _handleSessionEvent(arguments, eventName);
      });
    }

    await _connection!.start();
    if (kDebugMode) {
      debugPrint('[TableSessionRealtime] Connected to $_hubUrl');
    }
  }

  Future<void> _rejoinSessions() async {
    if (_connection?.state != HubConnectionState.Connected) return;
    for (final normalizedId in _sessionRefCounts.keys) {
      try {
        await _connection!.invoke('JoinSession', args: [normalizedId]);
      } catch (e, stack) {
        debugPrint(
          '[TableSessionRealtime] Rejoin failed for $normalizedId: $e\n$stack',
        );
      }
    }
  }

  void _handleSessionEvent(List<Object?>? arguments, String eventName) {
    final snapshot = _snapshotFromArguments(arguments);
    if (snapshot != null) {
      if (kDebugMode) {
        debugPrint(
          '[TableSessionRealtime] $eventName '
          '(${snapshot.participants.length} participants)',
        );
      }
      _publishSnapshot(snapshot);
      return;
    }

    if (kDebugMode) {
      debugPrint('[TableSessionRealtime] $eventName payload could not be parsed');
    }
    _scheduleRefresh(eventName);
  }

  void _publishSnapshot(TableSessionSnapshot snapshot) {
    if (snapshot.sessionId.isEmpty) return;

    final normalizedId = _normalizeId(snapshot.sessionId);
    _lastSnapshots[normalizedId] = snapshot;

    final controller = _controllers[normalizedId];
    if (controller == null || controller.isClosed) return;

    _scheduleCallback(() => controller.add(snapshot));
  }

  TableSessionSnapshot? _snapshotFromArguments(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty || arguments.first == null) {
      return null;
    }

    final map = _payloadToMap(arguments.first!);
    if (map == null) return null;

    try {
      return TableSessionSnapshot.fromJson(map);
    } catch (e, stack) {
      debugPrint('[TableSessionRealtime] fromJson failed: $e\n$stack');
      return null;
    }
  }

  Map<String, dynamic>? _payloadToMap(Object payload) {
    try {
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
      if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return null;
      }

      final encoded = jsonEncode(payload);
      final decoded = jsonDecode(encoded);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, stack) {
      debugPrint('[TableSessionRealtime] payloadToMap failed: $e\n$stack');
    }
    return null;
  }

  void _scheduleRefresh(String reason) {
    for (final callback in _refreshCallbacks.values) {
      _scheduleCallback(callback);
    }
    if (kDebugMode && _refreshCallbacks.isNotEmpty) {
      debugPrint('[TableSessionRealtime] Scheduling REST refresh ($reason)');
    }
  }

  void _scheduleCallback(VoidCallback callback) {
    SchedulerBinding.instance.scheduleTask(
      callback,
      Priority.animation,
    );
  }

  Future<void> _stopConnection() async {
    final connection = _connection;
    _connection = null;
    if (connection == null) return;

    try {
      await connection.stop();
    } catch (e, stack) {
      debugPrint('[TableSessionRealtime] stop failed: $e\n$stack');
    }
  }
}
