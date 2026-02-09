import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/project_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/question.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectProvider(projectId));

    return projectAsync.when(
      data: (project) {
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project')),
            body: const Center(child: Text('Project not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.leaderboard),
                onPressed: () => context.push('/rankings/$projectId'),
                tooltip: 'Rankings',
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Project'),
                        content: const Text('Are you sure you want to delete this project?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete',
                                style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(projectsProvider.notifier)
                          .deleteProject(projectId);
                      if (context.mounted) {
                        context.go('/');
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/project/$projectId/add-questions'),
            tooltip: 'Add Questions',
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              // Project Info Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${project.questionCount} Questions',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Chip(
                            label: Text(
                              project.canResetRankings ? 'Complete' : 'In Progress',
                              style: TextStyle(
                                color: project.canResetRankings
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                            backgroundColor: project.canResetRankings
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: project.usageProgress,
                        backgroundColor: AppColors.surfaceVariant,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Used: ${project.usedQuestionCount}/${project.questionCount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),

              // Start Tournament Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: project.questionCount >= 10
                        ? () => context.push('/pre-match/$projectId')
                        : null,
                    icon: Image.asset('assets/images/trophy_icon.png', width: 24, height: 24),
                    label: const Text('Start Tournament'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              if (project.questionCount < 10)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'At least 10 questions required to start a tournament',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                  ),
                ),

              const SizedBox(height: 16),

              // Questions List
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Question List',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: project.questions.length,
                        itemBuilder: (context, index) {
                          final question = project.questions[index];
                          final isUsed =
                              project.usedQuestionIds.contains(question.id);
                          return _QuestionCard(
                            question: question,
                            index: index + 1,
                            isUsed: isUsed,
                            projectId: projectId,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _QuestionCard extends ConsumerWidget {
  final Question question;
  final int index;
  final bool isUsed;
  final String projectId;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.isUsed,
    required this.projectId,
  });

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final questionController = TextEditingController(text: question.questionText);
    final answerController = TextEditingController(text: question.correctAnswer);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Question'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newQuestion = questionController.text.trim();
      final newAnswer = answerController.text.trim();
      if (newQuestion.isNotEmpty && newAnswer.isNotEmpty) {
        final updated = question.copyWith(
          questionText: newQuestion,
          correctAnswer: newAnswer,
        );
        await ref.read(projectsProvider.notifier).updateQuestion(projectId, updated);
      }
    }

    questionController.dispose();
    answerController.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text(
          'Delete this question?\n\n"${question.questionText}"',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(projectsProvider.notifier).deleteQuestion(projectId, question.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isUsed ? AppColors.surfaceVariant : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isUsed ? AppColors.success : AppColors.primary,
          child: Text(
            '$index',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          question.questionText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: isUsed
            ? const Text('Used', style: TextStyle(color: AppColors.success))
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Answer:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.correctAnswer,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditDialog(context, ref),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref),
                      icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                      label: const Text('Delete',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
