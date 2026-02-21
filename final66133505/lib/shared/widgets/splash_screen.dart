import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen splash shown while the app is booting and pulling from Firestore.
///
/// Receives a [Future] that resolves when startup is done. Once the future
/// completes, [onReady] is called and the caller can navigate to the main shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.startupFuture,
    required this.onReady,
  });

  /// The async work to wait for (Firestore pull, DI init, etc.).
  final Future<void> Function() startupFuture;

  /// Called once [startupFuture] resolves. Navigate to the main app here.
  final VoidCallback onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  String _statusMessage = 'Initializing…';
  bool _isDone = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _runStartup();
  }

  Future<void> _runStartup() async {
    _setStatus('Connecting to server…');
    try {
      await widget.startupFuture();
      _setStatus('Ready!');
      _isDone = true;
      // Brief pause so "Ready!" is visible before transition.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) widget.onReady();
    } catch (_) {
      _setStatus('Starting offline…');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) widget.onReady();
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Animated logo / icon ─────────────────────────────────
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.25),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.how_to_vote_rounded,
                    size: 52,
                    color: cs.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── App name ─────────────────────────────────────────────
            Text(
              'Election Monitor',
              style: GoogleFonts.prompt(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Incident Reporting System',
              style: GoogleFonts.prompt(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 48),

            // ── Progress indicator ───────────────────────────────────
            if (!_isDone)
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(8),
                  color: cs.primary,
                  backgroundColor: cs.primaryContainer,
                ),
              ),

            if (_isDone)
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade600,
                size: 28,
              ),

            const SizedBox(height: 16),

            // ── Status message ───────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusMessage,
                key: ValueKey(_statusMessage),
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
