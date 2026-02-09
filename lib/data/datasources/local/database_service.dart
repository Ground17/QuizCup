import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/project.dart';
import '../../models/question.dart';
import '../../models/ai_persona.dart';
import '../../models/user_profile.dart';
import '../../models/tournament.dart';
import '../../models/ranking.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'quizcup.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Projects table
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        usedQuestionIds TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    // Questions table
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        questionText TEXT NOT NULL,
        correctAnswer TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (projectId) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    // AI Personas table
    await db.execute('''
      CREATE TABLE ai_personas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        country TEXT NOT NULL,
        winRate REAL NOT NULL,
        speedMultiplier REAL NOT NULL,
        isCustomized INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // User profile table
    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        country TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Tournaments table
    await db.execute('''
      CREATE TABLE tournaments (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        data TEXT NOT NULL,
        FOREIGN KEY (projectId) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    // Rankings table
    await db.execute('''
      CREATE TABLE rankings (
        projectId TEXT NOT NULL,
        participantId TEXT NOT NULL,
        participantName TEXT NOT NULL,
        country TEXT NOT NULL,
        points INTEGER NOT NULL DEFAULT 0,
        championships INTEGER NOT NULL DEFAULT 0,
        runnerUps INTEGER NOT NULL DEFAULT 0,
        isUser INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (projectId, participantId)
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_questions_projectId ON questions(projectId)');
    await db.execute('CREATE INDEX idx_rankings_projectId ON rankings(projectId)');
    await db.execute('CREATE INDEX idx_rankings_points ON rankings(points DESC)');
  }

  // ==================== Projects ====================

  Future<List<Project>> getProjects() async {
    final db = await database;
    final results = await db.query('projects', orderBy: 'createdAt DESC');

    final projects = <Project>[];
    for (final row in results) {
      final questions = await getQuestionsByProject(row['id'] as String);
      projects.add(Project.fromJson({
        ...row,
        'usedQuestionIds': jsonDecode(row['usedQuestionIds'] as String),
      }, questions: questions));
    }
    return projects;
  }

  Future<Project?> getProject(String id) async {
    final db = await database;
    final results = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;

    final row = results.first;
    final questions = await getQuestionsByProject(id);
    return Project.fromJson({
      ...row,
      'usedQuestionIds': jsonDecode(row['usedQuestionIds'] as String),
    }, questions: questions);
  }

  Future<void> insertProject(Project project) async {
    final db = await database;
    await db.insert('projects', {
      ...project.toJson(),
      'usedQuestionIds': jsonEncode(project.usedQuestionIds.toList()),
    });
  }

  Future<void> updateProject(Project project) async {
    final db = await database;
    await db.update(
      'projects',
      {
        ...project.toJson(),
        'usedQuestionIds': jsonEncode(project.usedQuestionIds.toList()),
      },
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Questions ====================

  Future<List<Question>> getQuestionsByProject(String projectId) async {
    final db = await database;
    final results = await db.query(
      'questions',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'createdAt ASC',
    );
    return results.map((row) => Question.fromJson(row)).toList();
  }

  Future<void> insertQuestions(List<Question> questions) async {
    final db = await database;
    final batch = db.batch();
    for (final question in questions) {
      batch.insert('questions', question.toJson());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateQuestion(Question question) async {
    final db = await database;
    await db.update(
      'questions',
      question.toJson(),
      where: 'id = ?',
      whereArgs: [question.id],
    );
  }

  Future<void> deleteQuestion(String questionId) async {
    final db = await database;
    await db.delete('questions', where: 'id = ?', whereArgs: [questionId]);
  }

  Future<void> deleteQuestionsByProject(String projectId) async {
    final db = await database;
    await db.delete('questions', where: 'projectId = ?', whereArgs: [projectId]);
  }

  // ==================== AI Personas ====================

  Future<List<AIPersona>> getAIPersonas() async {
    final db = await database;
    final results = await db.query('ai_personas', orderBy: 'name ASC');
    return results.map((row) => AIPersona.fromJson(row)).toList();
  }

  Future<AIPersona?> getAIPersona(String id) async {
    final db = await database;
    final results = await db.query('ai_personas', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return AIPersona.fromJson(results.first);
  }

  Future<void> insertAIPersonas(List<AIPersona> personas) async {
    final db = await database;
    final batch = db.batch();
    for (final persona in personas) {
      batch.insert('ai_personas', persona.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateAIPersona(AIPersona persona) async {
    final db = await database;
    await db.update(
      'ai_personas',
      persona.toJson(),
      where: 'id = ?',
      whereArgs: [persona.id],
    );
  }

  Future<void> deleteAllAIPersonas() async {
    final db = await database;
    await db.delete('ai_personas');
  }

  Future<int> getAIPersonaCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ai_personas');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== User Profile ====================

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final results = await db.query('user_profile');
    if (results.isEmpty) return null;
    return UserProfile.fromJson(results.first);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== Tournaments ====================

  Future<Tournament?> getTournament(String id) async {
    final db = await database;
    final results = await db.query('tournaments', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Tournament.fromJson(jsonDecode(results.first['data'] as String));
  }

  Future<Tournament?> getActiveTournament(String projectId) async {
    final db = await database;
    final results = await db.query(
      'tournaments',
      where: 'projectId = ?',
      whereArgs: [projectId],
    );

    for (final row in results) {
      final tournament = Tournament.fromJson(jsonDecode(row['data'] as String));
      if (tournament.status != TournamentStatus.completed) {
        return tournament;
      }
    }
    return null;
  }

  Future<void> saveTournament(Tournament tournament) async {
    final db = await database;
    await db.insert(
      'tournaments',
      {
        'id': tournament.id,
        'projectId': tournament.projectId,
        'data': jsonEncode(tournament.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTournament(String id) async {
    final db = await database;
    await db.delete('tournaments', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Rankings ====================

  Future<List<Ranking>> getRankings(String projectId) async {
    final db = await database;
    final results = await db.query(
      'rankings',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'points DESC, championships DESC',
    );
    return results.map((row) => Ranking.fromJson(row)).toList();
  }

  Future<void> saveRanking(Ranking ranking) async {
    final db = await database;
    await db.insert(
      'rankings',
      ranking.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveRankings(List<Ranking> rankings) async {
    final db = await database;
    final batch = db.batch();
    for (final ranking in rankings) {
      batch.insert('rankings', ranking.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteRankings(String projectId) async {
    final db = await database;
    await db.delete('rankings', where: 'projectId = ?', whereArgs: [projectId]);
  }

  // ==================== Utilities ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
