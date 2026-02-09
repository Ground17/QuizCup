import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/project.dart';
import '../../data/models/question.dart';
import '../../data/datasources/local/database_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(() {
  return ProjectsNotifier();
});

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    return _fetchProjects();
  }

  Future<List<Project>> _fetchProjects() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getProjects();
  }

  Future<void> addProject(Project project) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertProject(project);
    if (project.questions.isNotEmpty) {
      await db.insertQuestions(project.questions);
    }
    state = AsyncData(await _fetchProjects());
  }

  Future<void> updateProject(Project project) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateProject(project);
    state = AsyncData(await _fetchProjects());
  }

  Future<void> deleteProject(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteQuestionsByProject(id);
    await db.deleteRankings(id);
    await db.deleteProject(id);
    state = AsyncData(await _fetchProjects());
  }

  Future<void> addQuestionsToProject(String projectId, List<Question> questions) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertQuestions(questions);
    state = AsyncData(await _fetchProjects());
    ref.invalidate(projectProvider(projectId));
  }

  Future<void> updateQuestion(String projectId, Question question) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateQuestion(question);
    state = AsyncData(await _fetchProjects());
    ref.invalidate(projectProvider(projectId));
  }

  Future<void> deleteQuestion(String projectId, String questionId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteQuestion(questionId);
    // Also remove from usedQuestionIds if present
    final project = await db.getProject(projectId);
    if (project != null && project.usedQuestionIds.contains(questionId)) {
      final updatedUsedIds = {...project.usedQuestionIds}..remove(questionId);
      await db.updateProject(project.copyWith(usedQuestionIds: updatedUsedIds));
    }
    state = AsyncData(await _fetchProjects());
    ref.invalidate(projectProvider(projectId));
  }

  Future<void> markQuestionsAsUsed(String projectId, List<String> questionIds) async {
    final db = ref.read(databaseServiceProvider);
    final project = await db.getProject(projectId);
    if (project != null) {
      final updatedUsedIds = {...project.usedQuestionIds, ...questionIds};
      final updatedProject = project.copyWith(usedQuestionIds: updatedUsedIds);
      await db.updateProject(updatedProject);
      state = AsyncData(await _fetchProjects());
    }
  }

  Future<void> resetUsedQuestions(String projectId) async {
    final db = ref.read(databaseServiceProvider);
    final project = await db.getProject(projectId);
    if (project != null) {
      final updatedProject = project.copyWith(usedQuestionIds: {});
      await db.updateProject(updatedProject);
      state = AsyncData(await _fetchProjects());
    }
  }
}

final projectProvider =
    FutureProvider.family<Project?, String>((ref, projectId) async {
  final db = ref.read(databaseServiceProvider);
  return await db.getProject(projectId);
});
