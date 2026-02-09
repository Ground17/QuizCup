import 'package:equatable/equatable.dart';
import 'match_result.dart';

enum TournamentStatus {
  notStarted,
  roundOf1024, // Round 0
  roundOf512,  // Round 1
  roundOf256,  // Round 2
  roundOf128,  // Round 3
  roundOf64,   // Round 4
  roundOf32,   // Round 5
  roundOf16,   // Round 6
  quarterFinals, // Round 7
  semiFinals,  // Round 8
  finals,      // Round 9
  completed,
}

extension TournamentStatusExtension on TournamentStatus {
  String get displayName {
    switch (this) {
      case TournamentStatus.notStarted:
        return 'Not Started';
      case TournamentStatus.roundOf1024:
        return 'Round of 1024';
      case TournamentStatus.roundOf512:
        return 'Round of 512';
      case TournamentStatus.roundOf256:
        return 'Round of 256';
      case TournamentStatus.roundOf128:
        return 'Round of 128';
      case TournamentStatus.roundOf64:
        return 'Round of 64';
      case TournamentStatus.roundOf32:
        return 'Round of 32';
      case TournamentStatus.roundOf16:
        return 'Round of 16';
      case TournamentStatus.quarterFinals:
        return 'Quarterfinals';
      case TournamentStatus.semiFinals:
        return 'Semifinals';
      case TournamentStatus.finals:
        return 'Finals';
      case TournamentStatus.completed:
        return 'Completed';
    }
  }

  int get roundNumber {
    switch (this) {
      case TournamentStatus.notStarted:
        return -1;
      case TournamentStatus.roundOf1024:
        return 0;
      case TournamentStatus.roundOf512:
        return 1;
      case TournamentStatus.roundOf256:
        return 2;
      case TournamentStatus.roundOf128:
        return 3;
      case TournamentStatus.roundOf64:
        return 4;
      case TournamentStatus.roundOf32:
        return 5;
      case TournamentStatus.roundOf16:
        return 6;
      case TournamentStatus.quarterFinals:
        return 7;
      case TournamentStatus.semiFinals:
        return 8;
      case TournamentStatus.finals:
        return 9;
      case TournamentStatus.completed:
        return 10;
    }
  }

  /// Check if this round uses fill-in-blank questions
  bool get usesFillBlank {
    return this == TournamentStatus.semiFinals || this == TournamentStatus.finals;
  }
}

/// Represents a user's wrong answer record
class WrongAnswer extends Equatable {
  final String questionText;
  final String correctAnswer;
  final String userAnswer;
  final int roundIndex;

  const WrongAnswer({
    required this.questionText,
    required this.correctAnswer,
    required this.userAnswer,
    required this.roundIndex,
  });

  Map<String, dynamic> toJson() => {
        'questionText': questionText,
        'correctAnswer': correctAnswer,
        'userAnswer': userAnswer,
        'roundIndex': roundIndex,
      };

  factory WrongAnswer.fromJson(Map<String, dynamic> json) => WrongAnswer(
        questionText: json['questionText'] as String,
        correctAnswer: json['correctAnswer'] as String,
        userAnswer: json['userAnswer'] as String,
        roundIndex: json['roundIndex'] as int,
      );

  @override
  List<Object?> get props => [questionText, correctAnswer, userAnswer, roundIndex];
}

/// Represents a tournament bracket entry
class BracketEntry extends Equatable {
  final String participantId;
  final int bracketPosition;
  final bool isUser;

  const BracketEntry({
    required this.participantId,
    required this.bracketPosition,
    required this.isUser,
  });

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'bracketPosition': bracketPosition,
      'isUser': isUser ? 1 : 0,
    };
  }

  factory BracketEntry.fromJson(Map<String, dynamic> json) {
    return BracketEntry(
      participantId: json['participantId'] as String,
      bracketPosition: json['bracketPosition'] as int,
      isUser: json['isUser'] == 1,
    );
  }

  @override
  List<Object?> get props => [participantId, bracketPosition, isUser];
}

/// Represents a single round in the tournament
class TournamentRound extends Equatable {
  final int roundNumber;
  final List<MatchResult> matches;
  final bool isCompleted;

  const TournamentRound({
    required this.roundNumber,
    this.matches = const [],
    this.isCompleted = false,
  });

