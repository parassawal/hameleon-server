import 'dart:io';
import 'dart:convert';
import 'package:shared/models.dart';
import 'package:shared/protocol.dart';

void main() async {
  print('Connecting to wss://hameleon-server-production.up.railway.app...');
  try {
    final ws = await WebSocket.connect('wss://hameleon-server-production.up.railway.app');
    print('Connected!');
    
    ws.add(GameMessage.heartbeatMsg().toJson());
    
    ws.listen((message) {
      print('Received: $message');
      ws.close();
    });
  } catch (e) {
    print('Error: $e');
  }
}
