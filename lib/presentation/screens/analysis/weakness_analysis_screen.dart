import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../../data/models/tournament.dart';
import '../../../core/theme/app_colors.dart';

class WeaknessAnalysisScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const WeaknessAnalysisScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<WeaknessAnalysisScreen> createState() =>
      _WeaknessAnalysisScreenState();
}

class _WeaknessAnalysisScreenState
    extends ConsumerState<WeaknessAnalysisScreen> {
  String? _analysis;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    try {
      final tournament =
          await ref.read(tournamentByIdProvider(widget.tournamentId).future);
      if (tournament == null || tournament.wrongAnswers.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No wrong answers to analyze.';
        });
        return;
      }

      final wrongAnswerMaps = tournament.wrongAnswers
          .map((wa) => {
                'question': wa.questionText,
                'correct': wa.correctAnswer,
                'user': wa.userAnswer,
              })
          .toList();

      final gemini = ref.read(geminiServiceProvider);
      final analysis = await gemini.analyzeWeaknesses(wrongAnswerMaps);

      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync =
        ref.watch(tournamentByIdProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weakness Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI is analyzing your mistakes...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Wrong answers list
                      tournamentAsync.when(
                        data: (tournament) {
                          if (tournament == null) return const SizedBox();
                          return _buildWrongAnswersList(
                              tournament.wrongAnswers);
                        },
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 24),

                      // AI Analysis
                      Card(
                        color: AppColors.info.withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.psychology,
                                      color: AppColors.info),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Analysis',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(color: AppColors.info),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _analysis ?? '',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWrongAnswersList(List<WrongAnswer> wrongAnswers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wrong Answers (${wrongAnswers.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...wrongAnswers.asMap().entries.map((entry) {
          final index = entry.key;
          final wa = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.error,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wa.questionText,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.close, color: AppColors.error, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Your answer: ${wa.userAnswer}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check, color: AppColors.success, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Correct: ${wa.correctAnswer}',
                          style: const TextStyle(color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
