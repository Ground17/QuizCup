import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/tournament.dart';
import '../../data/models/project.dart';
import '../../data/models/ai_persona.dart';
import '../../data/models/ranking.dart';
import '../../core/constants/app_constants.dart';
import 'project_provider.dart';
import 'persona_provider.dart';

final tournamentProvider =
    AsyncNotifierProvider<TournamentNotifier, Tournament?>(() {
  return TournamentNotifier();
});

class TournamentNotifier extends AsyncNotifier<Tournament?> {
  static const uuid = Uuid();
  final _random = Random();

  @override
  Future<Tournament?> build() async {
    return null;
  }

  Future<Tournament> createTournament(String projectId, {bool noTimeLimit = false}) async {
    final db = ref.read(databaseServiceProvider);
    final project = await db.getProject(projectId);
    if (project == null) {
      throw Exception('Project not found');
    }

    final personas = await ref.read(personasProvider.future);
    if (personas.length < 1023) {
      throw Exception('Not enough AI participants');
    }

    // Select questions for 10 rounds (3 per round), prioritize unused
    final questionsPerRound = AppConstants.questionsPerMatch;
    final totalNeeded = questionsPerRound * 10;
    final selectedQuestions = _selectQuestions(project, totalNeeded);
    final selectedQuestionIds = selectedQuestions.map((q) => q.id as String).toList();

    // Generate bracket (random positions)
    final userPosition = _random.nextInt(1024);
    final bracket = _generateBracket(personas, userPosition);

    // Initialize surviving IDs in bracket order
    final survivingIds = bracket.map((e) => e.participantId).toList();

    final tournament = Tournament(
      id: uuid.v4(),
      projectId: projectId,
      status: TournamentStatus.roundOf1024,
      bracket: bracket,
      selectedQuestionIds: selectedQuestionIds,
      survivingIds: survivingIds,
      userBracketPosition: userPosition,
      noTimeLimit: noTimeLimit,
      startedAt: DateTime.now(),
    );

    await db.saveTournament(tournament);
    state = AsyncData(tournament);
    return tournament;
  }

  List<BracketEntry> _generateBracket(List<AIPersona> personas, int userPosition) {
    final bracket = <BracketEntry>[];
    final shuffledPersonas = List<AIPersona>.from(personas)..shuffle(_random);

    int personaIndex = 0;
    for (int i = 0; i < 1024; i++) {
      if (i == userPosition) {
        bracket.add(BracketEntry(
          participantId: 'user',
          bracketPosition: i,
          isUser: true,
        ));
      } else {
        bracket.add(BracketEntry(
          participantId: shuffledPersonas[personaIndex].id,
          bracketPosition: i,
          isUser: false,
        ));
        personaIndex++;
      }
    }
    return bracket;
  }

  List<dynamic> _selectQuestions(Project project, int count) {
    // Gather all questions, prioritizing unused
    final unused = List.from(project.unusedQuestions)..shuffle(_random);
    final used = project.questions
        .where((q) => project.usedQuestionIds.contains(q.id))
        .toList()
      ..shuffle(_random);
    final allShuffled = [...unused, ...used];

    if (allShuffled.length >= count) {
      return allShuffled.take(count).toList();
    }

    // If not enough unique questions, cycle through them
    final result = <dynamic>[];
    while (result.length < count) {
      final remaining = count - result.length;
      final batch = List.from(allShuffled)..shuffle(_random);
      result.addAll(batch.take(remaining));
    }
    return result;
  }

  /// Simulate all AI vs AI matches for the current round and advance.
  /// The user's match result is provided via [userWon].
  Future<void> completeMatch({
    required String tournamentId,
    required bool userWon,
    required int userScore,
    required int aiScore,
  }) async {
    final db = ref.read(databaseServiceProvider);
    var tournament = await db.getTournament(tournamentId);
    if (tournament == null) return;

    final personas = await ref.read(personasProvider.future);
    final personaMap = {for (final p in personas) p.id: p};

    final survivors = List<String>.from(tournament.survivingIds);
    final nextSurvivors = <String>[];
    bool spectatorMode = tournament.spectatorMode;

    // Process pairs: 0&1, 2&3, 4&5, ...
    for (int i = 0; i < survivors.length; i += 2) {
      if (i + 1 >= survivors.length) {
        // Odd one out gets a bye
        nextSurvivors.add(survivors[i]);
        continue;
      }

      final p1 = survivors[i];
      final p2 = survivors[i + 1];
      final isUserMatch = p1 == 'user' || p2 == 'user';

      if (isUserMatch && !spectatorMode) {
        // User's match - result was passed in
        if (userWon) {
          nextSurvivors.add('user');
        } else {
          final opponentId = p1 == 'user' ? p2 : p1;
          nextSurvivors.add(opponentId);
          spectatorMode = true;
        }
      } else {
        // AI vs AI - simulate based on win rates
        final winner = _simulateAIvsAI(p1, p2, personaMap);
        nextSurvivors.add(winner);
      }
    }

    // Determine next status
    final nextStatus = _getNextStatus(tournament.status);

    String? championId;
    String? runnerUpId;

    if (nextStatus == TournamentStatus.completed && nextSurvivors.length == 1) {
      championId = nextSurvivors.first;

      // Find runner-up: the loser of the final match
      if (survivors.length == 2) {
        runnerUpId = survivors.firstWhere((id) => id != championId, orElse: () => 'unknown');
      }

      // Update rankings with actual names
      await _updateRankings(tournament.projectId, championId, runnerUpId, personaMap);

      // Mark questions as used
      await ref.read(projectsProvider.notifier).markQuestionsAsUsed(
            tournament.projectId,
            tournament.selectedQuestionIds,
          );
    }

    tournament = tournament.copyWith(
      status: nextStatus,
      survivingIds: nextSurvivors,
      spectatorMode: spectatorMode,
      championId: championId,
      runnerUpId: runnerUpId,
      completedAt: nextStatus == TournamentStatus.completed ? DateTime.now() : null,
    );

    await db.saveTournament(tournament);
    state = AsyncData(tournament);
    // Invalidate the by-ID provider so screens refetch updated data
    ref.invalidate(tournamentByIdProvider(tournamentId));
  }

