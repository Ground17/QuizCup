import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/project_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class PreMatchScreen extends ConsumerStatefulWidget {
  final String projectId;

  const PreMatchScreen({super.key, required this.projectId});

  @override
  ConsumerState<PreMatchScreen> createState() => _PreMatchScreenState();
}

class _PreMatchScreenState extends ConsumerState<PreMatchScreen> {
  bool _previewQuestions = false;
  bool _noTimeLimit = false;
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Prep'),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Project not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tournament Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/trophy_icon.png',
                          width: 64,
                          height: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          project.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1024-Player Tournament',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const Divider(height: 32),
                        _InfoRow(
                          icon: Icons.quiz,
                          label: 'Questions per Match',
                          value: '${AppConstants.questionsPerMatch}',
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.people,
                          label: 'Participants',
                          value: '1024 (You + 1023 AI)',
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.format_list_numbered,
                          label: 'Total Rounds',
                          value: '10',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Preview Option
                Card(
                  child: SwitchListTile(
                    title: const Text('Preview Questions'),
                    subtitle: const Text('Review questions before the match'),
                    value: _previewQuestions,
                    onChanged: (value) {
                      setState(() => _previewQuestions = value);
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // No Time Limit Option
                Card(
                  child: SwitchListTile(
                    title: const Text('No Time Limit'),
                    subtitle: const Text('Take turns answering without a timer. You go first.'),
                    value: _noTimeLimit,
                    onChanged: (value) {
                      setState(() => _noTimeLimit = value);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Start Button
                ElevatedButton(
                  onPressed: _isStarting ? null : _startTournament,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.gold,
                  ),
                  child: _isStarting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Preparing...'),
                          ],
                        )
                      : const Text(
                          'Start Tournament',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Rules
                Card(
                  color: AppColors.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Rules',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('• From Round of 1024 to Finals'),
                        Text('• Each match has ${AppConstants.questionsPerMatch} questions'),
                        const Text('• Multiple choice (5 options) until Quarterfinals'),
                        const Text('• Semifinals and Finals are fill-in-blank'),
                        const Text('• Spectator mode on defeat'),
                        const Text('• Champion: 3 pts, Runner-up: 1 pt'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _startTournament() async {
    setState(() => _isStarting = true);

    try {
      final tournament = await ref
          .read(tournamentProvider.notifier)
          .createTournament(widget.projectId, noTimeLimit: _noTimeLimit);

      if (!mounted) return;
      if (_previewQuestions) {
        await _showPreviewDialog(tournament.id);
      }
      if (!mounted) return;
      context.go('/tournament/${tournament.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start tournament: $e')),
      );
      setState(() => _isStarting = false);
    }
  }

  Future<void> _showPreviewDialog(String tournamentId) async {
    final tournament = await ref.read(tournamentByIdProvider(tournamentId).future);
    if (tournament == null || !mounted) return;

    final project = await ref.read(projectProvider(widget.projectId).future);
    if (project == null || !mounted) return;

    // Show first round's questions
    final firstRoundIds = tournament.selectedQuestionIds.take(AppConstants.questionsPerMatch).toList();
    final questions = project.questions
        .where((q) => firstRoundIds.contains(q.id))
        .toList();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Question Preview'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    question.questionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Answer: ${question.correctAnswer}'),
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
