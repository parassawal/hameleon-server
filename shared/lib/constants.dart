/// Game constants shared between client and server.
class GameConstants {
  // Player limits
  static const int minPlayers = 2;
  static const int maxPlayers = 8;

  // Timing (in seconds)
  static const int lobbyCountdown = 5;
  static const int hidingPhaseDuration = 15;
  static const int seekingPhaseDuration = 120;
  static const int resultsDisplayDuration = 10;

  // Map dimensions (in tiles)
  static const int mapWidth = 30;
  static const int mapHeight = 20;
  static const double tileSize = 48.0;

  // Player
  static const double playerSpeed = 150.0;
  static const double playerSize = 40.0;

  // Detection
  static const double detectionRadius = 120.0;
  static const double scanPulseRadius = 200.0;
  static const double scanCooldown = 3.0; // seconds between scans

  // Camouflage
  static const double perfectCamoThreshold = 15.0; // color distance
  static const double goodCamoThreshold = 40.0;
  static const double poorCamoThreshold = 80.0;

  // Scoring
  static const int hiderSurvivePoints = 100;
  static const int hiderTimeBonus = 1; // per second survived
  static const int seekerTagPoints = 50;
  static const int seekerSpeedBonus = 25; // bonus for quick finds

  // Network
  static const int serverPort = 443;
  static const String serverHost = 'hameleon-server-production.up.railway.app';
  static const int heartbeatIntervalMs = 5000;
  static const int reconnectDelayMs = 1000;
  static const int maxReconnectDelayMs = 16000;

  // Room
  static const int roomCodeLength = 4;
}
