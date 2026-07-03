import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:shared/constants.dart';
import 'components/map_component.dart';
import 'components/player_component.dart';
import 'components/hud_component.dart';
import '../multiplayer/game_client.dart';
import '../multiplayer/game_state.dart';

/// Main game class for Chameleon Mecha.
class ChameleonGame extends FlameGame with HasCollisionDetection, TapCallbacks, DragCallbacks {
  final GameClient client;
  final GameStateManager stateManager;

  // Components
  MapWorldComponent? mapComponent;
  final Map<String, PlayerSpriteComponent> _playerSprites = {};
  GameHudComponent? hudComponent;

  // Input state
  Vector2 _joystickDelta = Vector2.zero();
  bool _joystickActive = false;
  Vector2 _joystickCenter = Vector2.zero();

  // Camera offset
  Vector2 _cameraTarget = Vector2.zero();

  ChameleonGame({
    required this.client,
    required this.stateManager,
  });

  @override
  Color backgroundColor() => const Color(0xFF1a1a2e);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Set up camera
    camera.viewfinder.anchor = Anchor.center;

    // Listen for state updates
    stateManager.stateUpdates.listen(_onStateUpdate);
    stateManager.mapUpdates.listen(_onMapData);
    stateManager.phaseChanges.listen(_onPhaseChanged);
    stateManager.scanResults.listen(_onScanResult);

    // Add HUD (stays on screen)
    hudComponent = GameHudComponent(stateManager: stateManager);
    camera.viewport.add(hudComponent!);
  }

  void _onMapData(List<List<MapTile>> tiles) {
    // Remove old map
    mapComponent?.removeFromParent();

    // Create new map
    mapComponent = MapWorldComponent(tiles: tiles);
    world.add(mapComponent!);
  }

  void _onStateUpdate(GameStateModel state) {
    // Update or create player sprites
    final currentIds = <String>{};

    for (final player in state.players) {
      currentIds.add(player.id);

      if (_playerSprites.containsKey(player.id)) {
        // Update existing player
        _playerSprites[player.id]!.updateFromModel(player);
      } else {
        // Create new player sprite
        final sprite = PlayerSpriteComponent(
          player: player,
          isLocalPlayer: player.id == stateManager.myPlayerId,
        );
        _playerSprites[player.id] = sprite;
        world.add(sprite);
      }
    }

    // Remove disconnected players
    final toRemove = _playerSprites.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in toRemove) {
      _playerSprites[id]?.removeFromParent();
      _playerSprites.remove(id);
    }

    // Update camera to follow local player
    final myPlayer = stateManager.myPlayer;
    if (myPlayer != null) {
      _cameraTarget = Vector2(myPlayer.x, myPlayer.y);
    }
  }

  void _onPhaseChanged(GamePhase phase) {
    hudComponent?.onPhaseChanged(phase);
  }

  void _onScanResult(List<Map<String, dynamic>> detected) {
    // Show detected players with visual pulse
    for (final d in detected) {
      final playerId = d['playerId'] as String;
      final sprite = _playerSprites[playerId];
      if (sprite != null) {
        sprite.showDetectionPulse();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Handle joystick movement
    if (_joystickActive && stateManager.myPlayer != null) {
      final player = stateManager.myPlayer!;
      final speed = GameConstants.playerSpeed * dt;

      // Normalize joystick delta
      final magnitude = _joystickDelta.length;
      if (magnitude > 0) {
        final direction = _joystickDelta / magnitude;
        final newX = player.x + direction.x * speed;
        final newY = player.y + direction.y * speed;
        client.move(newX, newY);
      }
    }

    // Smoothly move camera
    final currentPos = camera.viewfinder.position;
    final diff = _cameraTarget - currentPos;
    if (diff.length > 1) {
      camera.viewfinder.position = currentPos + diff * min(1.0, dt * 5.0);
    }
  }

  // ==================== INPUT HANDLING ====================

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);

    // Joystick: bottom-left quadrant of screen
    final screenSize = camera.viewport.size;
    if (event.localPosition.x < screenSize.x * 0.4 &&
        event.localPosition.y > screenSize.y * 0.5) {
      _joystickActive = true;
      _joystickCenter = event.localPosition.clone();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_joystickActive) {
      _joystickDelta = event.localEndPosition - _joystickCenter;
      // Clamp joystick range
      if (_joystickDelta.length > 60) {
        _joystickDelta = _joystickDelta.normalized() * 60;
      }
      hudComponent?.updateJoystick(_joystickCenter, _joystickDelta);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _joystickActive = false;
    _joystickDelta = Vector2.zero();
    hudComponent?.updateJoystick(null, null);
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);

    final worldPos = event.localPosition;
    final state = stateManager.state;
    if (state == null) return;

    final myPlayer = stateManager.myPlayer;
    if (myPlayer == null) return;

    if (myPlayer.role == PlayerRole.hider) {
      // Tap to sample color from map
      final tileX = (worldPos.x / GameConstants.tileSize).floor();
      final tileY = (worldPos.y / GameConstants.tileSize).floor();
      client.sampleColor(tileX, tileY);
    } else if (myPlayer.role == PlayerRole.seeker) {
      // Tap to try to tag a player or scan
      bool tapped = false;
      for (final player in state.players) {
        if (player.id == myPlayer.id) continue;
        if (player.role != PlayerRole.hider || player.isTagged) continue;

        final dx = worldPos.x - player.x;
        final dy = worldPos.y - player.y;
        if (dx * dx + dy * dy < 2500) {
          // Within 50px tap radius
          client.tagPlayer(player.id);
          tapped = true;
          break;
        }
      }
      if (!tapped) {
        // Scan pulse
        client.scanPulse();
      }
    }
  }
}
