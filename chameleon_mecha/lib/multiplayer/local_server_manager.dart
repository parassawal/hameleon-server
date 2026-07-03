import 'dart:io';
import 'package:chameleon_server/chameleon_server.dart';
import 'package:shared/constants.dart';

class LocalServerManager {
  static HttpServer? _server;
  static String? _localIp;

  /// Starts the embedded Dart server on the local Wi-Fi network.
  static Future<String?> startLocalServer() async {
    if (_server != null) return _localIp;

    try {
      // Find local Wi-Fi IP address
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prefer wlan0 or en0 (typical Wi-Fi interfaces)
      for (var interface in interfaces) {
        if (interface.name.contains('wlan') || interface.name.contains('en')) {
          _localIp = interface.addresses.first.address;
          break;
        }
      }

      // Fallback if specific interface not found
      if (_localIp == null && interfaces.isNotEmpty) {
        _localIp = interfaces.first.addresses.first.address;
      }

      // Start the game server
      _server = await startServer(port: GameConstants.serverPort);
      print('🚀 Local Server started on $_localIp:${GameConstants.serverPort}');
      
      return _localIp;
    } catch (e) {
      print('❌ Failed to start local server: $e');
      return null;
    }
  }

  /// Stops the embedded server.
  static Future<void> stopLocalServer() async {
    await _server?.close(force: true);
    _server = null;
    _localIp = null;
    print('🛑 Local Server stopped.');
  }

  /// Whether the server is currently running on this device.
  static bool get isRunning => _server != null;

  /// The local IP address if the server is running.
  static String? get localIp => _localIp;
}
