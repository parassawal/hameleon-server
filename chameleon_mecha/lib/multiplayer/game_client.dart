import 'dart:async';
import 'dart:io' show Platform;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/models.dart';
import 'package:shared/protocol.dart';
import 'package:shared/constants.dart';

export 'package:shared/models.dart';
export 'package:shared/protocol.dart';

/// WebSocket client for connecting to the Chameleon Mecha server.
class GameClient {
  WebSocketChannel? _channel;
  String? _playerId;
  bool _connected = false;
  int _reconnectAttempt = 0;
  Timer? _heartbeatTimer;
  final String _serverUrl;

  // Stream controllers for game events
  final _messageController = StreamController<GameMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  /// Stream of incoming game messages.
  Stream<GameMessage> get messages => _messageController.stream;

  /// Stream of connection status changes.
  Stream<bool> get connectionStatus => _connectionController.stream;

  /// Whether the client is currently connected.
  bool get isConnected => _connected;

  /// The player's assigned ID.
  String? get playerId => _playerId;

  GameClient({String? serverUrl})
      : _serverUrl = serverUrl ??
            '${GameConstants.serverPort == 443 ? 'wss' : 'ws'}://${_getDefaultHost()}${GameConstants.serverPort == 443 || GameConstants.serverPort == 80 ? '' : ':${GameConstants.serverPort}'}';

  static String _getDefaultHost() {
    String host = GameConstants.serverHost;
    try {
      // If running on an Android Emulator and targeting localhost, map to host loopback
      if (Platform.isAndroid && host == 'localhost') {
        return '10.0.2.2';
      }
    } catch (_) {}
    return host;
  }

  /// Connect to the game server.
  Future<bool> connect() async {
    try {
      final uri = Uri.parse(_serverUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(const Duration(seconds: 5));
      _connected = true;
      _reconnectAttempt = 0;
      _connectionController.add(true);

      _channel!.stream.listen(
        (data) {
          try {
            final message = GameMessage.fromJson(data as String);
            _handleMessage(message);
          } catch (_) {}
        },
        onDone: () {
          _onDisconnected();
        },
        onError: (error) {
          _onDisconnected();
        },
      );

      _startHeartbeat();
      return true;
    } catch (_) {
      _connected = false;
      _connectionController.add(false);
      return false;
    }
  }

  void _handleMessage(GameMessage message) {
    if (message.type == MessageType.roomJoined) {
      _playerId = message.data['playerId'] as String?;
    }
    _messageController.add(message);
  }

  void _onDisconnected() {
    _connected = false;
    _heartbeatTimer?.cancel();
    _connectionController.add(false);
    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_reconnectAttempt > 5) return;

    final delay = Duration(
      milliseconds: (GameConstants.reconnectDelayMs *
              (1 << _reconnectAttempt))
          .clamp(0, GameConstants.maxReconnectDelayMs),
    );

    _reconnectAttempt++;
    Timer(delay, () {
      if (!_connected) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: GameConstants.heartbeatIntervalMs),
      (_) {
        send(GameMessage.heartbeatMsg());
      },
    );
  }

  /// Send a message to the server.
  void send(GameMessage message) {
    if (_connected && _channel != null) {
      try {
        _channel!.sink.add(message.toJson());
      } catch (_) {}
    }
  }

  /// Join or create a room.
  void joinRoom({required String playerName, String? roomCode}) {
    send(GameMessage.joinRoom(
      playerName: playerName,
      roomCode: roomCode,
    ));
  }

  /// Leave the current room.
  void leaveRoom() {
    send(GameMessage.leaveRoom());
  }

  /// Set ready status.
  void setReady(bool isReady) {
    send(GameMessage.playerReady(isReady: isReady));
  }

  /// Start the game (host only).
  void startGame() {
    send(GameMessage.startGame());
  }

  /// Send movement update.
  void move(double x, double y) {
    send(GameMessage.playerMove(x: x, y: y));
  }

  /// Sample color from a tile.
  void sampleColor(int tileX, int tileY) {
    send(GameMessage.sampleColor(tileX: tileX, tileY: tileY));
  }

  /// Apply a camouflage color.
  void applyCamouflage(int r, int g, int b) {
    send(GameMessage.applyCamouflage(
      color: GameColor(r, g, b),
    ));
  }

  /// Tag a player (seeker action).
  void tagPlayer(String targetId) {
    send(GameMessage.tagPlayer(targetId: targetId));
  }

  /// Trigger scan pulse (seeker action).
  void scanPulse() {
    send(GameMessage.scanPulse());
  }

  /// Disconnect from the server.
  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    _connectionController.add(false);
  }

  /// Dispose all resources.
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
