class AppConstants {
  AppConstants._();

  static const String appName = 'Qrophy';
  static const String appVersion = '1.0.0';

  // Tournament
  static const int totalParticipants = 1024;
  static const int aiParticipants = 1023;
  static const int questionsPerMatch = 3;
  static const int multipleChoiceOptions = 5;

  // Points
  static const int championPoints = 3;
  static const int runnerUpPoints = 1;

  // Tournament Rounds
  static const List<String> roundNames = [
    'Round of 1024',
    'Round of 512',
    'Round of 256',
    'Round of 128',
    'Round of 64',
    'Round of 32',
    'Round of 16',
    'Quarterfinals',
    'Semifinals',
    'Finals',
  ];

  // Semi-finals and Finals are subjective (fill-in-blank)
  static const int semiFinalsRound = 8; // Semifinals (4 remaining)
  static const int finalsRound = 9; // Finals (2 remaining)
}
