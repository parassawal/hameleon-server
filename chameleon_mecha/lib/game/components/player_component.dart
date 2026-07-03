import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:shared/models.dart';
import 'package:shared/constants.dart';

/// Visual representation of a player in the game world.
class PlayerSpriteComponent extends PositionComponent {
  PlayerModel player;
  final bool isLocalPlayer;

  // Interpolation
  Vector2 _targetPosition = Vector2.zero();

  // Visual state
  double _detectionPulseTimer = 0;
  bool _showDetection = false;
  double _camoShimmerTimer = 0;
  double _breatheTimer = 0;

  PlayerSpriteComponent({
    required this.player,
    required this.isLocalPlayer,
  }) : super(
          position: Vector2(player.x, player.y),
          size: Vector2.all(GameConstants.playerSize),
          anchor: Anchor.center,
        ) {
    _targetPosition = Vector2(player.x, player.y);
  }

  /// Update from server state.
  void updateFromModel(PlayerModel model) {
    player = model;
    _targetPosition = Vector2(model.x, model.y);
  }

  /// Show a detection pulse effect.
  void showDetectionPulse() {
    _showDetection = true;
    _detectionPulseTimer = 2.0; // 2 seconds
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth interpolation for remote players
    if (!isLocalPlayer) {
      final diff = _targetPosition - position;
      if (diff.length > 1) {
        position += diff * min(1.0, dt * 10);
      }
    } else {
      position = _targetPosition;
    }

    // Timers
    _breatheTimer += dt * 2;
    _camoShimmerTimer += dt * 3;

    if (_showDetection) {
      _detectionPulseTimer -= dt;
      if (_detectionPulseTimer <= 0) {
        _showDetection = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;

    // Breathe animation
    final breathe = 1.0 + sin(_breatheTimer) * 0.05;
    final currentRadius = radius * breathe;

    // Player body color
    final bodyColor = Color.fromARGB(
      255,
      player.currentColor.r,
      player.currentColor.g,
      player.currentColor.b,
    );

    if (player.isTagged) {
      _renderTaggedPlayer(canvas, center, currentRadius);
      return;
    }

    // Draw based on role
    if (player.role == PlayerRole.seeker) {
      _renderSeeker(canvas, center, currentRadius);
    } else {
      _renderHider(canvas, center, currentRadius, bodyColor);
    }

    // Detection pulse effect
    if (_showDetection) {
      final pulseAlpha = (_detectionPulseTimer / 2.0 * 255).clamp(0, 255).toInt();
      final pulseRadius = currentRadius + (2.0 - _detectionPulseTimer) * 30;
      final pulsePaint = Paint()
        ..color = Color.fromARGB(pulseAlpha, 255, 50, 50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, pulseRadius, pulsePaint);
    }

    // Player name
    _renderName(canvas, center, currentRadius);

    // Local player indicator
    if (isLocalPlayer) {
      final indicatorPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, currentRadius + 5, indicatorPaint);
    }
  }

  void _renderHider(Canvas canvas, Offset center, double radius, Color bodyColor) {
    // Outer glow based on camouflage quality
    final camoQuality = player.camouflageAccuracy / 100.0;
    final glowColor = Color.lerp(
      const Color(0xFFFF3333), // Red = bad camo
      const Color(0xFF33FF33), // Green = good camo
      camoQuality,
    )!;

    // Only show glow to local player or if camo is bad
    if (isLocalPlayer || camoQuality < 0.5) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.3 + (1.0 - camoQuality) * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius + 4, glowPaint);
    }

    // Mecha body
    final bodyPaint = Paint()..color = bodyColor;
    canvas.drawCircle(center, radius, bodyPaint);

    // Mecha details — visor
    final visorPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8);
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, -radius * 0.15), width: radius * 1.0, height: radius * 0.3),
      visorPaint,
    );

    // Shimmer effect for camouflage
    final shimmer = (sin(_camoShimmerTimer) + 1) / 2;
    final shimmerPaint = Paint()
      ..color = Colors.white.withValues(alpha: shimmer * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(-radius * 0.2, -radius * 0.2), radius * 0.5, shimmerPaint);

    // Camouflage accuracy indicator (only for local player)
    if (isLocalPlayer) {
      _renderCamoMeter(canvas, center, radius);
    }
  }

  void _renderSeeker(Canvas canvas, Offset center, double radius) {
    // Seeker has a distinct red/orange look
    final seekerGlow = Paint()
      ..color = const Color(0xFFFF4400).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius + 6, seekerGlow);

    // Body
    final bodyPaint = Paint()
      ..color = const Color(0xFF2D2D3D);
    canvas.drawCircle(center, radius, bodyPaint);

    // Red visor
    final visorPaint = Paint()
      ..color = const Color(0xFFFF4400);
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, -radius * 0.15), width: radius * 1.2, height: radius * 0.25),
      visorPaint,
    );

    // Scanner antenna
    final antennaPaint = Paint()
      ..color = const Color(0xFFFF6600)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      center.translate(0, -radius),
      center.translate(0, -radius * 1.6),
      antennaPaint,
    );
    canvas.drawCircle(center.translate(0, -radius * 1.6), 3, Paint()..color = const Color(0xFFFF4400));

    // Pulsing scan ring
    final pulseProgress = (_camoShimmerTimer % 3) / 3;
    if (pulseProgress < 0.5) {
      final scanRadius = radius + pulseProgress * 80;
      final scanAlpha = ((1.0 - pulseProgress * 2) * 80).toInt();
      final scanPaint = Paint()
        ..color = Color.fromARGB(scanAlpha, 255, 68, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, scanRadius, scanPaint);
    }
  }

  void _renderTaggedPlayer(Canvas canvas, Offset center, double radius) {
    // Ghost/eliminated appearance
    final ghostPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4);
    canvas.drawCircle(center, radius * 0.8, ghostPaint);

    // X eyes
    final xPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Left X
    canvas.drawLine(center.translate(-8, -5), center.translate(-2, 1), xPaint);
    canvas.drawLine(center.translate(-2, -5), center.translate(-8, 1), xPaint);
    // Right X
    canvas.drawLine(center.translate(2, -5), center.translate(8, 1), xPaint);
    canvas.drawLine(center.translate(8, -5), center.translate(2, 1), xPaint);

    _renderName(canvas, center, radius);
  }

  void _renderCamoMeter(Canvas canvas, Offset center, double radius) {
    // Small meter below player
    final meterY = center.dy + radius + 10;
    final meterWidth = radius * 2;
    final meterHeight = 4.0;
    final meterX = center.dx - meterWidth / 2;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(meterX, meterY, meterWidth, meterHeight),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    // Fill
    final fillWidth = meterWidth * (player.camouflageAccuracy / 100.0);
    final fillColor = Color.lerp(Colors.red, Colors.green, player.camouflageAccuracy / 100.0)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(meterX, meterY, fillWidth, meterHeight),
        const Radius.circular(2),
      ),
      Paint()..color = fillColor,
    );
  }

  void _renderName(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: player.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - radius - 16),
    );
  }
}
