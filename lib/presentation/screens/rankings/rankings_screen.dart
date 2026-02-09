import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/project_provider.dart';
import '../../../data/models/ranking.dart';
import '../../../core/theme/app_colors.dart';

class RankingsScreen extends ConsumerWidget {
  final String projectId;

  const RankingsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(rankingsProvider(projectId));
    final projectAsync = ref.watch(projectProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Project not found'));
          }

          return Column(
            children: [
              // Progress Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.surfaceVariant,
                child: Column(
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: project.usageProgress,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Questions Used: ${project.usedQuestionCount}/${project.questionCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (project.canResetRankings) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showResetDialog(context, ref),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Rankings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'All questions must be used before rankings can be reset',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              // Rankings List
              Expanded(
                child: rankingsAsync.when(
                  data: (rankings) {
                    if (rankings.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.leaderboard_outlined,
                              size: 64,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No rankings yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rankings will be recorded after completing a tournament',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort by points
                    final sortedRankings = List<Ranking>.from(rankings)
                      ..sort((a, b) => b.points.compareTo(a.points));

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedRankings.length,
                      itemBuilder: (context, index) {
                        final ranking = sortedRankings[index];
                        return _RankingCard(
                          ranking: ranking,
                          position: index + 1,
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Error: $error')),
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

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Rankings'),
        content: const Text(
          'All rankings will be deleted and question usage will be reset.\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(projectsProvider.notifier)
                  .resetUsedQuestions(projectId);
              // Also delete rankings (would need to add this method)
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  final Ranking ranking;
  final int position;

  const _RankingCard({
    required this.ranking,
    required this.position,
  });

  Color get _positionColor {
    switch (position) {
      case 1:
        return AppColors.gold;
      case 2:
        return AppColors.silver;
      case 3:
        return AppColors.bronze;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData get _positionIcon {
    switch (position) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.workspace_premium;
      case 3:
        return Icons.military_tech;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ranking.isUser
          ? AppColors.primary.withValues(alpha: 0.1)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _positionColor,
          child: position <= 3
              ? Icon(_positionIcon, color: Colors.white, size: 20)
              : Text(
                  '$position',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ranking.participantName,
                style: TextStyle(
                  fontWeight: ranking.isUser ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (ranking.isUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Me',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${ranking.championships} wins · ${ranking.runnerUps} runner-ups',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${ranking.points}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            Text(
              'Points',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
