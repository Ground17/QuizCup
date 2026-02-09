import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tournament_provider.dart';
import '../../../data/models/tournament.dart';
import '../../../core/theme/app_colors.dart';

class TournamentBracketScreen extends ConsumerWidget {
  final String tournamentId;

  const TournamentBracketScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(tournamentId));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament')),
            body: const Center(child: Text('Tournament not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tournament.status.displayName),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.go('/'),
            ),
          ),
          body: Column(
            children: [
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    Text(
                      tournament.status.displayName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Remaining: ${tournament.remainingParticipants} participants',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (tournament.spectatorMode) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Spectator Mode',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Progress Indicator
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Progress'),
                        Text('Round ${tournament.currentRoundIndex + 1}/10'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (tournament.currentRoundIndex + 1) / 10,
                      backgroundColor: AppColors.surfaceVariant,
                      minHeight: 8,
                    ),
                  ],
                ),
              ),

              // Round List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    final roundStatus = _getRoundStatus(tournament, index);
                    return _RoundCard(
                      roundIndex: index,
                      status: roundStatus,
                      isCurrentRound: tournament.currentRoundIndex == index,
                    );
                  },
                ),
              ),

              // Action Button
              if (tournament.status != TournamentStatus.completed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (tournament.spectatorMode) {
                          context.push('/spectator/$tournamentId');
                        } else {
                          context.push('/match/$tournamentId');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: tournament.spectatorMode
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                      child: Text(
                        tournament.spectatorMode ? 'Watch' : 'Start Match',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              if (tournament.status == TournamentStatus.completed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/results/$tournamentId'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'View Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  _RoundStatus _getRoundStatus(Tournament tournament, int roundIndex) {
    if (roundIndex < tournament.currentRoundIndex) {
      return _RoundStatus.completed;
    } else if (roundIndex == tournament.currentRoundIndex) {
      return _RoundStatus.current;
    } else {
      return _RoundStatus.upcoming;
    }
  }
}

enum _RoundStatus { completed, current, upcoming }

class _RoundCard extends StatelessWidget {
  final int roundIndex;
  final _RoundStatus status;
  final bool isCurrentRound;

  const _RoundCard({
    required this.roundIndex,
    required this.status,
    required this.isCurrentRound,
  });

  String get _roundName {
    const names = [
      'Round of 1024', 'Round of 512', 'Round of 256', 'Round of 128', 'Round of 64',
      'Round of 32', 'Round of 16', 'Quarterfinals', 'Semifinals', 'Finals'
    ];
    return names[roundIndex];
  }

  String get _questionType {
    return roundIndex >= 8 ? 'Fill-in-blank' : 'Multiple Choice (5 options)';
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case _RoundStatus.completed:
        backgroundColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        icon = Icons.check_circle;
        break;
      case _RoundStatus.current:
        backgroundColor = AppColors.primary.withValues(alpha: 0.1);
        textColor = AppColors.primary;
        icon = Icons.play_circle_filled;
        break;
      case _RoundStatus.upcoming:
        backgroundColor = AppColors.surfaceVariant;
        textColor = AppColors.textTertiary;
        icon = Icons.circle_outlined;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: backgroundColor,
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(
          _roundName,
          style: TextStyle(
            fontWeight: isCurrentRound ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
        subtitle: Text(
          _questionType,
          style: TextStyle(color: textColor.withValues(alpha: 0.7)),
        ),
        trailing: isCurrentRound
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : null,
      ),
    );
  }
}
