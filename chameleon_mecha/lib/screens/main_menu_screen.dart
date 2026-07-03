import 'dart:math';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../multiplayer/local_server_manager.dart';
import 'lobby_screen.dart';

/// Animated main menu with cyberpunk neon aesthetic.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _titleController;
  late AnimationController _buttonController;
  final _nameController = TextEditingController(text: 'Player');
  bool _showJoinDialog = false;
  final _roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _titleController.dispose();
    _buttonController.dispose();
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HSLColor.fromAHSL(1, _bgController.value * 360, 0.8, 0.08).toColor(),
                  const Color(0xFF0a0a1a),
                  HSLColor.fromAHSL(1, (_bgController.value * 360 + 180) % 360, 0.6, 0.1).toColor(),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Animated background particles
                  CustomPaint(
                    painter: _ParticlePainter(progress: _bgController.value),
                    size: Size.infinite,
                  ),
                  // Main content
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title
                          AnimatedBuilder(
                            animation: _titleController,
                            builder: (context, _) {
                              final glow = 4.0 + _titleController.value * 8;
                              return Column(
                                children: [
                                  // Chameleon icon
                                  Text(
                                    '🦎',
                                    style: TextStyle(fontSize: 64),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'CHAMELEON',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.cyanAccent,
                                      letterSpacing: 8,
                                      shadows: [
                                        Shadow(
                                          color: Colors.cyanAccent.withValues(alpha: 0.8),
                                          blurRadius: glow,
                                        ),
                                        Shadow(
                                          color: Colors.cyan.withValues(alpha: 0.4),
                                          blurRadius: glow * 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'MECHA',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFF6B35),
                                      letterSpacing: 16,
                                      shadows: [
                                        Shadow(
                                          color: const Color(0xFFFF6B35).withValues(alpha: 0.6),
                                          blurRadius: glow,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // Subtitle
                          Text(
                            'HIDE • CAMOUFLAGE • SURVIVE',
                            style: GoogleFonts.rajdhani(
                              fontSize: 16,
                              color: Colors.white38,
                              letterSpacing: 6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 50),

                          // Player name input
                          _buildNameInput(),

                          const SizedBox(height: 30),

                          // Buttons
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _buttonController,
                              curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
                            )),
                            child: _buildMenuButton(
                              label: 'HOST LOCAL GAME',
                              icon: Icons.wifi_tethering,
                              color: Colors.cyanAccent,
                              onTap: _onHostGame,
                            ),
                          ),

                          const SizedBox(height: 16),

                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _buttonController,
                              curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
                            )),
                            child: _buildMenuButton(
                              label: 'JOIN LOCAL GAME',
                              icon: Icons.wifi,
                              color: const Color(0xFFFF6B35),
                              onTap: () => setState(() => _showJoinDialog = true),
                            ),
                          ),

                          // Join dialog
                          if (_showJoinDialog) ...[
                            const SizedBox(height: 20),
                            _buildJoinDialog(),
                          ],

                          const SizedBox(height: 50),

                          // Version
                          Text(
                            'v1.0.0 • MULTIPLAYER',
                            style: GoogleFonts.rajdhani(
                              fontSize: 12,
                              color: Colors.white24,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNameInput() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _nameController,
        style: GoogleFonts.rajdhani(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Your Name',
          hintStyle: GoogleFonts.rajdhani(
            color: Colors.white30,
            fontSize: 18,
          ),
          prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent, size: 20),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 280,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.orbitron(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinDialog() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'ENTER HOST IP',
            style: GoogleFonts.orbitron(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomCodeController,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '192.168.1.x',
              hintStyle: GoogleFonts.orbitron(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => setState(() => _showJoinDialog = false),
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.rajdhani(color: Colors.white38),
                ),
              ),
              ElevatedButton(
                onPressed: _onJoinGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  foregroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'JOIN',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onHostGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Start local server
    final ip = await LocalServerManager.startLocalServer();
    if (!mounted) return;
    
    // Hide loading
    Navigator.pop(context);

    if (ip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start local server')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          playerName: name,
          roomCode: null,
          serverUrl: 'ws://127.0.0.1:8080',
        ),
      ),
    );
  }

  void _onJoinGame() {
    final name = _nameController.text.trim();
    final ip = _roomCodeController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter host IP')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          playerName: name,
          roomCode: null,
          serverUrl: 'ws://$ip:8080',
        ),
      ),
    );
  }
}

/// Animated background particles.
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final y = (baseY + progress * size.height * speed) % size.height;
      final radius = 1.0 + random.nextDouble() * 2;
      final alpha = (0.1 + random.nextDouble() * 0.2) *
          (0.5 + 0.5 * sin(progress * 2 * pi + i));

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.cyanAccent.withValues(alpha: alpha.clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
