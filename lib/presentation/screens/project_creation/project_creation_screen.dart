import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/project_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../../core/theme/app_colors.dart';

class ProjectCreationScreen extends ConsumerStatefulWidget {
  const ProjectCreationScreen({super.key});

  @override
  ConsumerState<ProjectCreationScreen> createState() =>
      _ProjectCreationScreenState();
}

class _ProjectCreationScreenState extends ConsumerState<ProjectCreationScreen> {
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();
  final _urlController = TextEditingController();
  List<PlatformFile> _selectedFiles = [];
  final List<String> _urls = [];
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.files;
      });
    }
  }

  void _addUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Basic URL validation
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

  Future<void> _generateQuiz() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a project name');
      return;
    }

    if (!_hasAnySource) {
      setState(() => _errorMessage = 'Please provide at least one source: files, URLs, or a prompt');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final project = await ref.read(geminiServiceProvider).generateQuiz(
            projectName: _nameController.text.trim(),
            files: _selectedFiles,
            urls: _urls,
            customPrompt: _promptController.text.trim(),
          );

      await ref.read(projectsProvider.notifier).addProject(project);

      if (mounted) {
        context.go('/project/${project.id}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Quiz generation failed: $e';
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'e.g., History Quiz',
              ),
              enabled: !_isGenerating,
            ),
            const SizedBox(height: 16),

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
                        Text(
                          'Files',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          'Optional',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
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
                                subtitle: Text(_formatFileSize(file.size)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _isGenerating
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedFiles.remove(file);
                                          });
                                        },
                                ),
                              )),
                          const SizedBox(height: 8),
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
                        Text(
                          'Website Links',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          'Optional',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_urls.isNotEmpty)
                      ..._urls.asMap().entries.map((entry) {
                        final index = entry.key;
                        final url = entry.value;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.language),
                          title: Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _isGenerating
                                ? null
                                : () {
                                    setState(() {
                                      _urls.removeAt(index);
                                    });
                                  },
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
                        Text(
                          'Prompt / Instructions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          'Optional',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _promptController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Generate 30 questions about World War II',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      enabled: !_isGenerating,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Provide at least one: files, URLs, or a prompt.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
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
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateQuiz,
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
                        Text('Generating quiz...'),
                      ],
                    )
                  : const Text('Generate Quiz'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
