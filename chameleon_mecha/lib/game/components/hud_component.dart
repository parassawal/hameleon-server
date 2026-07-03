import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:shared/models.dart';
import '../../multiplayer/game_state.dart';

/// HUD overlay component rendered on the camera viewport.
class GameHudComponent extends PositionComponent with HasGameReference {
  final GameStateManager stateManager;

  // Joystick state
  Vector2? _joystickCenter;
  Vector2? _joystickDelta;

  // Phase transition animation
  String? _phaseText;
  double _phaseTextTimer = 0;

  GameHudComponent({required this.stateManager});

  void updateJoystick(Vector2? center, Vector2? delta) {
    _joystickCenter = center;
    _joystickDelta = delta;
  }

  void onPhaseChanged(GamePhase phase) {
    switch (phase) {
      case GamePhase.hiding:
        _phaseText = '🦎 HIDE!';
        break;
      case GamePhase.seeking:
        _phaseText = '🔍 SEEK!';
        break;
      case GamePhase.results:
        _phaseText = '🏆 ROUND OVER';
        break;
      default:
        _phaseText = null;
    }
    _phaseTextTimer = 3.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_phaseTextTimer > 0) {
      _phaseTextTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final screenSize = game.camera.viewport.size;

    _renderTimer(canvas, screenSize);
    _renderRole(canvas, screenSize);
    _renderScore(canvas, screenSize);
    _renderJoystick(canvas, screenSize);
    _renderPhaseText(canvas, screenSize);
    _renderPlayerCount(canvas, screenSize);
    _renderCamoInfo(canvas, screenSize);
  }

  void _renderTimer(Canvas canvas, Vector2 screenSize) {
    final state = stateManager.state;
    if (state == null || state.phase == GamePhase.lobby) return;

    final timeStr = state.timeRemaining.ceil().toString();
    final isUrgent = state.timeRemaining <= 10;

    final timerBg = Paint()
      ..color = isUrgent
          ? const Color(0xBBFF2222)
          : const Color(0xBB1a1a2e);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(screenSize.x / 2, 35),
          width: 100,
          height: 44,
        ),
        const Radius.circular(22),
      ),
      timerBg,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: TextStyle(
          color: isUrgent ? Colors.white : Colors.cyanAccent,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(screenSize.x / 2 - textPainter.width / 2, 24),
    );
  }

  void _renderRole(Canvas canvas, Vector2 screenSize) {
    final myPlayer = stateManager.myPlayer;
    if (myPlayer == null) return;
    final state = stateManager.state;
    if (state == null || state.phase == GamePhase.lobby) return;

    final roleText = myPlayer.role == PlayerRole.seeker ? '🔍 SEEKER' : '🦎 HIDER';
    final roleColor = myPlayer.role == PlayerRole.seeker
        ? const Color(0xFFFF4400)
        : const Color(0xFF00CC88);

    final bg = Paint()..color = roleColor.withValues(alpha: 0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(screenSize.x - 130, 15, 120, 35),
        const Radius.circular(17),
      ),
      bg,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: roleText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(screenSize.x - 70 - textPainter.width / 2, 22),
    );
  }

  void _renderScore(Canvas canvas, Vector2 screenSize) {
    final myPlayer = stateManager.myPlayer;
    if (myPlayer == null) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '⭐ ${myPlayer.score}',
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, const Offset(15, 22));
  }

  void _renderPlayerCount(Canvas canvas, Vector2 screenSize) {
    final state = stateManager.state;
    if (state == null) return;

    if (state.phase == GamePhase.seeking || state.phase == GamePhase.hiding) {
      final activeHiders = state.players
          .where((p) => p.role == PlayerRole.hider && !p.isTagged)
          .length;
      final totalHiders = state.players
          .where((p) => p.role == PlayerRole.hider)
          .length;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '🦎 $activeHiders/$totalHiders',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, const Offset(15, 50));
    }
  }

  void _renderCamoInfo(Canvas canvas, Vector2 screenSize) {
    final myPlayer = stateManager.myPlayer;
    if (myPlayer == null || myPlayer.role != PlayerRole.hider) return;
    final state = stateManager.state;
    if (state == null || state.phase == GamePhase.lobby) return;

    // Color swatch showing current camouflage color
    final swatchX = screenSize.x - 130.0;
    final swatchY = 60.0;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(swatchX, swatchY, 120, 50),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xBB1a1a2e),
    );

    // Current color swatch
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(swatchX + 8, swatchY + 8, 34, 34),
        const Radius.circular(4),
      ),
      Paint()
        ..color = Color.fromARGB(
          255,
          myPlayer.currentColor.r,
          myPlayer.currentColor.g,
          myPlayer.currentColor.b,
        ),
    );

    // Camo accuracy text
    final accStr = '${myPlayer.camouflageAccuracy.toInt()}%';
    final accColor = Color.lerp(
      Colors.red,
      Colors.green,
      myPlayer.camouflageAccuracy / 100,
    )!;

    final textPainter = TextPainter(
      text: TextSpan(
        text: accStr,
        style: TextStyle(
          color: accColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(swatchX + 50, swatchY + 14));
  }

  void _renderJoystick(Canvas canvas, Vector2 screenSize) {
    if (_joystickCenter == null) {
      // Draw joystick zone hint
      final hintPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(
        Offset(100, screenSize.y - 120),
        50,
        hintPaint,
      );
      canvas.drawCircle(
        Offset(100, screenSize.y - 120),
        15,
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );
      return;
    }

    // Joystick base
    canvas.drawCircle(
      Offset(_joystickCenter!.x, _joystickCenter!.y),
      60,
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    canvas.drawCircle(
      Offset(_joystickCenter!.x, _joystickCenter!.y),
      60,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Joystick knob
    final knobPos = _joystickCenter! + (_joystickDelta ?? Vector2.zero());
    canvas.drawCircle(
      Offset(knobPos.x, knobPos.y),
      22,
      Paint()..color = Colors.cyanAccent.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      Offset(knobPos.x, knobPos.y),
      22,
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _renderPhaseText(Canvas canvas, Vector2 screenSize) {
    if (_phaseText == null || _phaseTextTimer <= 0) return;

    final alpha = (_phaseTextTimer / 3.0).clamp(0.0, 1.0);
    final scale = 1.0 + (1.0 - alpha) * 0.5;

    final textPainter = TextPainter(
      text: TextSpan(
        text: _phaseText!,
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: 42 * scale,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.cyanAccent.withValues(alpha: alpha * 0.8),
              blurRadius: 20,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        screenSize.x / 2 - textPainter.width / 2,
        screenSize.y / 3 - textPainter.height / 2,
      ),
    );
  }
}
