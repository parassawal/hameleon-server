import 'dart:io';
import '../lib/game_room.dart';
import '../lib/player_session.dart';
import 'package:shared/constants.dart';
import 'package:shared/models.dart';
import 'package:shared/protocol.dart';

/// Map of room code → GameRoom
final Map<String, GameRoom> rooms = {};

/// Map of player id → PlayerSession
final Map<String, PlayerSession> sessions = {};

void main() async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    GameConstants.serverPort,
  );

  print('🦎 Chameleon Mecha Server running on port ${GameConstants.serverPort}');
  print('   Waiting for connections...\n');

  await for (final request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      _handleWebSocket(request);
    } else {
      // Simple health check endpoint
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write('{"status":"ok","rooms":${rooms.length},"players":${sessions.length}}')
        ..close();
    }
  }
}

void _handleWebSocket(HttpRequest request) async {
  try {
    final ws = await WebSocketTransformer.upgrade(request);
    final session = PlayerSession(ws);
    sessions[session.id] = session;

    print('✅ Player connected: ${session.id}');

    ws.listen(
      (data) {
        try {
          final message = GameMessage.fromJson(data as String);
          _handleMessage(session, message);
        } catch (e) {
          print('❌ Error parsing message from ${session.id}: $e');
        }
      },
      onDone: () {
        _handleDisconnect(session);
      },
      onError: (error) {
        print('❌ WebSocket error for ${session.id}: $error');
        _handleDisconnect(session);
      },
    );

    // Start heartbeat
    session.startHeartbeat();
  } catch (e) {
    print('❌ Failed to upgrade WebSocket: $e');
  }
}

void _handleMessage(PlayerSession session, GameMessage message) {
  switch (message.type) {
    case MessageType.joinRoom:
      _handleJoinRoom(session, message);
      break;
    case MessageType.leaveRoom:
      _handleLeaveRoom(session);
      break;
    case MessageType.playerReady:
      session.room?.handlePlayerReady(
        session,
        message.data['isReady'] as bool,
      );
      break;
    case MessageType.startGame:
      session.room?.handleStartGame(session);
      break;
    case MessageType.playerMove:
      session.room?.handlePlayerMove(
        session,
        (message.data['x'] as num).toDouble(),
        (message.data['y'] as num).toDouble(),
      );
      break;
    case MessageType.sampleColor:
      session.room?.handleSampleColor(
        session,
        message.data['tileX'] as int,
        message.data['tileY'] as int,
      );
      break;
    case MessageType.applyCamouflage:
      session.room?.handleApplyCamouflage(session, message);
      break;
    case MessageType.tagPlayer:
      session.room?.handleTagPlayer(
        session,
        message.data['targetId'] as String,
      );
      break;
    case MessageType.scanPulse:
      session.room?.handleScanPulse(session);
      break;
    case MessageType.heartbeat:
      session.send(GameMessage.heartbeatAckMsg());
      break;
    default:
      break;
  }
}

void _handleJoinRoom(PlayerSession session, GameMessage message) {
  final playerName = message.data['playerName'] as String;
  final roomCode = message.data['roomCode'] as String?;

  session.playerName = playerName;

  GameRoom room;

  if (roomCode != null && rooms.containsKey(roomCode.toUpperCase())) {
    // Join existing room
    room = rooms[roomCode.toUpperCase()]!;
    if (room.isFull) {
      session.send(GameMessage.gameErrorMsg(message: 'Room is full'));
      return;
    }
    if (room.state.phase != GamePhase.lobby) {
      session.send(GameMessage.gameErrorMsg(message: 'Game already in progress'));
      return;
    }
  } else if (roomCode != null && !rooms.containsKey(roomCode.toUpperCase())) {
    session.send(GameMessage.gameErrorMsg(message: 'Room not found'));
    return;
  } else {
    // Create new room
    room = GameRoom();
    rooms[room.code] = room;
    print('🏠 Room created: ${room.code}');
  }

  room.addPlayer(session);
  print('👤 ${session.playerName} joined room ${room.code} (${room.playerCount} players)');
}

void _handleLeaveRoom(PlayerSession session) {
  final room = session.room;
  if (room != null) {
    room.removePlayer(session);
    print('👤 ${session.playerName} left room ${room.code}');

    if (room.isEmpty) {
      rooms.remove(room.code);
      print('🏠 Room ${room.code} deleted (empty)');
    }
  }
}

void _handleDisconnect(PlayerSession session) {
  print('❌ Player disconnected: ${session.playerName ?? session.id}');
  _handleLeaveRoom(session);
  sessions.remove(session.id);
  session.dispose();
}
