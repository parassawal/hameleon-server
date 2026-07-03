import 'dart:async';
import 'dart:math';
import 'player_session.dart';
import 'package:shared/models.dart';
import 'package:shared/protocol.dart';
import 'package:shared/constants.dart';

/// Manages a single game room with authoritative game logic.
class GameRoom {
  final String code;
  final List<PlayerSession> _players = [];
  late GameStateModel state;
  Timer? _gameTimer;
  final Random _random = Random();

  /// Map tile data — 2D grid of colors for camouflage sampling.
  late List<List<MapTile>> _mapTiles;

  /// Scan cooldowns per player.
  final Map<String, DateTime> _scanCooldowns = {};

  GameRoom() : code = _generateCode() {
    state = GameStateModel(roomCode: code);
    _generateMap();
  }

  static final Random _codeRandom = Random();
  static String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(
      GameConstants.roomCodeLength,
      (_) => chars[_codeRandom.nextInt(chars.length)],
    ).join();
  }

  bool get isFull => _players.length >= GameConstants.maxPlayers;
  bool get isEmpty => _players.isEmpty;
  int get playerCount => _players.length;

  // ==================== MAP GENERATION ====================

  void _generateMap() {
    // Generate a colorful map with distinct zones
    _mapTiles = List.generate(GameConstants.mapHeight, (y) {
      return List.generate(GameConstants.mapWidth, (x) {
        return _generateTile(x, y);
      });
    });
  }

  MapTile _generateTile(int x, int y) {
    // Create distinct color zones across the map
    final zoneX = x ~/ 10; // 3 horizontal zones
    final zoneY = y ~/ 10; // 2 vertical zones
    final zone = zoneX + zoneY * 3;

    // Wall borders
    if (x == 0 || y == 0 || x == GameConstants.mapWidth - 1 || y == GameConstants.mapHeight - 1) {
      return MapTile(gridX: x, gridY: y, type: TileType.wall, color: const GameColor(60, 60, 70));
    }

    // Some internal walls for cover
    if ((x % 8 == 0 && y > 2 && y < GameConstants.mapHeight - 3 && y % 3 != 0) ||
        (y % 6 == 0 && x > 2 && x < GameConstants.mapWidth - 3 && x % 4 != 0)) {
      return MapTile(gridX: x, gridY: y, type: TileType.wall, color: const GameColor(80, 75, 85));
    }

    // Zone-based colors with slight variation
    GameColor baseColor;
    switch (zone) {
      case 0: // Red/orange industrial zone
        baseColor = GameColor(
          180 + _random.nextInt(40),
          80 + _random.nextInt(30),
          60 + _random.nextInt(20),
        );
        break;
      case 1: // Green nature zone
        baseColor = GameColor(
          60 + _random.nextInt(30),
          150 + _random.nextInt(50),
          70 + _random.nextInt(30),
        );
        break;
      case 2: // Blue tech zone
        baseColor = GameColor(
          60 + _random.nextInt(20),
          100 + _random.nextInt(30),
          180 + _random.nextInt(40),
        );
        break;
      case 3: // Purple warehouse zone
        baseColor = GameColor(
          140 + _random.nextInt(30),
          70 + _random.nextInt(20),
          160 + _random.nextInt(40),
        );
        break;
      case 4: // Yellow/gold zone
        baseColor = GameColor(
          200 + _random.nextInt(30),
          180 + _random.nextInt(30),
          60 + _random.nextInt(20),
        );
        break;
      default: // Teal zone
        baseColor = GameColor(
          60 + _random.nextInt(20),
          170 + _random.nextInt(40),
          170 + _random.nextInt(40),
        );
    }

    // Occasionally place props
    if (_random.nextDouble() < 0.05) {
      return MapTile(gridX: x, gridY: y, type: TileType.prop, color: baseColor);
    }

    return MapTile(gridX: x, gridY: y, type: TileType.floor, color: baseColor);
  }

  // ==================== PLAYER MANAGEMENT ====================

  void addPlayer(PlayerSession session) {
    // Create player model
    final isHost = _players.isEmpty;
    final player = PlayerModel(
      id: session.id,
      name: session.playerName ?? 'Player',
      x: 100 + _random.nextDouble() * 200,
      y: 100 + _random.nextDouble() * 200,
      isHost: isHost,
    );

    state.players.add(player);
    _players.add(session);
    session.room = this;

    // Send room joined to the new player
    session.send(GameMessage.roomJoined(
      roomCode: code,
      playerId: session.id,
      state: state,
    ));

    // Send map data to the new player
    session.send(GameMessage.sendMapData(
      tiles: _mapTiles
          .map((row) => row.map((t) => t.toJson()).toList())
          .toList(),
    ));

    // Notify all players of state update
    _broadcastState();
  }

  void removePlayer(PlayerSession session) {
    _players.remove(session);
    state.players.removeWhere((p) => p.id == session.id);
    session.room = null;

    // Transfer host if needed
    if (state.players.isNotEmpty && !state.players.any((p) => p.isHost)) {
      state.players.first.isHost = true;
    }

    _broadcastState();

    // If game is in progress and not enough players, end the round
    if (state.phase != GamePhase.lobby && _players.length < GameConstants.minPlayers) {
      _endRound();
    }
  }

  // ==================== GAME FLOW ====================

  void handlePlayerReady(PlayerSession session, bool isReady) {
    final player = _findPlayer(session.id);
    if (player != null) {
      player.isReady = isReady;
      _broadcastState();
    }
  }

  void handleStartGame(PlayerSession session) {
    final player = _findPlayer(session.id);
    if (player == null || !player.isHost) return;
    if (_players.length < GameConstants.minPlayers) {
      session.send(GameMessage.gameErrorMsg(
        message: 'Need at least ${GameConstants.minPlayers} players',
      ));
      return;
    }

    _startRound();
  }

  void _startRound() {
    state.roundNumber++;

    // Assign roles: 1 seeker per 3 players, min 1
    final seekerCount = max(1, _players.length ~/ 3);
    final shuffled = List<PlayerModel>.from(state.players)..shuffle(_random);

    for (int i = 0; i < shuffled.length; i++) {
      shuffled[i].role = i < seekerCount ? PlayerRole.seeker : PlayerRole.hider;
      shuffled[i].isTagged = false;
      shuffled[i].camouflageAccuracy = 0;

      // Spawn positions
      if (shuffled[i].role == PlayerRole.seeker) {
        // Seekers spawn at center
        shuffled[i].x = GameConstants.mapWidth * GameConstants.tileSize / 2;
        shuffled[i].y = GameConstants.mapHeight * GameConstants.tileSize / 2;
      } else {
        // Hiders spawn at random edges
        if (_random.nextBool()) {
          shuffled[i].x = (_random.nextBool() ? 2 : GameConstants.mapWidth - 3) * GameConstants.tileSize;
          shuffled[i].y = (2 + _random.nextInt(GameConstants.mapHeight - 4)) * GameConstants.tileSize;
        } else {
          shuffled[i].x = (2 + _random.nextInt(GameConstants.mapWidth - 4)) * GameConstants.tileSize;
          shuffled[i].y = (_random.nextBool() ? 2 : GameConstants.mapHeight - 3) * GameConstants.tileSize;
        }
      }
    }

    // Start hiding phase
    state.phase = GamePhase.hiding;
    state.timeRemaining = GameConstants.hidingPhaseDuration.toDouble();
    _broadcast(GameMessage.phaseChanged(
      phase: GamePhase.hiding,
      timeRemaining: state.timeRemaining,
    ));
    _broadcastState();

    // Start game timer
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    state.timeRemaining -= 1;

    if (state.timeRemaining <= 0) {
      if (state.phase == GamePhase.hiding) {
        // Transition to seeking phase
        state.phase = GamePhase.seeking;
        state.timeRemaining = GameConstants.seekingPhaseDuration.toDouble();
        _broadcast(GameMessage.phaseChanged(
          phase: GamePhase.seeking,
          timeRemaining: state.timeRemaining,
        ));
      } else if (state.phase == GamePhase.seeking) {
        _endRound();
        return;
      }
    }

    // Check if all hiders are tagged
    if (state.phase == GamePhase.seeking) {
      final activeHiders = state.players
          .where((p) => p.role == PlayerRole.hider && !p.isTagged)
          .length;
      if (activeHiders == 0) {
        _endRound();
        return;
      }
    }

    _broadcastState();
  }

  void _endRound() {
    _gameTimer?.cancel();

    // Calculate scores
    for (final player in state.players) {
      if (player.role == PlayerRole.hider && !player.isTagged) {
        player.score += GameConstants.hiderSurvivePoints;
      }
    }

    state.phase = GamePhase.results;
    state.timeRemaining = GameConstants.resultsDisplayDuration.toDouble();
    _broadcast(GameMessage.phaseChanged(
      phase: GamePhase.results,
      timeRemaining: state.timeRemaining,
    ));
    _broadcastState();

    // Return to lobby after results
    Timer(const Duration(seconds: GameConstants.resultsDisplayDuration), () {
      state.phase = GamePhase.lobby;
      for (final p in state.players) {
        p.isReady = false;
        p.isTagged = false;
        p.role = PlayerRole.hider;
      }
      _broadcastState();
    });
  }

  // ==================== GAME ACTIONS ====================

  void handlePlayerMove(PlayerSession session, double x, double y) {
    final player = _findPlayer(session.id);
    if (player == null) return;

    // During hiding phase, only hiders can move
    if (state.phase == GamePhase.hiding && player.role == PlayerRole.seeker) return;

    // Validate movement (basic bounds check)
    final maxX = GameConstants.mapWidth * GameConstants.tileSize;
    final maxY = GameConstants.mapHeight * GameConstants.tileSize;
    final clampedX = x.clamp(GameConstants.tileSize, maxX - GameConstants.tileSize);
    final clampedY = y.clamp(GameConstants.tileSize, maxY - GameConstants.tileSize);

    // Check wall collision
    final tileX = (clampedX / GameConstants.tileSize).floor();
    final tileY = (clampedY / GameConstants.tileSize).floor();
    if (tileY >= 0 && tileY < _mapTiles.length && tileX >= 0 && tileX < _mapTiles[0].length) {
      if (_mapTiles[tileY][tileX].type == TileType.wall) return;
    }

    player.x = clampedX;
    player.y = clampedY;

    // Update camouflage accuracy based on surroundings
    if (player.role == PlayerRole.hider) {
      _updateCamouflageAccuracy(player);
    }

    // No need to broadcast every move — state updates will handle it
  }

  void handleSampleColor(PlayerSession session, int tileX, int tileY) {
    if (state.phase != GamePhase.hiding && state.phase != GamePhase.seeking) return;

    final player = _findPlayer(session.id);
    if (player == null || player.role != PlayerRole.hider) return;

    // Validate tile coordinates
    if (tileY < 0 || tileY >= _mapTiles.length || tileX < 0 || tileX >= _mapTiles[0].length) return;

    final tile = _mapTiles[tileY][tileX];
    player.currentColor = tile.color;
    _updateCamouflageAccuracy(player);
  }

  void handleApplyCamouflage(PlayerSession session, GameMessage message) {
    final player = _findPlayer(session.id);
    if (player == null || player.role != PlayerRole.hider) return;

    final colorData = message.data['color'] as Map<String, dynamic>;
    player.currentColor = GameColor.fromJson(colorData);
    _updateCamouflageAccuracy(player);
  }

  void handleTagPlayer(PlayerSession session, String targetId) {
    if (state.phase != GamePhase.seeking) return;

    final seeker = _findPlayer(session.id);
    if (seeker == null || seeker.role != PlayerRole.seeker) return;

    final target = _findPlayer(targetId);
    if (target == null || target.role != PlayerRole.hider || target.isTagged) return;

    // Check distance
    final dx = seeker.x - target.x;
    final dy = seeker.y - target.y;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist <= GameConstants.detectionRadius) {
      target.isTagged = true;
      seeker.score += GameConstants.seekerTagPoints;

      // Bonus for quick finds
      final elapsed = GameConstants.seekingPhaseDuration - state.timeRemaining;
      if (elapsed < 30) {
        seeker.score += GameConstants.seekerSpeedBonus;
      }

      _broadcast(GameMessage.playerTaggedMsg(
        seekerId: seeker.id,
        hiderId: target.id,
      ));
      _broadcastState();
    }
  }

  void handleScanPulse(PlayerSession session) {
    if (state.phase != GamePhase.seeking) return;

    final seeker = _findPlayer(session.id);
    if (seeker == null || seeker.role != PlayerRole.seeker) return;

    // Check cooldown
    final lastScan = _scanCooldowns[session.id];
    if (lastScan != null) {
      final elapsed = DateTime.now().difference(lastScan).inMilliseconds;
      if (elapsed < GameConstants.scanCooldown * 1000) return;
    }
    _scanCooldowns[session.id] = DateTime.now();

    // Find hiders within scan range
    final detected = <Map<String, dynamic>>[];
    for (final player in state.players) {
      if (player.role != PlayerRole.hider || player.isTagged) continue;

      final dx = seeker.x - player.x;
      final dy = seeker.y - player.y;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist <= GameConstants.scanPulseRadius) {
        // Detection chance based on camouflage quality
        final camoFactor = 1.0 - (player.camouflageAccuracy / 100.0);
        final detectChance = (1.0 - (dist / GameConstants.scanPulseRadius)) * camoFactor;

        if (_random.nextDouble() < detectChance + 0.2) {
          // Always at least 20% chance if in range
          detected.add({
            'playerId': player.id,
            'x': player.x,
            'y': player.y,
            'accuracy': player.camouflageAccuracy,
          });
        }
      }
    }

    session.send(GameMessage.scanResultMsg(detectedPlayers: detected));
  }

  // ==================== HELPERS ====================

  void _updateCamouflageAccuracy(PlayerModel player) {
    final tileX = (player.x / GameConstants.tileSize).floor();
    final tileY = (player.y / GameConstants.tileSize).floor();

    if (tileY < 0 || tileY >= _mapTiles.length || tileX < 0 || tileX >= _mapTiles[0].length) {
      player.camouflageAccuracy = 0;
      return;
    }

    final tile = _mapTiles[tileY][tileX];
    final distance = player.currentColor.perceptualDistanceTo(tile.color);

    // Convert distance to accuracy percentage
    if (distance <= GameConstants.perfectCamoThreshold) {
      player.camouflageAccuracy = 100;
    } else if (distance <= GameConstants.goodCamoThreshold) {
      player.camouflageAccuracy = 80 + (1 - (distance - GameConstants.perfectCamoThreshold) /
          (GameConstants.goodCamoThreshold - GameConstants.perfectCamoThreshold)) * 20;
    } else if (distance <= GameConstants.poorCamoThreshold) {
      player.camouflageAccuracy = 30 + (1 - (distance - GameConstants.goodCamoThreshold) /
          (GameConstants.poorCamoThreshold - GameConstants.goodCamoThreshold)) * 50;
    } else {
      player.camouflageAccuracy = max(0, 30 - (distance - GameConstants.poorCamoThreshold) / 10);
    }
  }

  PlayerModel? _findPlayer(String id) {
    try {
      return state.players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void _broadcast(GameMessage message) {
    for (final session in _players) {
      session.send(message);
    }
  }

  void _broadcastState() {
    final msg = GameMessage.gameStateUpdate(state: state);
    for (final session in _players) {
      session.send(msg);
    }
  }
}
