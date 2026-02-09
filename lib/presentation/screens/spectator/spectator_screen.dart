import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tournament_provider.dart';
import '../../../data/models/tournament.dart';
import '../../../core/theme/app_colors.dart';

class SpectatorScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const SpectatorScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends ConsumerState<SpectatorScreen> {
  bool _isSimulating = false;
  String _currentMatch = '';
  int _simulationStep = 0;
  Timer? _simulationTimer;

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSimulation() async {
    setState(() => _isSimulating = true);

    // Simulate remaining rounds
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final tournament = await ref.read(tournamentByIdProvider(widget.tournamentId).future);

      if (tournament == null || tournament.status == TournamentStatus.completed) {
        timer.cancel();
        if (!mounted) return;
        final t = await ref.read(tournamentByIdProvider(widget.tournamentId).future);
        final isChampion = t?.championId == 'user';
        if (!mounted) return;
        context.go('/victory/${widget.tournamentId}?champion=$isChampion');
        return;
      }

      setState(() {
        _currentMatch = '${tournament.status.displayName} in progress...';
        _simulationStep++;
      });

      await ref.read(tournamentProvider.notifier).simulateSpectatorRound(widget.tournamentId);
    });
  }

  void _skipToEnd() async {
    _simulationTimer?.cancel();
    setState(() => _isSimulating = true);

    // Fast forward all remaining rounds
    Tournament? tournament = await ref.read(tournamentByIdProvider(widget.tournamentId).future);

    while (tournament != null && tournament.status != TournamentStatus.completed) {
      await ref.read(tournamentProvider.notifier).simulateSpectatorRound(widget.tournamentId);
      // Re-fetch tournament
      final updatedTournament = await ref.read(tournamentByIdProvider(widget.tournamentId).future);
      tournament = updatedTournament;
    }

    if (!mounted) return;
    final t = await ref.read(tournamentByIdProvider(widget.tournamentId).future);
    final isChampion = t?.championId == 'user';
    if (!mounted) return;
    context.go('/victory/${widget.tournamentId}?champion=$isChampion');
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spectator Mode'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: tournamentAsync.when(
        data: (tournament) {
          if (tournament == null) {
            return const Center(child: Text('Tournament not found'));
          }

          return Column(
            children: [
              // Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.secondary.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    const Icon(
                      Icons.visibility,
                      size: 48,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Spectator Mode',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The tournament continues',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              // Current Status
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          tournament.status.displayName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Remaining: ${tournament.remainingParticipants} participants',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: (tournament.currentRoundIndex + 1) / 10,
                          backgroundColor: AppColors.surfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text('Round ${tournament.currentRoundIndex + 1}/10'),
                      ],
                    ),
                  ),
                ),
              ),

              // Simulation Status
              if (_isSimulating) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _currentMatch,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Simulation step: $_simulationStep',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_isSimulating) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startSimulation,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Watching'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _skipToEnd,
                        icon: const Icon(Icons.fast_forward),
                        label: const Text('Skip to Results'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
