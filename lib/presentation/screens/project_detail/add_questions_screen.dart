import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../providers/project_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../../data/models/question.dart';
import '../../../core/theme/app_colors.dart';

class AddQuestionsScreen extends ConsumerStatefulWidget {
  final String projectId;

  const AddQuestionsScreen({super.key, required this.projectId});

  @override
  ConsumerState<AddQuestionsScreen> createState() => _AddQuestionsScreenState();
}

class _AddQuestionsScreenState extends ConsumerState<AddQuestionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // AI generation
  final _promptController = TextEditingController();
  final _urlController = TextEditingController();
  List<PlatformFile> _selectedFiles = [];
  final List<String> _urls = [];
  bool _isGenerating = false;
  String? _errorMessage;

  // Manual entry
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _urlController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() => _selectedFiles = result.files);
    }
  }

  void _addUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _errorMessage = 'URL must start with http:// or https://');
      return;
    }

    setState(() {
      _urls.add(url);
      _urlController.clear();
      _errorMessage = null;
    });
  }

  bool get _hasAnySource {
    return _selectedFiles.isNotEmpty ||
        _urls.isNotEmpty ||
        _promptController.text.trim().isNotEmpty;
  }

  Future<void> _generateQuestions() async {
    if (!_hasAnySource) {
      setState(
          () => _errorMessage = 'Please provide at least one source: files, URLs, or a prompt');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final questions =
          await ref.read(geminiServiceProvider).generateAdditionalQuestions(
                projectId: widget.projectId,
                files: _selectedFiles,
                urls: _urls,
                customPrompt: _promptController.text.trim(),
              );

      await ref
          .read(projectsProvider.notifier)
          .addQuestionsToProject(widget.projectId, questions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${questions.length} questions added!')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Generation failed: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _addManualQuestion() async {
    final questionText = _questionController.text.trim();
    final answerText = _answerController.text.trim();

    if (questionText.isEmpty || answerText.isEmpty) {
      setState(() => _errorMessage = 'Both question and answer are required');
      return;
    }

    final question = Question(
      id: _uuid.v4(),
      projectId: widget.projectId,
      questionText: questionText,
      correctAnswer: answerText,
      createdAt: DateTime.now(),
    );

    await ref
        .read(projectsProvider.notifier)
        .addQuestionsToProject(widget.projectId, [question]);

    if (mounted) {
      _questionController.clear();
      _answerController.clear();
      setState(() => _errorMessage = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question added!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Questions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'AI Generate'),
            Tab(icon: Icon(Icons.edit), text: 'Manual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAIGenerateTab(),
          _buildManualTab(),
        ],
      ),
    );
  }

  Widget _buildAIGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Files Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file),
                      const SizedBox(width: 8),
                      Text('Files',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedFiles.isEmpty)
                    OutlinedButton.icon(
                      onPressed: _isGenerating ? null : _pickFiles,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select Files'),
                    )
                  else
                    Column(
                      children: [
                        ..._selectedFiles.map((file) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.description),
                              title: Text(file.name),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _isGenerating
                                    ? null
                                    : () => setState(
                                        () => _selectedFiles.remove(file)),
                              ),
                            )),
                        OutlinedButton.icon(
                          onPressed: _isGenerating ? null : _pickFiles,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Files'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // URLs Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link),
                      const SizedBox(width: 8),
                      Text('Website Links',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_urls.isNotEmpty)
                    ..._urls.asMap().entries.map((entry) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.language),
                        title: Text(entry.value,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _isGenerating
                              ? null
                              : () =>
                                  setState(() => _urls.removeAt(entry.key)),
                        ),
                      );
                    }),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            hintText: 'https://example.com',
                            isDense: true,
                          ),
                          enabled: !_isGenerating,
                          onSubmitted: (_) => _addUrl(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isGenerating ? null : _addUrl,
                        icon: const Icon(Icons.add_circle),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Prompt Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note),
                      const SizedBox(width: 8),
                      Text('Prompt / Instructions',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g., Generate 20 questions about photosynthesis',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !_isGenerating,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateQuestions,
            child: _isGenerating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Generating...'),
                    ],
                  )
                : const Text('Generate Questions'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: 'Question',
              hintText: 'Enter the question text',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _answerController,
            decoration: const InputDecoration(
              labelText: 'Answer',
              hintText: 'Enter the correct answer (1-5 words)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null && _tabController.index == 1) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: _addManualQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Add Question'),
          ),
        ],
      ),
    );
  }
}
