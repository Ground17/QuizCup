import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_colors.dart';

class VictoryScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final bool isChampion;

  const VictoryScreen({
    super.key,
    required this.tournamentId,
    required this.isChampion,
  });

  @override
  ConsumerState<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends ConsumerState<VictoryScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _trophyController;
  late Animation<double> _trophyAnimation;
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _ceremonyPlayer = AudioPlayer();
  StreamSubscription? _accelerometerSubscription;
  bool _celebrationTriggered = false;
  bool _bgmMuted = true; // Start muted

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));

    _trophyController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _trophyAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.elasticOut),
    );

    if (widget.isChampion) {
      _trophyController.forward();
      _startBgm();
      _setupAccelerometer();
    }
  }

  Future<void> _startBgm() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0); // Start muted
      await _bgmPlayer.play(AssetSource('audio/ceremony_before.mp3'));
    } catch (e) {
      debugPrint('BGM not available: $e');
    }
  }

  void _toggleBgm() {
    setState(() => _bgmMuted = !_bgmMuted);
    _bgmPlayer.setVolume(_bgmMuted ? 0 : 1.0);
    if (!_bgmMuted && _celebrationTriggered) {
      _ceremonyPlayer.setVolume(1.0);
    }
  }

  void _setupAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final isLifted =
          event.z < -8.0 && event.x.abs() < 3.0 && event.y.abs() < 3.0;

      if (isLifted && !_celebrationTriggered) {
        _triggerCelebration();
      }
    });
  }

  void _onTrophyTap() {
    if (!_celebrationTriggered && widget.isChampion) {
      _triggerCelebration();
    }
  }

  Future<void> _triggerCelebration() async {
    if (_celebrationTriggered) return;

    setState(() => _celebrationTriggered = true);
    _confettiController.play();

    // Stop the before-ceremony BGM
    await _bgmPlayer.stop();

    // Play ceremony audio once
    try {
      await _ceremonyPlayer.setReleaseMode(ReleaseMode.release);
      await _ceremonyPlayer.setVolume(_bgmMuted ? 0 : 1.0);
      await _ceremonyPlayer.play(AssetSource('audio/ceremony.mp3'));

      // Listen for completion to finish ceremony
      _ceremonyPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          // Ceremony finished
          // Auto navigate home after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.go('/');
          });
        }
      });
    } catch (e) {
      debugPrint('Ceremony audio not available: $e');
      // If audio fails, still finish after confetti
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          // Ceremony finished
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.go('/');
          });
        }
      });
    }
  }

  void _skipCeremony() {
    _bgmPlayer.stop();
    _ceremonyPlayer.stop();
    context.go('/');
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _trophyController.dispose();
    _bgmPlayer.dispose();
    _ceremonyPlayer.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.isChampion
                    ? [
                        AppColors.gold.withValues(alpha: 0.3),
                        AppColors.gold.withValues(alpha: 0.1)
                      ]
                    : [
                        AppColors.silver.withValues(alpha: 0.3),
                        AppColors.silver.withValues(alpha: 0.1)
                      ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Trophy image (large)
                  GestureDetector(
                    onTap: _onTrophyTap,
                    child: AnimatedBuilder(
                      animation: _trophyAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _trophyAnimation.value,
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/images/trophy_icon.png',
                        width: 560,
                        height: 560,
                        color: widget.isChampion ? null : AppColors.silver,
                        colorBlendMode:
                            widget.isChampion ? null : BlendMode.modulate,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    widget.isChampion ? 'Champion!' : 'Runner-up',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.isChampion
                              ? AppColors.gold
                              : AppColors.silver,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Points
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isChampion
                          ? AppColors.gold.withValues(alpha: 0.2)
                          : AppColors.silver.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.isChampion ? '+3 Points' : '+1 Point',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instruction or celebration message
                  if (widget.isChampion && !_celebrationTriggered) ...[
                    Text(
                      'Tap the trophy or lift your phone!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],

                  if (_celebrationTriggered) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                  ],

                  // Non-champion: show buttons immediately
                  if (!widget.isChampion) ...[
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () =>
                          context.push('/results/${widget.tournamentId}'),
                      child: const Text('View Results'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Home'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.gold,
                AppColors.secondary,
                AppColors.primary,
                Colors.red,
                Colors.blue,
                Colors.green,
              ],
              numberOfParticles: 50,
              gravity: 0.3,
            ),
          ),

          // Bottom controls (champion only)
          if (widget.isChampion)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // BGM toggle (left)
                    IconButton(
                      onPressed: _toggleBgm,
                      icon: Icon(
                        _bgmMuted ? Icons.volume_off : Icons.volume_up,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: _bgmMuted ? 'Unmute BGM' : 'Mute BGM',
                    ),
                    // Skip (right)
                    IconButton(
                      onPressed: _skipCeremony,
                      icon: const Icon(
                        Icons.skip_next,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Skip Ceremony',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
