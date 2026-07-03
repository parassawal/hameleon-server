import 'dart:async';
import 'package:shared/models.dart';
import 'package:shared/protocol.dart';

/// Manages synchronized game state from the server.
class GameStateManager {
  GameStateModel? _state;
  String? _myPlayerId;
  List<List<MapTile>>? _mapTiles;

  final _stateController = StreamController<GameStateModel>.broadcast();
  final _phaseController = StreamController<GamePhase>.broadcast();
  final _mapController = StreamController<List<List<MapTile>>>.broadcast();
  final _tagController = StreamController<Map<String, String>>.broadcast();
  final _scanController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Current game state.
  GameStateModel? get state => _state;

  /// This player's ID.
  String? get myPlayerId => _myPlayerId;

  /// This player's model.
  PlayerModel? get myPlayer {
    if (_state == null || _myPlayerId == null) return null;
    try {
      return _state!.players.firstWhere((p) => p.id == _myPlayerId);
    } catch (_) {
      return null;
    }
  }

  /// Map tile data.
  List<List<MapTile>>? get mapTiles => _mapTiles;

  /// Stream of state updates.
  Stream<GameStateModel> get stateUpdates => _stateController.stream;

  /// Stream of phase changes.
  Stream<GamePhase> get phaseChanges => _phaseController.stream;

  /// Stream of map data.
  Stream<List<List<MapTile>>> get mapUpdates => _mapController.stream;

  /// Stream of player tag events (seekerId → hiderId).
  Stream<Map<String, String>> get tagEvents => _tagController.stream;

  /// Stream of scan results.
  Stream<List<Map<String, dynamic>>> get scanResults => _scanController.stream;

  /// Stream of error messages.
  Stream<String> get errors => _errorController.stream;

  /// Process an incoming message from the server.
  void processMessage(GameMessage message) {
    switch (message.type) {
      case MessageType.roomJoined:
        _myPlayerId = message.data['playerId'] as String?;
        final stateData = message.data['state'] as Map<String, dynamic>;
        _state = GameStateModel.fromJson(stateData);
        _stateController.add(_state!);
        break;

      case MessageType.gameStateUpdate:
        final stateData = message.data['state'] as Map<String, dynamic>;
        _state = GameStateModel.fromJson(stateData);
        _stateController.add(_state!);
        break;

      case MessageType.phaseChanged:
        final phase = GamePhase.values.byName(message.data['phase'] as String);
        if (_state != null) {
          _state!.phase = phase;
          _state!.timeRemaining = (message.data['timeRemaining'] as num).toDouble();
        }
        _phaseController.add(phase);
        break;

      case MessageType.mapData:
        final tilesData = message.data['tiles'] as List;
        _mapTiles = tilesData.map((row) {
          return (row as List)
              .map((t) => MapTile.fromJson(t as Map<String, dynamic>))
              .toList();
        }).toList();
        _mapController.add(_mapTiles!);
        break;

      case MessageType.playerTagged:
        _tagController.add({
          message.data['seekerId'] as String: message.data['hiderId'] as String,
        });
        break;

      case MessageType.scanResult:
        final detected = (message.data['detectedPlayers'] as List)
            .cast<Map<String, dynamic>>();
        _scanController.add(detected);
        break;

      case MessageType.gameError:
        _errorController.add(message.data['message'] as String);
        break;

      default:
        break;
    }
  }

  void dispose() {
    _stateController.close();
    _phaseController.close();
    _mapController.close();
    _tagController.close();
    _scanController.close();
    _errorController.close();
  }
}
