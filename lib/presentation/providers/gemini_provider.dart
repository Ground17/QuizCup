import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/project.dart';
import '../../data/models/question.dart';
import '../../core/constants/api_constants.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

class GeminiService {
  final Dio _dio = Dio();
  static const uuid = Uuid();

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<Project> generateQuiz({
    required String projectName,
    List<PlatformFile> files = const [],
    List<String> urls = const [],
    String? customPrompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key is not set. Please check your .env file.');
    }

    // Gather content from all sources
    final contentParts = <String>[];

    // Read file contents
    if (files.isNotEmpty) {
      final fileContents = await _readFiles(files);
      if (fileContents.isNotEmpty) {
        contentParts.add('--- Files ---\n$fileContents');
      }
    }

    // Fetch URL contents
    if (urls.isNotEmpty) {
      final urlContents = await _fetchUrls(urls);
      if (urlContents.isNotEmpty) {
        contentParts.add('--- Web Pages ---\n$urlContents');
      }
    }

    final allContent = contentParts.join('\n\n');

    // Build prompt
    final prompt = _buildPrompt(allContent, customPrompt);

    // Call Gemini API
    final questions = await _callGeminiAPI(prompt);

    // Create project
    final projectId = uuid.v4();
    final now = DateTime.now();

    final questionObjects = questions.map((q) {
      return Question(
        id: uuid.v4(),
        projectId: projectId,
        questionText: q['question'] as String,
        correctAnswer: q['answer'] as String,
        createdAt: now,
      );
    }).toList();

    return Project(
      id: projectId,
      name: projectName,
      createdAt: now,
      questions: questionObjects,
    );
  }

  /// Generate additional questions for an existing project
  Future<List<Question>> generateAdditionalQuestions({
    required String projectId,
    List<PlatformFile> files = const [],
    List<String> urls = const [],
    String? customPrompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key is not set. Please check your .env file.');
    }

    final contentParts = <String>[];

    if (files.isNotEmpty) {
      final fileContents = await _readFiles(files);
      if (fileContents.isNotEmpty) {
        contentParts.add('--- Files ---\n$fileContents');
      }
    }

    if (urls.isNotEmpty) {
      final urlContents = await _fetchUrls(urls);
      if (urlContents.isNotEmpty) {
        contentParts.add('--- Web Pages ---\n$urlContents');
      }
    }

    final allContent = contentParts.join('\n\n');
    final prompt = _buildPrompt(allContent, customPrompt);
    final questions = await _callGeminiAPI(prompt);

    final now = DateTime.now();
    return questions.map((q) {
      return Question(
        id: uuid.v4(),
        projectId: projectId,
        questionText: q['question'] as String,
        correctAnswer: q['answer'] as String,
        createdAt: now,
      );
    }).toList();
  }

  Future<String> _readFiles(List<PlatformFile> files) async {
    final contents = <String>[];

    for (final file in files) {
      if (file.path != null) {
        final fileObj = File(file.path!);
        try {
          final content = await fileObj.readAsString();
          contents.add('--- ${file.name} ---\n$content\n');
        } catch (e) {
          // If can't read as string, skip
          contents.add('--- ${file.name} ---\n[Unable to read file]\n');
        }
      }
    }

    return contents.join('\n');
  }

