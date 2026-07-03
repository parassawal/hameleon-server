import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/chameleon_game.dart';
import '../multiplayer/game_client.dart';
import '../multiplayer/game_state.dart';
import 'results_screen.dart';

/// Wrapper screen that hosts the Flame GameWidget with overlay UI.
class GameScreen extends StatefulWidget {
  final GameClient client;
  final GameStateManager stateManager;

  const GameScreen({
    super.key,
    required this.client,
    required this.stateManager,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ChameleonGame _game;
  late StreamSubscription _phaseSub;
  bool _showPause = false;

  @override
  void initState() {
    super.initState();
    _game = ChameleonGame(
      client: widget.client,
      stateManager: widget.stateManager,
    );

    // Listen for results phase to navigate
    _phaseSub = widget.stateManager.phaseChanges.listen((phase) {
      if (phase == GamePhase.results && mounted) {
        // Show results overlay
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              stateManager: widget.stateManager,
              client: widget.client,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _phaseSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Flame game widget
          GameWidget(game: _game),

          // Pause button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => setState(() => _showPause = true),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                child: const Icon(Icons.pause, color: Colors.white70, size: 20),
              ),
            ),
          ),

          // Scan button for seekers
          StreamBuilder<GameStateModel>(
            stream: widget.stateManager.stateUpdates,
            builder: (context, snapshot) {
              final myPlayer = widget.stateManager.myPlayer;
              if (myPlayer?.role != PlayerRole.seeker) return const SizedBox();

              return Positioned(
                bottom: 30,
                right: 30,
                child: GestureDetector(
                  onTap: () => widget.client.scanPulse(),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF4400).withValues(alpha: 0.6),
                          const Color(0xFFFF4400).withValues(alpha: 0.2),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFF4400).withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4400).withValues(alpha: 0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),

          // Pause overlay
          if (_showPause)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'PAUSED',
                      style: GoogleFonts.orbitron(
                        color: Colors.cyanAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildPauseButton(
                      'RESUME',
                      Colors.cyanAccent,
                      () => setState(() => _showPause = false),
                    ),
                    const SizedBox(height: 16),
                    _buildPauseButton(
                      'LEAVE GAME',
                      Colors.redAccent,
                      () {
                        widget.client.leaveRoom();
                        widget.client.disconnect();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPauseButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 200,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
