import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import 'support_realtime_models.dart';

typedef AsyncAccessTokenFactory = Future<String?> Function();

enum SupportRealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disposed,
}

class SupportRealtimeService {
  SupportRealtimeService({
    required String hubUrl,
    required AsyncAccessTokenFactory accessTokenFactory,
  }) : _hubUrl = _validateHubUrl(hubUrl),
       // Public named parameters cannot use private initializing formals.
       // ignore: prefer_initializing_formals
       _accessTokenFactory = accessTokenFactory;

  static const List<int> _reconnectDelaysInMilliseconds = <int>[
    0,
    2000,
    5000,
    10000,
    30000,
  ];

  final String _hubUrl;
  final AsyncAccessTokenFactory _accessTokenFactory;
  final Set<String> _trackedConversationIds = <String>{};
  final Set<String> _seenEventIds = <String>{};

  final StreamController<SupportRealtimeNotification> _supportEventController =
      StreamController<SupportRealtimeNotification>.broadcast();
  final StreamController<RealtimeUserNotification>
  _notificationEventController =
      StreamController<RealtimeUserNotification>.broadcast();
  final StreamController<NotificationReadStateEvent>
  _notificationStateEventController =
      StreamController<NotificationReadStateEvent>.broadcast();
  final StreamController<SupportRealtimeConnectionState> _stateController =
      StreamController<SupportRealtimeConnectionState>.broadcast();

  HubConnection? _connection;
  Future<void>? _startFuture;
  SupportRealtimeConnectionState _state =
      SupportRealtimeConnectionState.disconnected;
  bool _disposed = false;

  Stream<SupportRealtimeNotification> get supportEvents =>
      _supportEventController.stream;

  Stream<RealtimeUserNotification> get notificationEvents =>
      _notificationEventController.stream;

  Stream<NotificationReadStateEvent> get notificationStateEvents =>
      _notificationStateEventController.stream;

  Stream<SupportRealtimeConnectionState> get connectionStates =>
      _stateController.stream;

  SupportRealtimeConnectionState get state => _state;

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected && !_disposed;

  Future<void> start() async {
    _checkNotDisposed();

    final connection = _connection ??= _buildConnection();
    if (connection.state == HubConnectionState.Connected ||
        connection.state == HubConnectionState.Reconnecting) {
      return;
    }

    final pendingStart = _startFuture;
    if (pendingStart != null) {
      return pendingStart;
    }

    final startFuture = _startConnection(connection);
    _startFuture = startFuture;
    try {
      await startFuture;
    } finally {
      if (identical(_startFuture, startFuture)) {
        _startFuture = null;
      }
    }
  }

  Future<void> subscribeToConversation(String conversationId) async {
    _checkNotDisposed();
    final id = _validatedConversationId(conversationId);
    _trackedConversationIds.add(id);

    final connection = _connection;
    if (connection?.state == HubConnectionState.Connected) {
      await connection!.invoke('SubscribeToConversation', args: <Object>[id]);
    }
  }

  Future<void> unsubscribeFromConversation(String conversationId) async {
    _checkNotDisposed();
    final id = _validatedConversationId(conversationId);
    _trackedConversationIds.remove(id);

    final connection = _connection;
    if (connection?.state == HubConnectionState.Connected) {
      await connection!.invoke(
        'UnsubscribeFromConversation',
        args: <Object>[id],
      );
    }
  }

  Future<void> stop() async {
    if (_disposed) {
      return;
    }

    final connection = _connection;
    if (connection == null ||
        connection.state == HubConnectionState.Disconnected) {
      _setState(SupportRealtimeConnectionState.disconnected);
      return;
    }

    await connection.stop();
    _setState(SupportRealtimeConnectionState.disconnected);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _state = SupportRealtimeConnectionState.disposed;
    if (!_stateController.isClosed) {
      _stateController.add(SupportRealtimeConnectionState.disposed);
    }
    _disposed = true;

    final connection = _connection;
    if (connection != null) {
      connection.off('SupportEvent');
      connection.off('NotificationEvent');
      connection.off('NotificationStateEvent');
      try {
        await connection.stop();
      } catch (_) {
        // Disposal is final; persisted HTTP state remains authoritative.
      }
    }

    _trackedConversationIds.clear();
    _seenEventIds.clear();
    await Future.wait<void>(<Future<void>>[
      _supportEventController.close(),
      _notificationEventController.close(),
      _notificationStateEventController.close(),
      _stateController.close(),
    ]);
  }