  Future<String> _fetchUrls(List<String> urls) async {
    final contents = <String>[];

    for (final url in urls) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'User-Agent': 'Qrophy/1.0',
            },
          ),
        );
        final body = response.data?.toString() ?? '';
        // Strip HTML tags for a rough text extraction
        final text = _stripHtml(body);
        if (text.isNotEmpty) {
          contents.add('--- $url ---\n$text\n');
        }
      } catch (e) {
        contents.add('--- $url ---\n[Failed to fetch: $e]\n');
      }
    }

    return contents.join('\n');
  }

  String _stripHtml(String html) {
    // Remove script and style blocks
    var text = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // Decode common HTML entities
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&nbsp;', ' ');
    // Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Limit length to avoid exceeding API limits
    if (text.length > 30000) {
      text = text.substring(0, 30000);
    }
    return text;
  }

  String _buildPrompt(String content, String? customPrompt) {
    final hasContent = content.trim().isNotEmpty;
    final hasPrompt = customPrompt != null && customPrompt.isNotEmpty;

    if (hasContent && hasPrompt) {
      return '''
Based on the following content, generate as many quiz questions as possible.

Content:
$content

Additional requirements:
$customPrompt

Rules:
1. Generate as many questions as possible (at least 20 recommended)
2. Keep answers concise, 1-5 words
3. Cover all major topics from the content
4. Mix difficulty levels
5. Answers must be clear and unambiguous

Respond ONLY in the following JSON format (no other text):
[
  {"question": "Question text", "answer": "Answer"},
  {"question": "Question text", "answer": "Answer"}
]
''';
    } else if (hasContent) {
      return '''
Based on the following content, generate as many quiz questions as possible.

Content:
$content

Rules:
1. Generate as many questions as possible (at least 20 recommended)
2. Keep answers concise, 1-5 words
3. Cover all major topics from the content
4. Mix difficulty levels
5. Answers must be clear and unambiguous

Respond ONLY in the following JSON format (no other text):
[
  {"question": "Question text", "answer": "Answer"},
  {"question": "Question text", "answer": "Answer"}
]
''';
    } else {
      // Prompt only
      return '''
Generate as many quiz questions as possible based on the following topic/instructions:

$customPrompt

Rules:
1. Generate as many questions as possible (at least 20 recommended)
2. Keep answers concise, 1-5 words
3. Cover the topic thoroughly
4. Mix difficulty levels
5. Answers must be clear and unambiguous

Respond ONLY in the following JSON format (no other text):
[
  {"question": "Question text", "answer": "Answer"},
  {"question": "Question text", "answer": "Answer"}
]
''';
    }
  }

  Future<List<Map<String, dynamic>>> _callGeminiAPI(String prompt) async {
    try {
      final response = await _dio.post(
        ApiConstants.generateContentEndpoint(_apiKey),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 8192,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Parse JSON from response
        return _parseQuizResponse(text);
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('API error: ${e.response?.data}');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  /// Analyze user's wrong answers and provide weakness insights
  Future<String> analyzeWeaknesses(List<Map<String, String>> wrongAnswers) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key is not set. Please check your .env file.');
    }

    final wrongAnswerText = wrongAnswers.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final wa = entry.value;
      return '$i. Question: ${wa['question']}\n   Correct Answer: ${wa['correct']}\n   User Answer: ${wa['user']}';
    }).join('\n\n');

    final prompt = '''
Analyze the following wrong answers from a quiz and provide a weakness analysis.

Wrong Answers:
$wrongAnswerText

Please provide:
1. A summary of the main weak areas (what topics/patterns the user struggles with)
2. Specific advice for improvement
3. Common mistake patterns you notice

Keep the response concise (under 300 words). Use bullet points for clarity.
Respond in the same language as the quiz questions.
''';

    try {
      final response = await _dio.post(
        ApiConstants.generateContentEndpoint(_apiKey),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.5,
            'maxOutputTokens': 2048,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('API error: ${e.response?.data}');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  /// AI Challenge: check if user's answer is semantically equivalent to the correct answer
  /// Returns true only if the meaning matches. Strict on spelling.
  Future<bool> challengeAnswer({
    required String question,
    required String correctAnswer,
    required String userAnswer,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key is not set. Please check your .env file.');
    }

    final prompt = '''
You are a strict quiz answer judge. Determine if the user's answer is semantically equivalent to the correct answer for the given question.

Question: $question
Correct Answer: $correctAnswer
User's Answer: $userAnswer

Rules:
1. The user's answer must be semantically equivalent to the correct answer (e.g., "초록" and "초록색" are equivalent, "green" and "green color" are equivalent)
2. Spelling must be STRICTLY correct - any typo means the answer is WRONG
3. Minor formatting differences (spacing, punctuation) are acceptable
4. The core meaning must match exactly - partial answers or related but different answers are WRONG

Respond with ONLY "ACCEPT" or "REJECT" (one word, nothing else).
''';

    try {
      final response = await _dio.post(
        ApiConstants.generateContentEndpoint(_apiKey),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.0,
            'maxOutputTokens': 10,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final text = (data['candidates'][0]['content']['parts'][0]['text'] as String).trim().toUpperCase();
        return text.contains('ACCEPT');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _parseQuizResponse(String text) {
    // Try to extract JSON from the response
    String jsonStr = text.trim();

    // Remove markdown code blocks if present
    if (jsonStr.startsWith('```json')) {
      jsonStr = jsonStr.substring(7);
    } else if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.substring(3);
    }
    if (jsonStr.endsWith('```')) {
      jsonStr = jsonStr.substring(0, jsonStr.length - 3);
    }
    jsonStr = jsonStr.trim();

    // Find JSON array in the text
    final startIndex = jsonStr.indexOf('[');
    final endIndex = jsonStr.lastIndexOf(']');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      jsonStr = jsonStr.substring(startIndex, endIndex + 1);
    }

    try {
      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed.map((item) {
        return {
          'question': item['question']?.toString() ?? '',
          'answer': item['answer']?.toString() ?? '',
        };
      }).where((item) {
        return item['question']!.isNotEmpty && item['answer']!.isNotEmpty;
      }).toList();
    } catch (e) {
      throw Exception('Quiz parsing failed: $e');
    }
  }
}
