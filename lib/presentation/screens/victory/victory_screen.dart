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
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _accelerometerSubscription;
  bool _phoneLifted = false;
  bool _celebrationTriggered = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));

    _trophyController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _trophyAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.elasticOut),
    );

    if (widget.isChampion) {
      _trophyController.forward();
      _setupAccelerometer();
    }
  }

  void _setupAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      // Detect phone lift (z-axis pointing up when phone is raised)
      final isLifted = event.z < -8.0 && event.x.abs() < 3.0 && event.y.abs() < 3.0;

      if (isLifted && !_phoneLifted && !_celebrationTriggered) {
        setState(() {
          _phoneLifted = true;
          _celebrationTriggered = true;
        });
        _triggerCelebration();
      }
    });
  }

  Future<void> _triggerCelebration() async {
    _confettiController.play();

    // Play cheering sound (would need actual audio file)
    try {
      await _audioPlayer.play(AssetSource('audio/cheering.mp3'));
    } catch (e) {
      // Audio file might not exist yet
      debugPrint('Audio not available: $e');
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _trophyController.dispose();
    _audioPlayer.dispose();
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
                    ? [AppColors.gold.withValues(alpha: 0.3), AppColors.gold.withValues(alpha: 0.1)]
                    : [AppColors.silver.withValues(alpha: 0.3), AppColors.silver.withValues(alpha: 0.1)],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Trophy
                  AnimatedBuilder(
                    animation: _trophyAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _trophyAnimation.value,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.emoji_events,
                      size: 150,
                      color: widget.isChampion ? AppColors.gold : AppColors.silver,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    widget.isChampion ? 'Champion!' : 'Runner-up',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.isChampion
                              ? AppColors.gold
                              : AppColors.silver,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Points
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isChampion
                          ? AppColors.gold.withValues(alpha: 0.2)
                          : AppColors.silver.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      widget.isChampion ? '+3 Points' : '+1 Point',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Phone lift instruction (champion only)
                  if (widget.isChampion && !_celebrationTriggered) ...[
                    const Icon(
                      Icons.phone_android,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lift your phone to celebrate!',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],

                  if (_celebrationTriggered) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Buttons
                  ElevatedButton(
                    onPressed: () => context.push('/results/${widget.tournamentId}'),
                    child: const Text('View Results'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Home'),
                  ),
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
        ],
      ),
    );
  }
}
