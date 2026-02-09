import 'package:equatable/equatable.dart';

enum QuestionType { multipleChoice, fillBlank }

class Question extends Equatable {
  final String id;
  final String projectId;
  final String questionText;
  final String correctAnswer;
  final QuestionType type;
  final DateTime createdAt;

  const Question({
    required this.id,
    required this.projectId,
    required this.questionText,
    required this.correctAnswer,
    this.type = QuestionType.multipleChoice,
    required this.createdAt,
  });

  /// Get character count for fill-in-blank hint
  int get characterCount => correctAnswer.replaceAll(' ', '').length;

  /// Get space count for hint
  int get spaceCount => correctAnswer.split(' ').length - 1;

  Question copyWith({
    String? id,
    String? projectId,
    String? questionText,
    String? correctAnswer,
    QuestionType? type,
    DateTime? createdAt,
  }) {
    return Question(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      questionText: questionText ?? this.questionText,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'questionText': questionText,
      'correctAnswer': correctAnswer,
      'type': type.index,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      questionText: json['questionText'] as String,
      correctAnswer: json['correctAnswer'] as String,
      type: QuestionType.values[json['type'] as int],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, projectId, questionText, correctAnswer, type, createdAt];
}
