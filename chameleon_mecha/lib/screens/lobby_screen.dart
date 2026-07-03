import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../multiplayer/game_client.dart';
import '../multiplayer/game_state.dart';
import 'game_screen.dart';

/// Multiplayer lobby — waiting room before the game starts.
class LobbyScreen extends StatefulWidget {
  final String playerName;
  final String? roomCode;

  const LobbyScreen({
    super.key,
    required this.playerName,
    this.roomCode,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with TickerProviderStateMixin {
  late GameClient _client;
  late GameStateManager _stateManager;
  late AnimationController _pulseController;
  final List<StreamSubscription> _subscriptions = [];

  bool _connecting = true;
  String? _error;
  String? _roomCode;
  GameStateModel? _state;

  @override
  void initState() {
    super.initState();
    _client = GameClient();
    _stateManager = GameStateManager();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _connect();
  }

  Future<void> _connect() async {
    // Forward all messages to state manager
    _subscriptions.add(
      _client.messages.listen((msg) {
        _stateManager.processMessage(msg);
      }),
    );

    // Listen for state updates
    _subscriptions.add(
      _stateManager.stateUpdates.listen((state) {
        if (mounted) {
          setState(() {
            _state = state;
            _roomCode = state.roomCode;
          });
        }

        // Auto-transition to game when phase changes from lobby
        if (state.phase != GamePhase.lobby) {
          _navigateToGame();
        }
      }),
    );

    // Listen for errors
    _subscriptions.add(
      _stateManager.errors.listen((error) {
        if (mounted) {
          setState(() => _error = error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }),
    );

    // Connect
    final connected = await _client.connect();
    if (mounted) {
      setState(() => _connecting = false);
    }

    if (connected) {
      // Join or create room
      _client.joinRoom(
        playerName: widget.playerName,
        roomCode: widget.roomCode,
      );
    } else {
      if (mounted) {
        setState(() => _error = 'Could not connect to server');
      }
    }
  }

  void _navigateToGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          client: _client,
          stateManager: _stateManager,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _pulseController.dispose();
    // Don't dispose client/state manager if navigating to game
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () {
            _client.leaveRoom();
            _client.disconnect();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'LOBBY',
          style: GoogleFonts.orbitron(
            color: Colors.cyanAccent,
            fontSize: 18,
            letterSpacing: 4,
          ),
        ),
        centerTitle: true,
      ),
      body: _connecting
          ? _buildConnecting()
          : _error != null && _state == null
              ? _buildError()
              : _buildLobby(),
    );
  }

  Widget _buildConnecting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.cyanAccent),
          const SizedBox(height: 20),
          Text(
            'CONNECTING...',
            style: GoogleFonts.orbitron(
              color: Colors.white38,
              fontSize: 14,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.rajdhani(
              color: Colors.white60,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _connecting = true;
                _error = null;
              });
              _connect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.cyanAccent,
            ),
            child: Text('RETRY', style: GoogleFonts.orbitron(letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby() {
    final players = _state?.players ?? [];
    final myPlayer = _stateManager.myPlayer;
    final isHost = myPlayer?.isHost ?? false;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Room code card
          _buildRoomCodeCard(),

          const SizedBox(height: 24),

          // Players list
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'PLAYERS',
                      style: GoogleFonts.orbitron(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 4,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${players.length}/8',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      return _buildPlayerTile(players[index]);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bottom buttons
          Row(
            children: [
              // Ready button
              Expanded(
                child: _buildActionButton(
                  label: myPlayer?.isReady == true ? 'NOT READY' : 'READY',
                  color: myPlayer?.isReady == true ? Colors.redAccent : Colors.greenAccent,
                  onTap: () {
                    _client.setReady(!(myPlayer?.isReady ?? false));
                  },
                ),
              ),

              if (isHost) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'START',
                    color: Colors.cyanAccent,
                    onTap: () => _client.startGame(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final glow = 4 + _pulseController.value * 8;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.cyanAccent.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: Colors.cyanAccent.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.1),
                blurRadius: glow,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'ROOM CODE',
                style: GoogleFonts.orbitron(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _roomCode ?? '----',
                    style: GoogleFonts.orbitron(
                      color: Colors.cyanAccent,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      shadows: [
                        Shadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.6),
                          blurRadius: glow,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      if (_roomCode != null) {
                        Clipboard.setData(ClipboardData(text: _roomCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Room code copied!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, color: Colors.white38, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Share this code with friends',
                style: GoogleFonts.rajdhani(
                  color: Colors.white24,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerTile(PlayerModel player) {
    final isMe = player.id == _stateManager.myPlayerId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isMe
            ? Colors.cyanAccent.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: isMe
              ? Colors.cyanAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.3),
                  const Color(0xFFFF6B35).withValues(alpha: 0.3),
                ],
              ),
            ),
            child: Center(
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (player.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                        ),
                        child: Text(
                          'HOST',
                          style: GoogleFonts.orbitron(
                            color: const Color(0xFFFFD700),
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(you)',
                        style: GoogleFonts.rajdhani(
                          color: Colors.cyanAccent.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Ready indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: player.isReady
                  ? Colors.greenAccent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            child: Text(
              player.isReady ? 'READY' : 'WAITING',
              style: GoogleFonts.orbitron(
                color: player.isReady ? Colors.greenAccent : Colors.white30,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.orbitron(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
