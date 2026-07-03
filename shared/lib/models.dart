/// Shared data models for Chameleon Mecha.

/// Player role in the game.
enum PlayerRole { hider, seeker, spectator }

/// Current phase of a game round.
enum GamePhase { lobby, hiding, seeking, results }

/// Tile types for the map.
enum TileType { floor, wall, prop, spawn }

/// Represents a color as RGB integers.
class GameColor {
  final int r;
  final int g;
  final int b;

  const GameColor(this.r, this.g, this.b);

  factory GameColor.fromJson(Map<String, dynamic> json) {
    return GameColor(
      json['r'] as int,
      json['g'] as int,
      json['b'] as int,
    );
  }

  Map<String, dynamic> toJson() => {'r': r, 'g': g, 'b': b};

  /// Calculate color distance (Euclidean RGB distance).
  double distanceTo(GameColor other) {
    final dr = (r - other.r).toDouble();
    final dg = (g - other.g).toDouble();
    final db = (b - other.b).toDouble();
    return (dr * dr + dg * dg + db * db);
  }

  /// Weighted color distance for better perceptual accuracy.
  double perceptualDistanceTo(GameColor other) {
    final rmean = (r + other.r) / 2.0;
    final dr = (r - other.r).toDouble();
    final dg = (g - other.g).toDouble();
    final db = (b - other.b).toDouble();
    final weightR = 2 + rmean / 256;
    final weightG = 4.0;
    final weightB = 2 + (255 - rmean) / 256;
    return (weightR * dr * dr + weightG * dg * dg + weightB * db * db);
  }

  @override
  String toString() => 'GameColor($r, $g, $b)';

  @override
  bool operator ==(Object other) =>
      other is GameColor && r == other.r && g == other.g && b == other.b;

  @override
  int get hashCode => Object.hash(r, g, b);
}

/// Represents a player in the game.
class PlayerModel {
  final String id;
  final String name;
  double x;
  double y;
  PlayerRole role;
  GameColor currentColor;
  double camouflageAccuracy;
  int score;
  bool isTagged;
  bool isReady;
  bool isHost;

  PlayerModel({
    required this.id,
    required this.name,
    this.x = 0,
    this.y = 0,
    this.role = PlayerRole.hider,
    this.currentColor = const GameColor(100, 100, 100),
    this.camouflageAccuracy = 0,
    this.score = 0,
    this.isTagged = false,
    this.isReady = false,
    this.isHost = false,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      role: PlayerRole.values.byName(json['role'] as String),
      currentColor: GameColor.fromJson(json['currentColor'] as Map<String, dynamic>),
      camouflageAccuracy: (json['camouflageAccuracy'] as num).toDouble(),
      score: json['score'] as int,
      isTagged: json['isTagged'] as bool,
      isReady: json['isReady'] as bool,
      isHost: json['isHost'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'role': role.name,
        'currentColor': currentColor.toJson(),
        'camouflageAccuracy': camouflageAccuracy,
        'score': score,
        'isTagged': isTagged,
        'isReady': isReady,
        'isHost': isHost,
      };
}

/// Represents a tile in the game map.
class MapTile {
  final int gridX;
  final int gridY;
  final TileType type;
  final GameColor color;

  const MapTile({
    required this.gridX,
    required this.gridY,
    required this.type,
    required this.color,
  });

  factory MapTile.fromJson(Map<String, dynamic> json) {
    return MapTile(
      gridX: json['gridX'] as int,
      gridY: json['gridY'] as int,
      type: TileType.values.byName(json['type'] as String),
      color: GameColor.fromJson(json['color'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'gridX': gridX,
        'gridY': gridY,
        'type': type.name,
        'color': color.toJson(),
      };
}

/// Full game state snapshot.
class GameStateModel {
  final String roomCode;
  GamePhase phase;
  double timeRemaining;
  final List<PlayerModel> players;
  final List<List<MapTile>> mapData;
  int roundNumber;

  GameStateModel({
    required this.roomCode,
    this.phase = GamePhase.lobby,
    this.timeRemaining = 0,
    List<PlayerModel>? players,
    List<List<MapTile>>? mapData,
    this.roundNumber = 0,
  })  : players = players ?? [],
        mapData = mapData ?? [];

  factory GameStateModel.fromJson(Map<String, dynamic> json) {
    return GameStateModel(
      roomCode: json['roomCode'] as String,
      phase: GamePhase.values.byName(json['phase'] as String),
      timeRemaining: (json['timeRemaining'] as num).toDouble(),
      players: (json['players'] as List)
          .map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      roundNumber: json['roundNumber'] as int,
      // mapData is sent separately for efficiency
    );
  }

  Map<String, dynamic> toJson() => {
        'roomCode': roomCode,
        'phase': phase.name,
        'timeRemaining': timeRemaining,
        'players': players.map((p) => p.toJson()).toList(),
        'roundNumber': roundNumber,
      };
}
