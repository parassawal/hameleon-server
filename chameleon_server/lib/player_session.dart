import 'dart:async';
import 'dart:io';
import 'package:shared/protocol.dart';

/// Manages a single player's WebSocket connection.
class PlayerSession {
  final WebSocket _ws;
  final String id;
  String? playerName;
  dynamic room; // GameRoom reference, dynamic to avoid circular imports
  Timer? _heartbeatTimer;
  bool _disposed = false;

  PlayerSession(this._ws) : id = _generateId();

  static int _idCounter = 0;
  static String _generateId() {
    _idCounter++;
    return 'player_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  /// Send a message to this player.
  void send(GameMessage message) {
    if (!_disposed && _ws.readyState == WebSocket.open) {
      try {
        _ws.add(message.toJson());
      } catch (e) {
        print('Error sending to ${playerName ?? id}: $e');
      }
    }
  }

  /// Start periodic heartbeat checks.
  void startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (_ws.readyState == WebSocket.open) {
          _ws.add(GameMessage.heartbeatAckMsg().toJson());
        }
      },
    );
  }

  /// Clean up resources.
  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    if (_ws.readyState == WebSocket.open) {
      _ws.close();
    }
  }
}
