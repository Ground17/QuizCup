import 'package:equatable/equatable.dart';

/// Represents a single question's result in a match
class MatchQuestionResult extends Equatable {
  final String questionId;
  final String? userAnswer;
  final Duration? userAnswerTime;
  final String? aiAnswer;
  final Duration? aiAnswerTime;
  final bool userCorrect;
  final bool aiCorrect;

  const MatchQuestionResult({
    required this.questionId,
    this.userAnswer,
    this.userAnswerTime,
    this.aiAnswer,
    this.aiAnswerTime,
    required this.userCorrect,
    required this.aiCorrect,
  });

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'userAnswer': userAnswer,
      'userAnswerTime': userAnswerTime?.inMilliseconds,
      'aiAnswer': aiAnswer,
      'aiAnswerTime': aiAnswerTime?.inMilliseconds,
      'userCorrect': userCorrect ? 1 : 0,
      'aiCorrect': aiCorrect ? 1 : 0,
    };
  }

  factory MatchQuestionResult.fromJson(Map<String, dynamic> json) {
    return MatchQuestionResult(
      questionId: json['questionId'] as String,
      userAnswer: json['userAnswer'] as String?,
      userAnswerTime: json['userAnswerTime'] != null
          ? Duration(milliseconds: json['userAnswerTime'] as int)
          : null,
      aiAnswer: json['aiAnswer'] as String?,
      aiAnswerTime: json['aiAnswerTime'] != null
          ? Duration(milliseconds: json['aiAnswerTime'] as int)
          : null,
      userCorrect: json['userCorrect'] == 1,
      aiCorrect: json['aiCorrect'] == 1,
    );
  }

  @override
  List<Object?> get props => [
        questionId,
        userAnswer,
        userAnswerTime,
        aiAnswer,
        aiAnswerTime,
        userCorrect,
        aiCorrect,
      ];
}

/// Represents the result of a match between two participants
class MatchResult extends Equatable {
  final String matchId;
  final String participant1Id;
  final String participant2Id;
  final String winnerId;
  final int participant1Score;
  final int participant2Score;
  final String participant1Name;
  final String participant2Name;
  final List<MatchQuestionResult> questionResults;
  final bool isUserMatch;

  const MatchResult({
    required this.matchId,
    required this.participant1Id,
    required this.participant2Id,
    required this.winnerId,
    required this.participant1Score,
    required this.participant2Score,
    this.participant1Name = '',
    this.participant2Name = '',
    this.questionResults = const [],
    required this.isUserMatch,
  });

  bool get isUserWinner => isUserMatch && winnerId == participant1Id;

  String get winnerName =>
      winnerId == participant1Id ? participant1Name : participant2Name;

  String get loserName =>
      winnerId == participant1Id ? participant2Name : participant1Name;

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'participant1Id': participant1Id,
      'participant2Id': participant2Id,
      'winnerId': winnerId,
      'participant1Score': participant1Score,
      'participant2Score': participant2Score,
      'participant1Name': participant1Name,
      'participant2Name': participant2Name,
      'questionResults': questionResults.map((e) => e.toJson()).toList(),
      'isUserMatch': isUserMatch ? 1 : 0,
    };
  }

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      matchId: json['matchId'] as String,
      participant1Id: json['participant1Id'] as String,
      participant2Id: json['participant2Id'] as String,
      winnerId: json['winnerId'] as String,
      participant1Score: json['participant1Score'] as int,
      participant2Score: json['participant2Score'] as int,
      participant1Name: json['participant1Name'] as String? ?? '',
      participant2Name: json['participant2Name'] as String? ?? '',
      questionResults: (json['questionResults'] as List<dynamic>?)
              ?.map((e) => MatchQuestionResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isUserMatch: json['isUserMatch'] == 1,
    );
  }

  @override
  List<Object?> get props => [
        matchId,
        participant1Id,
        participant2Id,
        winnerId,
        participant1Score,
        participant2Score,
        participant1Name,
        participant2Name,
        questionResults,
        isUserMatch,
      ];
}