  TournamentRound copyWith({
    int? roundNumber,
    List<MatchResult>? matches,
    bool? isCompleted,
  }) {
    return TournamentRound(
      roundNumber: roundNumber ?? this.roundNumber,
      matches: matches ?? this.matches,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roundNumber': roundNumber,
      'matches': matches.map((e) => e.toJson()).toList(),
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory TournamentRound.fromJson(Map<String, dynamic> json) {
    return TournamentRound(
      roundNumber: json['roundNumber'] as int,
      matches: (json['matches'] as List<dynamic>?)
              ?.map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isCompleted: json['isCompleted'] == 1,
    );
  }

  @override
  List<Object?> get props => [roundNumber, matches, isCompleted];
}

/// Main Tournament model
class Tournament extends Equatable {
  final String id;
  final String projectId;
  final TournamentStatus status;
  final List<BracketEntry> bracket; // Initial bracket of 1024 participants
  final List<TournamentRound> rounds;
  final List<String> selectedQuestionIds;
  final List<String> survivingIds; // Participants still in the tournament
  final List<WrongAnswer> wrongAnswers; // User's wrong answers for analysis
  final int userBracketPosition;
  final bool spectatorMode; // True if user lost but watching
  final bool noTimeLimit; // If true, no timer - alternating turns until correct
  final String? championId;
  final String? runnerUpId;
  final DateTime startedAt;
  final DateTime? completedAt;

  const Tournament({
    required this.id,
    required this.projectId,
    this.status = TournamentStatus.notStarted,
    this.bracket = const [],
    this.rounds = const [],
    this.selectedQuestionIds = const [],
    this.survivingIds = const [],
    this.wrongAnswers = const [],
    required this.userBracketPosition,
    this.spectatorMode = false,
    this.noTimeLimit = false,
    this.championId,
    this.runnerUpId,
    required this.startedAt,
    this.completedAt,
  });

  /// Check if user is still in tournament
  bool get isUserActive => !spectatorMode && status != TournamentStatus.completed;

  /// Get current round index (0-9)
  int get currentRoundIndex => status.roundNumber;

  /// Get number of participants remaining
  int get remainingParticipants => survivingIds.isEmpty ? 1024 : survivingIds.length;

  /// Get the user's current opponent ID (paired by adjacent positions in survivingIds)
  String? get userOpponentId {
    final userIndex = survivingIds.indexOf('user');
    if (userIndex == -1) return null;
    // Pairs: 0&1, 2&3, 4&5, ...
    if (userIndex % 2 == 0) {
      return userIndex + 1 < survivingIds.length ? survivingIds[userIndex + 1] : null;
    } else {
      return survivingIds[userIndex - 1];
    }
  }

  Tournament copyWith({
    String? id,
    String? projectId,
    TournamentStatus? status,
    List<BracketEntry>? bracket,
    List<TournamentRound>? rounds,
    List<String>? selectedQuestionIds,
    List<String>? survivingIds,
    List<WrongAnswer>? wrongAnswers,
    int? userBracketPosition,
    bool? spectatorMode,
    bool? noTimeLimit,
    String? championId,
    String? runnerUpId,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return Tournament(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      bracket: bracket ?? this.bracket,
      rounds: rounds ?? this.rounds,
      selectedQuestionIds: selectedQuestionIds ?? this.selectedQuestionIds,
      survivingIds: survivingIds ?? this.survivingIds,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      userBracketPosition: userBracketPosition ?? this.userBracketPosition,
      spectatorMode: spectatorMode ?? this.spectatorMode,
      noTimeLimit: noTimeLimit ?? this.noTimeLimit,
      championId: championId ?? this.championId,
      runnerUpId: runnerUpId ?? this.runnerUpId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'status': status.index,
      'bracket': bracket.map((e) => e.toJson()).toList(),
      'rounds': rounds.map((e) => e.toJson()).toList(),
      'selectedQuestionIds': selectedQuestionIds,
      'survivingIds': survivingIds,
      'wrongAnswers': wrongAnswers.map((e) => e.toJson()).toList(),
      'userBracketPosition': userBracketPosition,
      'spectatorMode': spectatorMode ? 1 : 0,
      'noTimeLimit': noTimeLimit ? 1 : 0,
      'championId': championId,
      'runnerUpId': runnerUpId,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      status: TournamentStatus.values[json['status'] as int],
      bracket: (json['bracket'] as List<dynamic>?)
              ?.map((e) => BracketEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rounds: (json['rounds'] as List<dynamic>?)
              ?.map((e) => TournamentRound.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      selectedQuestionIds: (json['selectedQuestionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      survivingIds: (json['survivingIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      wrongAnswers: (json['wrongAnswers'] as List<dynamic>?)
              ?.map((e) => WrongAnswer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      userBracketPosition: json['userBracketPosition'] as int,
      spectatorMode: json['spectatorMode'] == 1,
      noTimeLimit: json['noTimeLimit'] == 1,
      championId: json['championId'] as String?,
      runnerUpId: json['runnerUpId'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        status,
        bracket,
        rounds,
        selectedQuestionIds,
        survivingIds,
        wrongAnswers,
        userBracketPosition,
        spectatorMode,
        noTimeLimit,
        championId,
        runnerUpId,
        startedAt,
        completedAt,
      ];
}
