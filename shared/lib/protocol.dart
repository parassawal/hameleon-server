import 'dart:convert';
import 'models.dart';

/// Message types for the game protocol.
enum MessageType {
  // Client → Server
  joinRoom,
  leaveRoom,
  playerReady,
  playerMove,
  sampleColor,
  applyCamouflage,
  tagPlayer,
  scanPulse,
  startGame,
  heartbeat,

  // Server → Client
  roomJoined,
  roomLeft,
  playerJoinedRoom,
  playerLeftRoom,
  gameStateUpdate,
  phaseChanged,
  playerTagged,
  scanResult,
  roundStarted,
  roundEnded,
  gameError,
  mapData,
  heartbeatAck,
}

/// Base game message for network communication.
class GameMessage {
  final MessageType type;
  final Map<String, dynamic> data;
  final String? senderId;

  const GameMessage({
    required this.type,
    this.data = const {},
    this.senderId,
  });

  factory GameMessage.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return GameMessage(
      type: MessageType.values.byName(json['type'] as String),
      data: json['data'] as Map<String, dynamic>? ?? {},
      senderId: json['senderId'] as String?,
    );
  }

  String toJson() => jsonEncode({
        'type': type.name,
        'data': data,
        if (senderId != null) 'senderId': senderId,
      });

  // ===== Client → Server Message Factories =====

  static GameMessage joinRoom({
    required String playerName,
    String? roomCode,
  }) {
    return GameMessage(
      type: MessageType.joinRoom,
      data: {
        'playerName': playerName,
        if (roomCode != null) 'roomCode': roomCode,
      },
    );
  }

  static GameMessage leaveRoom() {
    return const GameMessage(type: MessageType.leaveRoom);
  }

  static GameMessage playerReady({required bool isReady}) {
    return GameMessage(
      type: MessageType.playerReady,
      data: {'isReady': isReady},
    );
  }

  static GameMessage playerMove({
    required double x,
    required double y,
  }) {
    return GameMessage(
      type: MessageType.playerMove,
      data: {'x': x, 'y': y},
    );
  }

  static GameMessage sampleColor({
    required int tileX,
    required int tileY,
  }) {
    return GameMessage(
      type: MessageType.sampleColor,
      data: {'tileX': tileX, 'tileY': tileY},
    );
  }

  static GameMessage applyCamouflage({
    required GameColor color,
  }) {
    return GameMessage(
      type: MessageType.applyCamouflage,
      data: {'color': color.toJson()},
    );
  }

  static GameMessage tagPlayer({required String targetId}) {
    return GameMessage(
      type: MessageType.tagPlayer,
      data: {'targetId': targetId},
    );
  }

  static GameMessage scanPulse() {
    return const GameMessage(type: MessageType.scanPulse);
  }

  static GameMessage startGame() {
    return const GameMessage(type: MessageType.startGame);
  }

  static GameMessage heartbeatMsg() {
    return GameMessage(
      type: MessageType.heartbeat,
      data: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  // ===== Server → Client Message Factories =====

  static GameMessage roomJoined({
    required String roomCode,
    required String playerId,
    required GameStateModel state,
  }) {
    return GameMessage(
      type: MessageType.roomJoined,
      data: {
        'roomCode': roomCode,
        'playerId': playerId,
        'state': state.toJson(),
      },
    );
  }

  static GameMessage gameStateUpdate({required GameStateModel state}) {
    return GameMessage(
      type: MessageType.gameStateUpdate,
      data: {'state': state.toJson()},
    );
  }

  static GameMessage phaseChanged({
    required GamePhase phase,
    required double timeRemaining,
  }) {
    return GameMessage(
      type: MessageType.phaseChanged,
      data: {
        'phase': phase.name,
        'timeRemaining': timeRemaining,
      },
    );
  }

  static GameMessage playerTaggedMsg({
    required String seekerId,
    required String hiderId,
  }) {
    return GameMessage(
      type: MessageType.playerTagged,
      data: {
        'seekerId': seekerId,
        'hiderId': hiderId,
      },
    );
  }

  static GameMessage scanResultMsg({
    required List<Map<String, dynamic>> detectedPlayers,
  }) {
    return GameMessage(
      type: MessageType.scanResult,
      data: {'detectedPlayers': detectedPlayers},
    );
  }

  static GameMessage sendMapData({
    required List<List<Map<String, dynamic>>> tiles,
  }) {
    return GameMessage(
      type: MessageType.mapData,
      data: {'tiles': tiles},
    );
  }

  static GameMessage gameErrorMsg({required String message}) {
    return GameMessage(
      type: MessageType.gameError,
      data: {'message': message},
    );
  }

  static GameMessage heartbeatAckMsg() {
    return GameMessage(
      type: MessageType.heartbeatAck,
      data: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }
}
