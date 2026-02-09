import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/persona_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../../data/models/tournament.dart';
import '../../../data/models/question.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/constants/app_constants.dart';

class MatchScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const MatchScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  int _currentQuestionIndex = 0;
  int _userScore = 0;
  int _aiScore = 0;
  String? _selectedAnswer;
  String _fillBlankAnswer = '';
  final TextEditingController _fillBlankController = TextEditingController();
  bool _answered = false;
  bool _showResult = false;
  Timer? _timer;
  int _timeLeft = 30;
  List<Question> _questions = [];
  List<String> _currentChoices = [];
  String? _aiOpponentId;
  String _aiOpponentName = 'AI';

  // No time limit mode
  bool _noTimeLimit = false;
  bool _isUserTurn = true;  // User always starts first in no time limit mode
  bool _userAnsweredWrong = false;
  bool _aiAnsweredWrong = false;
  String? _lastWrongAnswer;  // Track wrong answer for display
  final List<WrongAnswer> _wrongAnswerRecords = []; // Collect wrong answers for analysis

  // AI Challenge for fill-in-blank
  bool _canChallenge = false; // Show challenge button when fill-in-blank answer is wrong
  bool _challenging = false; // Loading state during challenge
  bool? _challengeResult; // null = not challenged, true = accepted, false = rejected

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fillBlankController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchData() async {
    final tournament = await ref.read(tournamentByIdProvider(widget.tournamentId).future);
    if (tournament == null) return;

    final project = await ref.read(projectProvider(tournament.projectId).future);
    if (project == null) return;

    // Get questions for this round (different each round)
    final qPerRound = AppConstants.questionsPerMatch;
    final roundIndex = tournament.currentRoundIndex;
    final allSelectedIds = tournament.selectedQuestionIds;
    final startIdx = roundIndex * qPerRound;
    final endIdx = (startIdx + qPerRound).clamp(0, allSelectedIds.length);
    final roundQuestionIds = allSelectedIds.sublist(startIdx, endIdx);

    final matchQuestions = project.questions
        .where((q) => roundQuestionIds.contains(q.id))
        .toList();

    // Find AI opponent from bracket surviving list
    final opponentId = tournament.userOpponentId;
    if (opponentId != null) {
      _aiOpponentId = opponentId;
      final persona = await ref.read(personaProvider(opponentId).future);
      _aiOpponentName = persona?.name ?? 'AI';
    }

    setState(() {
      _noTimeLimit = tournament.noTimeLimit;
      _questions = matchQuestions;
      if (_questions.isNotEmpty) {
        _generateChoices(project.questions);
      }
    });

    if (!_noTimeLimit) {
      _startTimer();
    }
  }

  void _generateChoices(List<Question> allQuestions) {
    if (_currentQuestionIndex >= _questions.length) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final tournament = ref.read(tournamentByIdProvider(widget.tournamentId)).value;

    // Check if this is semi-finals or finals (subjective questions)
    final isFillBlank = tournament?.status.usesFillBlank ?? false;

    if (isFillBlank) {
      _currentChoices = [];
    } else {
      // Get wrong answers from other questions
      final otherAnswers = allQuestions
          .where((q) => q.id != currentQuestion.id)
          .map((q) => q.correctAnswer)
          .toSet()
          .toList();

      otherAnswers.shuffle();
      final wrongAnswers = otherAnswers.take(4).toList();

      // Combine with correct answer and shuffle
      _currentChoices = [...wrongAnswers, currentQuestion.correctAnswer];
      _currentChoices.shuffle();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0 && !_answered) {
        setState(() => _timeLeft--);
      } else if (_timeLeft == 0 && !_answered) {
        _submitAnswer(null);
      }
    });
  }

  void _submitAnswer(String? answer) {
    if (_answered) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = answer != null &&
        StringUtils.answersMatch(answer, currentQuestion.correctAnswer);

    if (_noTimeLimit) {
      // No time limit mode: alternating turns
      _handleNoTimeLimitAnswer(answer, isCorrect, currentQuestion);
    } else {
      // Normal mode with timer
      _timer?.cancel();
      final aiCorrect = _simulateAIAnswer();

      // Record wrong answer
      if (!isCorrect) {
        final tournament = ref.read(tournamentByIdProvider(widget.tournamentId)).value;
        _wrongAnswerRecords.add(WrongAnswer(
          questionText: currentQuestion.questionText,
          correctAnswer: currentQuestion.correctAnswer,
          userAnswer: answer ?? '(no answer)',
          roundIndex: tournament?.currentRoundIndex ?? 0,
        ));
        // Enable AI Challenge for fill-in-blank questions
        final isFillBlank = tournament?.status.usesFillBlank ?? false;
        if (isFillBlank && answer != null && answer.trim().isNotEmpty) {
          _canChallenge = true;
        }
      }

      setState(() {
        _answered = true;
        _selectedAnswer = answer;
        if (isCorrect) _userScore++;
        if (aiCorrect) _aiScore++;
        _showResult = true;
      });
    }
  }

  void _handleNoTimeLimitAnswer(String? answer, bool isCorrect, Question currentQuestion) {
    if (_isUserTurn) {
      // User's turn
      if (isCorrect) {
        // User got it right - user scores
        setState(() {
          _answered = true;
          _selectedAnswer = answer;
          _userScore++;
          _showResult = true;
        });
      } else {
        // Record wrong answer
        final tournament = ref.read(tournamentByIdProvider(widget.tournamentId)).value;
        _wrongAnswerRecords.add(WrongAnswer(
          questionText: currentQuestion.questionText,
          correctAnswer: currentQuestion.correctAnswer,
          userAnswer: answer ?? '(no answer)',
          roundIndex: tournament?.currentRoundIndex ?? 0,
        ));

        // Enable AI Challenge for fill-in-blank questions
        final isFillBlank = tournament?.status.usesFillBlank ?? false;
        if (isFillBlank && answer != null && answer.trim().isNotEmpty) {
          _canChallenge = true;
        }

        // User got it wrong - AI's turn
        setState(() {
          _userAnsweredWrong = true;
          _lastWrongAnswer = answer;
          _isUserTurn = false;
        });
        // AI attempts to answer
        _aiAttemptAnswer(currentQuestion);
      }
    }
  }

  void _aiAttemptAnswer(Question currentQuestion) {
    // Add delay to simulate AI thinking
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      final aiCorrect = _simulateAIAnswer();

      if (aiCorrect) {
        // AI got it right - AI scores
        setState(() {
          _answered = true;
          _aiScore++;
          _showResult = true;
        });
      } else {
        // AI got it wrong - back to user's turn
        setState(() {
          _aiAnsweredWrong = true;
          _isUserTurn = true;
        });
      }
    });
  }

  bool _simulateAIAnswer() {
    // Simplified AI simulation
    final personas = ref.read(personasProvider).value ?? [];
    if (_aiOpponentId == null || personas.isEmpty) {
      return false;
    }

    final opponent = personas.firstWhere(
      (p) => p.id == _aiOpponentId,
      orElse: () => personas.first,
    );

    // Random based on win rate
    return (DateTime.now().millisecondsSinceEpoch % 100) < (opponent.winRate * 100);
  }

  Future<void> _performChallenge() async {
    if (_challenging || _challengeResult != null) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final userAnswer = _selectedAnswer ?? _fillBlankAnswer;
    if (userAnswer.trim().isEmpty) return;

    setState(() => _challenging = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      final accepted = await gemini.challengeAnswer(
        question: currentQuestion.questionText,
        correctAnswer: currentQuestion.correctAnswer,
        userAnswer: userAnswer,
      );

      if (!mounted) return;

      setState(() {
        _challengeResult = accepted;
        _challenging = false;
      });

      if (accepted) {
        // Challenge succeeded - fix the score
        setState(() => _userScore++);

        // Remove the last wrong answer record for this question
        _wrongAnswerRecords.removeWhere(
          (wa) => wa.questionText == currentQuestion.questionText &&
                  wa.userAnswer == userAnswer,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _challengeResult = false;
        _challenging = false;
      });
    }
  }

  void _nextQuestion() async {
    if (_currentQuestionIndex < _questions.length - 1) {
      final project = await ref.read(
        projectProvider(
          ref.read(tournamentByIdProvider(widget.tournamentId)).value?.projectId ?? '',
        ).future,
      );

      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _fillBlankAnswer = '';
        _fillBlankController.clear();
        _answered = false;
        _showResult = false;
        // Reset turn state for no time limit mode
        _isUserTurn = true;
        _userAnsweredWrong = false;
        _aiAnsweredWrong = false;
        _lastWrongAnswer = null;
        // Reset challenge state
        _canChallenge = false;
        _challenging = false;
        _challengeResult = null;
        if (project != null) {
          _generateChoices(project.questions);
        }
      });
      if (!_noTimeLimit) {
        _startTimer();
      }
    } else {
      // Match finished
      _finishMatch();
    }
  }

  Future<void> _finishMatch() async {
    final userWon = _userScore >= _aiScore;

    // Save wrong answers
    if (_wrongAnswerRecords.isNotEmpty) {
      await ref.read(tournamentProvider.notifier).addWrongAnswers(
            widget.tournamentId,
            _wrongAnswerRecords,
          );
    }

    await ref.read(tournamentProvider.notifier).completeMatch(
          tournamentId: widget.tournamentId,
          userWon: userWon,
          userScore: _userScore,
          aiScore: _aiScore,
        );

    if (!mounted) return;
    final tournament = await ref.read(tournamentByIdProvider(widget.tournamentId).future);

    if (!mounted) return;
    if (tournament?.status == TournamentStatus.completed) {
      final isChampion = tournament?.championId == 'user';
      context.go('/victory/${widget.tournamentId}?champion=$isChampion');
    } else {
      // Show round result dialog with bracket option
      await _showRoundResultDialog(userWon, tournament);
    }
  }

  Future<void> _showRoundResultDialog(bool userWon, Tournament? tournament) async {
    if (!mounted) return;
    final nextRound = tournament?.status.displayName ?? 'Next Round';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              userWon ? Icons.check_circle : Icons.cancel,
              color: userWon ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(userWon ? 'Victory!' : 'Defeated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_userScore - $_aiScore',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'vs $_aiOpponentName',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              userWon
                  ? 'Advancing to $nextRound'
                  : 'You can watch the rest as a spectator',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (_wrongAnswerRecords.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/analysis/${widget.tournamentId}');
              },
              icon: const Icon(Icons.psychology),
              label: const Text('Analysis'),
            ),
          if (userWon)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.go('/tournament/${widget.tournamentId}');
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Next'),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.go('/spectator/${widget.tournamentId}');
              },
              icon: const Icon(Icons.visibility),
              label: const Text('Watch'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final tournament = ref.watch(tournamentByIdProvider(widget.tournamentId)).value;
    final isFillBlank = tournament?.status.usesFillBlank ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament?.status.displayName ?? 'Match'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Score and Timer/Turn Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // User Score
                Column(
                  children: [
                    Row(
                      children: [
                        const Text('Me', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_noTimeLimit && _isUserTurn && !_answered)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.arrow_left, color: AppColors.primary, size: 20),
                          ),
                      ],
                    ),
                    Text(
                      '$_userScore',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (_noTimeLimit && _userAnsweredWrong)
                      const Text('Wrong', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ],
                ),
                // Timer or Turn indicator
                if (_noTimeLimit)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _isUserTurn ? AppColors.primary : AppColors.secondary,
                    ),
                    child: Text(
                      _answered ? 'Done' : (_isUserTurn ? 'Your Turn' : 'AI Turn'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _timeLeft <= 10 ? AppColors.error : AppColors.primary,
                    ),
                    child: Text(
                      '$_timeLeft',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // AI Score
                Column(
                  children: [
                    Row(
                      children: [
                        if (_noTimeLimit && !_isUserTurn && !_answered)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.arrow_right, color: AppColors.secondary, size: 20),
                          ),
                        Text(
                          _aiOpponentName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      '$_aiScore',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    if (_noTimeLimit && _aiAnsweredWrong)
                      const Text('Wrong', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // Progress
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: AppColors.surfaceVariant,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Question ${_currentQuestionIndex + 1}/${_questions.length}'),
          ),

          // Question
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        currentQuestion.questionText,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isFillBlank) ...[
                    // Fill in the blank
                    Text(
                      'Hint: ${StringUtils.getCharacterCountHint(currentQuestion.correctAnswer)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    // No time limit mode: show turn status message
                    if (_noTimeLimit && !_answered) ...[
                      if (!_isUserTurn)
                        Card(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('AI is thinking...'),
                              ],
                            ),
                          ),
                        ),
                      if (_userAnsweredWrong && _lastWrongAnswer != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Wrong: $_lastWrongAnswer',
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _fillBlankController,
                      enabled: !_answered && (!_noTimeLimit || _isUserTurn),
                      onChanged: (value) => _fillBlankAnswer = value,
                      decoration: const InputDecoration(
                        hintText: 'Enter your answer',
                        border: OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    if (!_answered && (!_noTimeLimit || _isUserTurn))
                      ElevatedButton(
                        onPressed: () => _submitAnswer(_fillBlankAnswer),
                        child: const Text('Submit'),
                      ),
                  ] else ...[
                    // No time limit mode: show turn status message
                    if (_noTimeLimit && !_answered) ...[
                      if (!_isUserTurn)
                        Card(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('AI is thinking...'),
                              ],
                            ),
                          ),
                        ),
                      if (_userAnsweredWrong && _lastWrongAnswer != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Wrong: $_lastWrongAnswer',
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    // Multiple choice
                    ..._currentChoices.map((choice) {
                      Color? backgroundColor;
                      Color? textColor;
                      final bool isDisabled = _answered || (_noTimeLimit && !_isUserTurn);

                      if (_showResult) {
                        if (choice == currentQuestion.correctAnswer) {
                          backgroundColor = AppColors.success;
                          textColor = Colors.white;
                        } else if (choice == _selectedAnswer) {
                          backgroundColor = AppColors.error;
                          textColor = Colors.white;
                        }
                      } else if (choice == _selectedAnswer) {
                        backgroundColor = AppColors.primary;
                        textColor = Colors.white;
                      } else if (_noTimeLimit && choice == _lastWrongAnswer) {
                        // Show previously wrong answer in no time limit mode
                        backgroundColor = AppColors.error.withValues(alpha: 0.3);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ElevatedButton(
                          onPressed: isDisabled ? null : () => _submitAnswer(choice),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: backgroundColor,
                            foregroundColor: textColor,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            choice,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }),
                  ],

                  // Result display
                  if (_showResult) ...[
                    const SizedBox(height: 16),
                    Builder(builder: (_) {
                      final isCorrect = _selectedAnswer != null &&
                          StringUtils.answersMatch(
                              _selectedAnswer!, currentQuestion.correctAnswer);
                      final challengeAccepted = _challengeResult == true;
                      final showAsCorrect = isCorrect || challengeAccepted;

                      return Card(
                        color: showAsCorrect
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                showAsCorrect ? Icons.check_circle : Icons.cancel,
                                size: 48,
                                color: showAsCorrect
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Answer: ${currentQuestion.correctAnswer}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (challengeAccepted) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'AI Challenge Accepted!',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              if (_challengeResult == false) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'AI Challenge Rejected',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                    // AI Challenge button for fill-in-blank
                    if (_canChallenge && _challengeResult == null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _challenging ? null : _performChallenge,
                        icon: _challenging
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.gavel),
                        label: Text(_challenging ? 'Checking...' : 'AI Challenge'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      child: Text(
                        _currentQuestionIndex < _questions.length - 1
                            ? 'Next Question'
                            : 'View Results',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
