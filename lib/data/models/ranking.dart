import 'package:equatable/equatable.dart';

class Ranking extends Equatable {
  final String projectId;
  final String participantId;
  final String participantName;
  final String country;
  final int points;
  final int championships;
  final int runnerUps;
  final bool isUser;

  const Ranking({
    required this.projectId,
    required this.participantId,
    required this.participantName,
    required this.country,
    this.points = 0,
    this.championships = 0,
    this.runnerUps = 0,
    required this.isUser,
  });

  Ranking copyWith({
    String? projectId,
    String? participantId,
    String? participantName,
    String? country,
    int? points,
    int? championships,
    int? runnerUps,
    bool? isUser,
  }) {
    return Ranking(
      projectId: projectId ?? this.projectId,
      participantId: participantId ?? this.participantId,
      participantName: participantName ?? this.participantName,
      country: country ?? this.country,
      points: points ?? this.points,
      championships: championships ?? this.championships,
      runnerUps: runnerUps ?? this.runnerUps,
      isUser: isUser ?? this.isUser,
    );
  }

  /// Add championship points (3 points)
  Ranking addChampionship() {
    return copyWith(
      points: points + 3,
      championships: championships + 1,
    );
  }

  /// Add runner-up points (1 point)
  Ranking addRunnerUp() {
    return copyWith(
      points: points + 1,
      runnerUps: runnerUps + 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'participantId': participantId,
      'participantName': participantName,
      'country': country,
      'points': points,
      'championships': championships,
      'runnerUps': runnerUps,
      'isUser': isUser ? 1 : 0,
    };
  }

  factory Ranking.fromJson(Map<String, dynamic> json) {
    return Ranking(
      projectId: json['projectId'] as String,
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      country: json['country'] as String,
      points: json['points'] as int,
      championships: json['championships'] as int,
      runnerUps: json['runnerUps'] as int,
      isUser: json['isUser'] == 1,
    );
  }

  @override
  List<Object?> get props => [
        projectId,
        participantId,
        participantName,
        country,
        points,
        championships,
        runnerUps,
        isUser,
      ];
}
