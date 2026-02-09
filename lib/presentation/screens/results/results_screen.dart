import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/project_provider.dart';
import '../../../data/models/question.dart';
import '../../../core/theme/app_colors.dart';

class ResultsScreen extends ConsumerWidget {
  final String tournamentId;

  const ResultsScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(tournamentId));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Results')),
            body: const Center(child: Text('Tournament not found')),
          );
        }

        final projectAsync = ref.watch(projectProvider(tournament.projectId));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tournament Results'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.go('/'),
            ),
          ),
          body: projectAsync.when(
            data: (project) {
              if (project == null) {
                return const Center(child: Text('Project not found'));
              }

              final questions = project.questions
                  .where((q) => tournament.selectedQuestionIds.contains(q.id))
                  .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tournament Summary Card
                    Card(
                      color: tournament.championId == 'user'
                          ? AppColors.gold.withValues(alpha: 0.1)
                          : AppColors.surfaceVariant,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            tournament.championId == 'user'
                                ? Image.asset(
                                    'assets/images/trophy_icon.png',
                                    width: 48,
                                    height: 48,
                                  )
                                : const Icon(
                                    Icons.sports_score,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                            const SizedBox(height: 8),
                            Text(
                              tournament.championId == 'user' ? 'Champion!' : 'Tournament Complete',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatItem(
                                  label: 'Questions',
                                  value: '${questions.length}',
                                ),
                                _StatItem(
                                  label: 'Points Earned',
                                  value: tournament.championId == 'user'
                                      ? '+3'
                                      : tournament.runnerUpId == 'user'
                                          ? '+1'
                                          : '0',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Questions Review
                    Text(
                      'Questions Asked',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final question = entry.value;
                      return _QuestionReviewCard(
                        question: question,
                        index: index + 1,
                      );
                    }),

                    const SizedBox(height: 24),

                    // Wrong answers analysis
                    if (tournament.wrongAnswers.isNotEmpty) ...[
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/analysis/${tournament.id}'),
                        icon: const Icon(Icons.psychology),
                        label: const Text('AI Weakness Analysis'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Buttons
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/rankings/${tournament.projectId}'),
                      icon: const Icon(Icons.leaderboard),
                      label: const Text('View Rankings'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Home'),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  final Question question;
  final int index;

  const _QuestionReviewCard({
    required this.question,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Answer: ${question.correctAnswer}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
