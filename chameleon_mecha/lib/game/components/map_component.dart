import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:shared/models.dart';
import 'package:shared/constants.dart';

/// Renders the game map from tile data.
class MapWorldComponent extends PositionComponent {
  final List<List<MapTile>> tiles;

  MapWorldComponent({required this.tiles})
      : super(
          position: Vector2.zero(),
          size: Vector2(
            GameConstants.mapWidth * GameConstants.tileSize,
            GameConstants.mapHeight * GameConstants.tileSize,
          ),
        );

  @override
  void render(Canvas canvas) {
    for (int y = 0; y < tiles.length; y++) {
      for (int x = 0; x < tiles[y].length; x++) {
        final tile = tiles[y][x];
        final rect = Rect.fromLTWH(
          x * GameConstants.tileSize,
          y * GameConstants.tileSize,
          GameConstants.tileSize,
          GameConstants.tileSize,
        );

        // Draw tile base color
        final paint = Paint()
          ..color = Color.fromARGB(
            255,
            tile.color.r,
            tile.color.g,
            tile.color.b,
          );

        canvas.drawRect(rect, paint);

        // Draw tile borders for visual separation
        final borderPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        canvas.drawRect(rect, borderPaint);

        // Draw wall tiles with a different style
        if (tile.type == TileType.wall) {
          // Draw a subtle 3D effect on walls
          final highlight = Paint()
            ..color = Colors.white.withValues(alpha: 0.15);
          canvas.drawRect(
            Rect.fromLTWH(
              x * GameConstants.tileSize,
              y * GameConstants.tileSize,
              GameConstants.tileSize,
              2,
            ),
            highlight,
          );
          final shadow = Paint()
            ..color = Colors.black.withValues(alpha: 0.3);
          canvas.drawRect(
            Rect.fromLTWH(
              x * GameConstants.tileSize,
              (y + 1) * GameConstants.tileSize - 2,
              GameConstants.tileSize,
              2,
            ),
            shadow,
          );
        }

        // Draw prop indicator
        if (tile.type == TileType.prop) {
          final propPaint = Paint()
            ..color = Color.fromARGB(
              255,
              (tile.color.r * 0.7).toInt(),
              (tile.color.g * 0.7).toInt(),
              (tile.color.b * 0.7).toInt(),
            );
          final center = Offset(
            x * GameConstants.tileSize + GameConstants.tileSize / 2,
            y * GameConstants.tileSize + GameConstants.tileSize / 2,
          );
          canvas.drawCircle(center, GameConstants.tileSize * 0.35, propPaint);

          // Highlight ring
          final ringPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(center, GameConstants.tileSize * 0.35, ringPaint);
        }
      }
    }

    // Draw zone labels
    _drawZoneOverlays(canvas);
  }

  void _drawZoneOverlays(Canvas canvas) {
    // Subtle gradient overlays for zone transitions
    final zones = [
      Rect.fromLTWH(0, 0, 10 * GameConstants.tileSize, 10 * GameConstants.tileSize),
      Rect.fromLTWH(10 * GameConstants.tileSize, 0, 10 * GameConstants.tileSize, 10 * GameConstants.tileSize),
      Rect.fromLTWH(20 * GameConstants.tileSize, 0, 10 * GameConstants.tileSize, 10 * GameConstants.tileSize),
    ];

    for (final zone in zones) {
      final gradient = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ).createShader(zone);
      canvas.drawRect(zone, gradient);
    }
  }

  /// Get the color of a tile at the given grid position.
  GameColor? getColorAt(int gridX, int gridY) {
    if (gridY >= 0 && gridY < tiles.length && gridX >= 0 && gridX < tiles[0].length) {
      return tiles[gridY][gridX].color;
    }
    return null;
  }
}
