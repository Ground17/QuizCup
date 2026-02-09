import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ai_persona.dart';
import '../../core/utils/random_utils.dart';
import 'project_provider.dart';

final personasProvider =
    AsyncNotifierProvider<PersonasNotifier, List<AIPersona>>(() {
  return PersonasNotifier();
});

class PersonasNotifier extends AsyncNotifier<List<AIPersona>> {
  static const int totalPersonas = 1023;

  @override
  Future<List<AIPersona>> build() async {
    return _fetchOrGeneratePersonas();
  }

  Future<List<AIPersona>> _fetchOrGeneratePersonas() async {
    final db = ref.read(databaseServiceProvider);
    final count = await db.getAIPersonaCount();

    if (count < totalPersonas) {
      // Generate new personas
      final personas = _generatePersonas();
      await db.insertAIPersonas(personas);
      return personas;
    }

    return await db.getAIPersonas();
  }

  List<AIPersona> _generatePersonas() {
    const uuid = Uuid();
    final personas = <AIPersona>[];

    for (int i = 0; i < totalPersonas; i++) {
      personas.add(AIPersona(
        id: uuid.v4(),
        name: _generateName(i),
        country: _getRandomCountry(),
        winRate: _generateWinRate(),
        speedMultiplier: _generateSpeedMultiplier(),
        isCustomized: false,
      ));
    }

    return personas;
  }

  String _generateName(int index) {
    final prefixes = [
      'Quiz', 'Brain', 'Think', 'Smart', 'Genius', 'Mind', 'Logic',
      'Puzzle', 'Wisdom', 'Know', 'Learn', 'Study', 'Master', 'Pro',
      'Super', 'Ultra', 'Mega', 'Hyper', 'Turbo', 'Nitro', 'Cyber',
      'Neo', 'Meta', 'Alpha', 'Beta', 'Omega', 'Delta', 'Sigma',
      'Pixel', 'Byte', 'Code', 'Data', 'Cloud', 'Star', 'Moon',
      'Sun', 'Fire', 'Ice', 'Storm', 'Thunder', 'Lightning', 'Flash',
      'Shadow', 'Night', 'Dark', 'Light', 'Bright', 'Golden', 'Silver',
      'Crystal', 'Diamond', 'Ruby', 'Emerald', 'Sapphire', 'Dragon',
    ];

    final suffixes = [
      'Master', 'King', 'Queen', 'Lord', 'Knight', 'Warrior', 'Hunter',
      'Seeker', 'Finder', 'Solver', 'Breaker', 'Maker', 'Builder',
      'Runner', 'Walker', 'Rider', 'Flyer', 'Hawk', 'Eagle', 'Falcon',
      'Wolf', 'Tiger', 'Lion', 'Bear', 'Fox', 'Phoenix', 'Ninja',
      'Samurai', 'Viking', 'Wizard', 'Mage', 'Sage', 'Monk', 'Titan',
      'Giant', 'Legend', 'Hero', 'Champion', 'Winner', 'Victor',
      'Bot', 'AI', 'X', 'Z', 'Plus', 'Prime', 'Elite', 'Force',
    ];

    final random = Random();
    final prefix = prefixes[random.nextInt(prefixes.length)];
    final suffix = suffixes[random.nextInt(suffixes.length)];
    final number = random.nextInt(1000);

    // Various name patterns
    final patterns = [
      '$prefix$suffix',
      '$prefix$suffix$number',
      '${prefix}_$suffix',
      '$prefix$number$suffix',
      'The$prefix$suffix',
      '${prefix}inator',
      '$prefix${suffix}X',
    ];

    return patterns[random.nextInt(patterns.length)];
  }

  String _getRandomCountry() {
    final countries = [
      'KR', 'US', 'JP', 'CN', 'GB', 'DE', 'FR', 'IT', 'ES', 'BR',
      'CA', 'AU', 'IN', 'RU', 'MX', 'NL', 'SE', 'NO', 'DK', 'FI',
      'PL', 'TR', 'TH', 'VN', 'ID', 'PH', 'MY', 'SG', 'NZ', 'CH',
    ];
    return countries[Random().nextInt(countries.length)];
  }

  double _generateWinRate() {
    // Normal distribution around 0.5 with stddev 0.15
    double rate = RandomUtils.normalDistribution(0.5, 0.15);
    return RandomUtils.clamp(rate, 0.05, 0.95);
  }

  double _generateSpeedMultiplier() {
    // Uniform distribution between 0.1 and 1.0
    return RandomUtils.randomDouble(0.1, 1.0);
  }

  Future<void> updatePersona(AIPersona persona) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateAIPersona(persona);
    state = AsyncData(await db.getAIPersonas());
  }

  Future<void> regenerateAll() async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteAllAIPersonas();
    final personas = _generatePersonas();
    await db.insertAIPersonas(personas);
    state = AsyncData(personas);
  }
}

final personaProvider =
    FutureProvider.family<AIPersona?, String>((ref, personaId) async {
  final db = ref.read(databaseServiceProvider);
  return await db.getAIPersona(personaId);
});