  /// Simulate a match between two AI participants.
  String _simulateAIvsAI(String id1, String id2, Map<String, AIPersona> personaMap) {
    final p1 = personaMap[id1];
    final p2 = personaMap[id2];

    final rate1 = p1?.winRate ?? 0.5;
    final rate2 = p2?.winRate ?? 0.5;

    // Probability of p1 winning based on relative win rates
    final p1WinProb = rate1 / (rate1 + rate2);
    return _random.nextDouble() < p1WinProb ? id1 : id2;
  }

  TournamentStatus _getNextStatus(TournamentStatus current) {
    switch (current) {
      case TournamentStatus.roundOf1024:
        return TournamentStatus.roundOf512;
      case TournamentStatus.roundOf512:
        return TournamentStatus.roundOf256;
      case TournamentStatus.roundOf256:
        return TournamentStatus.roundOf128;
      case TournamentStatus.roundOf128:
        return TournamentStatus.roundOf64;
      case TournamentStatus.roundOf64:
        return TournamentStatus.roundOf32;
      case TournamentStatus.roundOf32:
        return TournamentStatus.roundOf16;
      case TournamentStatus.roundOf16:
        return TournamentStatus.quarterFinals;
      case TournamentStatus.quarterFinals:
        return TournamentStatus.semiFinals;
      case TournamentStatus.semiFinals:
        return TournamentStatus.finals;
      case TournamentStatus.finals:
        return TournamentStatus.completed;
      default:
        return current;
    }
  }

  Future<void> _updateRankings(
    String projectId,
    String championId,
    String? runnerUpId,
    Map<String, AIPersona> personaMap,
  ) async {
    final db = ref.read(databaseServiceProvider);
    final rankings = await db.getRankings(projectId);

    // Get user profile for name
    final userProfile = await db.getUserProfile();
    final userName = userProfile?.name ?? 'Player';
    final userCountry = userProfile?.country ?? 'KR';

    String getName(String id) {
      if (id == 'user') return userName;
      return personaMap[id]?.name ?? 'AI';
    }
    String getCountry(String id) {
      if (id == 'user') return userCountry;
      return personaMap[id]?.country ?? 'KR';
    }

    // Update or create champion ranking
    final championRanking = rankings.firstWhere(
      (r) => r.participantId == championId,
      orElse: () => Ranking(
        projectId: projectId,
        participantId: championId,
        participantName: getName(championId),
        country: getCountry(championId),
        isUser: championId == 'user',
      ),
    );
    await db.saveRanking(championRanking.copyWith(
      participantName: getName(championId),
      country: getCountry(championId),
    ).addChampionship());

    // Update runner-up
    if (runnerUpId != null) {
      final runnerUpRanking = rankings.firstWhere(
        (r) => r.participantId == runnerUpId,
        orElse: () => Ranking(
          projectId: projectId,
          participantId: runnerUpId,
          participantName: getName(runnerUpId),
          country: getCountry(runnerUpId),
          isUser: runnerUpId == 'user',
        ),
      );
      await db.saveRanking(runnerUpRanking.copyWith(
        participantName: getName(runnerUpId),
        country: getCountry(runnerUpId),
      ).addRunnerUp());
    }
  }

  Future<void> addWrongAnswers(String tournamentId, List<WrongAnswer> newWrongAnswers) async {
    final db = ref.read(databaseServiceProvider);
    var tournament = await db.getTournament(tournamentId);
    if (tournament == null) return;

    final updated = tournament.copyWith(
      wrongAnswers: [...tournament.wrongAnswers, ...newWrongAnswers],
    );
    await db.saveTournament(updated);
    ref.invalidate(tournamentByIdProvider(tournamentId));
  }

  Future<void> simulateSpectatorRound(String tournamentId) async {
    await completeMatch(
      tournamentId: tournamentId,
      userWon: false,
      userScore: 0,
      aiScore: 0,
    );
  }
}

final tournamentByIdProvider =
    FutureProvider.family<Tournament?, String>((ref, tournamentId) async {
  final db = ref.read(databaseServiceProvider);
  return await db.getTournament(tournamentId);
});

final rankingsProvider =
    FutureProvider.family<List<Ranking>, String>((ref, projectId) async {
  final db = ref.read(databaseServiceProvider);
  return await db.getRankings(projectId);
});
