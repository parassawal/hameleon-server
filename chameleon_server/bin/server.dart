import 'dart:io';
import 'package:chameleon_server/chameleon_server.dart';
import 'package:shared/constants.dart';

void main() async {
  final port = Platform.environment['PORT'] != null
      ? int.parse(Platform.environment['PORT']!)
      : GameConstants.serverPort;

  await startServer(port: port);
}