  HubConnection _buildConnection() {
    final options = HttpConnectionOptions(
      accessTokenFactory: () async => (await _accessTokenFactory()) ?? '',
      logMessageContent: false,
      requestTimeout: 20000,
    );

    final connection = HubConnectionBuilder()
        .withUrl(_hubUrl, options: options)
        .withAutomaticReconnect(retryDelays: _reconnectDelaysInMilliseconds)
        .build();

    connection.on('SupportEvent', _handleSupportEvent);
    connection.on('NotificationEvent', _handleNotificationEvent);
    connection.on('NotificationStateEvent', _handleNotificationStateEvent);
    connection.onreconnecting(({Exception? error}) {
      if (!_disposed) {
        _setState(SupportRealtimeConnectionState.reconnecting);
      }
    });
    connection.onreconnected(({String? connectionId}) {
      if (_disposed) {
        return;
      }
      _setState(SupportRealtimeConnectionState.connected);
      unawaited(_restoreConversationSubscriptions(connection));
    });
    connection.onclose(({Exception? error}) {
      if (!_disposed) {
        _setState(SupportRealtimeConnectionState.disconnected);
      }
    });

    return connection;
  }

  Future<void> _startConnection(HubConnection connection) async {
    _setState(SupportRealtimeConnectionState.connecting);
    try {
      await connection.start();
      if (_disposed) {
        return;
      }
      _setState(SupportRealtimeConnectionState.connected);
      await _restoreConversationSubscriptions(connection);
    } catch (_) {
      if (!_disposed) {
        _setState(SupportRealtimeConnectionState.disconnected);
      }
      rethrow;
    }
  }

  Future<void> _restoreConversationSubscriptions(
    HubConnection connection,
  ) async {
    final conversationIds = List<String>.of(_trackedConversationIds);
    for (final conversationId in conversationIds) {
      if (_disposed || connection.state != HubConnectionState.Connected) {
        return;
      }
      try {
        await connection.invoke(
          'SubscribeToConversation',
          args: <Object>[conversationId],
        );
      } catch (_) {
        // Realtime is advisory. The repository remains the source of truth.
      }
    }
  }

  void _handleSupportEvent(List<Object?>? arguments) {
    if (_disposed) {
      return;
    }
    try {
      final event = SupportRealtimeNotification.fromJson(
        _singleEventPayload(arguments),
      );
      if (_rememberEvent(event.notificationId)) {
        _supportEventController.add(event);
      }
    } catch (_) {
      // Ignore malformed hints and let the next HTTP reconciliation recover.
    }
  }

  void _handleNotificationEvent(List<Object?>? arguments) {
    if (_disposed) {
      return;
    }
    try {
      final event = RealtimeUserNotification.fromJson(
        _singleEventPayload(arguments),
      );
      if (_rememberEvent(event.id)) {
        _notificationEventController.add(event);
      }
    } catch (_) {
      // Ignore malformed hints and let the next HTTP reconciliation recover.
    }
  }

  void _handleNotificationStateEvent(List<Object?>? arguments) {
    if (_disposed) {
      return;
    }
    try {
      final event = NotificationReadStateEvent.fromJson(
        _singleEventPayload(arguments),
      );
      if (_rememberEvent(event.eventId)) {
        _notificationStateEventController.add(event);
      }
    } catch (_) {
      // Ignore malformed hints and let the next HTTP reconciliation recover.
    }
  }

  bool _rememberEvent(String eventId) {
    if (!_seenEventIds.add(eventId)) {
      return false;
    }
    if (_seenEventIds.length > 200) {
      _seenEventIds.remove(_seenEventIds.first);
    }
    return true;
  }

  void _setState(SupportRealtimeConnectionState nextState) {
    if (_state == nextState || _disposed) {
      return;
    }
    _state = nextState;
    if (!_stateController.isClosed) {
      _stateController.add(nextState);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('SupportRealtimeService has been disposed.');
    }
  }

  static Object? _singleEventPayload(List<Object?>? arguments) {
    if (arguments == null || arguments.length != 1) {
      throw const FormatException(
        'SignalR event must contain exactly one payload.',
      );
    }
    return arguments.single;
  }

  static String _validatedConversationId(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        conversationId,
        'conversationId',
        'Conversation ID cannot be empty.',
      );
    }
    return id;
  }

  static String _validateHubUrl(String hubUrl) {
    final trimmed = hubUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(
        hubUrl,
        'hubUrl',
        'Hub URL must be an absolute HTTP(S) URL.',
      );
    }
    return trimmed;
  }
}
