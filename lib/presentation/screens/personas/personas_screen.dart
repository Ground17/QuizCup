import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/persona_provider.dart';
import '../../../data/models/ai_persona.dart';
import '../../../core/theme/app_colors.dart';

class PersonasScreen extends ConsumerStatefulWidget {
  const PersonasScreen({super.key});

  @override
  ConsumerState<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends ConsumerState<PersonasScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personasAsync = ref.watch(personasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Participants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _showResetDialog(context, ref),
            tooltip: 'Reset AI',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: personasAsync.when(
              data: (personas) {
                final filtered = _searchQuery.isEmpty
                    ? personas
                    : personas
                        .where((p) => p.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No AI participants'
                              : 'No results found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final persona = filtered[index];
                    return _PersonaCard(
                      persona: persona,
                      onEdit: () => _showEditDialog(context, ref, persona),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, AIPersona persona) {
    final nameController = TextEditingController(text: persona.name);
    double winRate = persona.winRate;
    double speedMultiplier = persona.speedMultiplier;
    String country = persona.country;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit AI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Win Rate: '),
                    Expanded(
                      child: Slider(
                        value: winRate,
                        min: 0,
                        max: 1,
                        divisions: 100,
                        label: '${(winRate * 100).toStringAsFixed(0)}%',
                        onChanged: (value) =>
                            setDialogState(() => winRate = value),
                      ),
                    ),
                    Text('${(winRate * 100).toStringAsFixed(0)}%'),
                  ],
                ),
                Row(
                  children: [
                    const Text('Speed: '),
                    Expanded(
                      child: Slider(
                        value: speedMultiplier,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: speedMultiplier.toStringAsFixed(1),
                        onChanged: (value) =>
                            setDialogState(() => speedMultiplier = value),
                      ),
                    ),
                    Text(speedMultiplier < 0.3
                        ? 'Fast'
                        : speedMultiplier > 0.7
                            ? 'Slow'
                            : 'Normal'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = persona.copyWith(
                  name: nameController.text,
                  winRate: winRate,
                  speedMultiplier: speedMultiplier,
                  country: country,
                  isCustomized: true,
                );
                ref.read(personasProvider.notifier).updatePersona(updated);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset AI'),
        content: const Text('Regenerate all AI participants?\nCustomizations will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(personasProvider.notifier).regenerateAll();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final AIPersona persona;
  final VoidCallback onEdit;

  const _PersonaCard({required this.persona, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: persona.isCustomized
              ? AppColors.secondary
              : AppColors.primary,
          child: Text(
            persona.country,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(persona.name)),
            if (persona.isCustomized)
              const Icon(Icons.edit, size: 16, color: AppColors.secondary),
          ],
        ),
        subtitle: Text(
          'Win Rate: ${persona.winRatePercentage} · ${persona.speedDescription}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
