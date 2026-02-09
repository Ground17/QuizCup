import 'package:equatable/equatable.dart';
import 'question.dart';

class Project extends Equatable {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Question> questions;
  final Set<String> usedQuestionIds;

  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    this.questions = const [],
    this.usedQuestionIds = const {},
  });

  /// Check if all questions have been used (can reset rankings)
  bool get canResetRankings =>
      questions.isNotEmpty && usedQuestionIds.length >= questions.length;

  /// Get unused questions
  List<Question> get unusedQuestions =>
      questions.where((q) => !usedQuestionIds.contains(q.id)).toList();

  /// Get progress percentage
  double get usageProgress =>
      questions.isEmpty ? 0 : usedQuestionIds.length / questions.length;

  /// Get question count
  int get questionCount => questions.length;

  /// Get used question count
  int get usedQuestionCount => usedQuestionIds.length;

  Project copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<Question>? questions,
    Set<String>? usedQuestionIds,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      questions: questions ?? this.questions,
      usedQuestionIds: usedQuestionIds ?? this.usedQuestionIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'usedQuestionIds': usedQuestionIds.toList(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json, {List<Question>? questions}) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      questions: questions ?? [],
      usedQuestionIds: (json['usedQuestionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, questions, usedQuestionIds];
}
