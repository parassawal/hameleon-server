import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../multiplayer/game_client.dart';
import '../multiplayer/game_state.dart';

/// Results screen shown at the end of each round.
class ResultsScreen extends StatefulWidget {
  final GameStateManager stateManager;
  final GameClient client;

  const ResultsScreen({
    super.key,
    required this.stateManager,
    required this.client,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _revealController;
  late AnimationController _shineController;
  late StreamSubscription _phaseSub;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Listen for return to lobby
    _phaseSub = widget.stateManager.phaseChanges.listen((phase) {
      if (phase == GamePhase.lobby && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _shineController.dispose();
    _phaseSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.stateManager.state;
    if (state == null) return const SizedBox();

    // Sort players by score
    final sorted = List<PlayerModel>.from(state.players)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _revealController,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Title
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _revealController,
                      curve: const Interval(0, 0.3),
                    ),
                    child: Text(
                      '🏆 ROUND RESULTS',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFFFFD700),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _revealController,
                      curve: const Interval(0.1, 0.4),
                    ),
                    child: Text(
                      'Round ${state.roundNumber}',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Rankings
                  Expanded(
                    child: ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final delay = 0.2 + index * 0.1;
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _revealController,
                            curve: Interval(
                              delay.clamp(0, 0.8),
                              (delay + 0.3).clamp(0, 1),
                            ),
                          ),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.5, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _revealController,
                              curve: Interval(
                                delay.clamp(0, 0.8),
                                (delay + 0.3).clamp(0, 1),
                                curve: Curves.easeOutBack,
                              ),
                            )),
                            child: _buildRankingTile(sorted[index], index),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Auto-return countdown
                  StreamBuilder<GameStateModel>(
                    stream: widget.stateManager.stateUpdates,
                    builder: (context, snapshot) {
                      final time = widget.stateManager.state?.timeRemaining ?? 0;
                      return Text(
                        'Returning to lobby in ${time.ceil()}s...',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white30,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankingTile(PlayerModel player, int rank) {
    final isMe = player.id == widget.stateManager.myPlayerId;
    final isFirst = rank == 0;

    Color rankColor;
    String rankEmoji;
    switch (rank) {
      case 0:
        rankColor = const Color(0xFFFFD700);
        rankEmoji = '🥇';
        break;
      case 1:
        rankColor = const Color(0xFFC0C0C0);
        rankEmoji = '🥈';
        break;
      case 2:
        rankColor = const Color(0xFFCD7F32);
        rankEmoji = '🥉';
        break;
      default:
        rankColor = Colors.white38;
        rankEmoji = '${rank + 1}';
    }

    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isFirst
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: 0.15),
                      const Color(0xFFFFD700).withValues(alpha: 0.05),
                      const Color(0xFFFFD700).withValues(alpha: 0.15),
                    ],
                    stops: [
                      0,
                      _shineController.value,
                      1,
                    ],
                  )
                : null,
            color: isFirst
                ? null
                : isMe
                    ? Colors.cyanAccent.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: isFirst
                  ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                  : isMe
                      ? Colors.cyanAccent.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
              width: isFirst ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 40,
                child: Text(
                  rankEmoji,
                  style: const TextStyle(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(width: 12),

              // Player info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          player.name,
                          style: GoogleFonts.rajdhani(
                            color: isFirst ? const Color(0xFFFFD700) : Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                    Text(
                      player.role == PlayerRole.seeker
                          ? '🔍 Seeker${player.isTagged ? "" : ""}'
                          : player.isTagged
                              ? '🦎 Hider (Tagged!)'
                              : '🦎 Hider (Survived!)',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: rankColor.withValues(alpha: 0.15),
                ),
                child: Text(
                  '${player.score}',
                  style: GoogleFonts.orbitron(
                    color: rankColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
