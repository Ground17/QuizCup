import 'package:equatable/equatable.dart';

class AIPersona extends Equatable {
  final String id;
  final String name;
  final String country; // ISO country code
  final double winRate; // 0.0 to 1.0
  final double speedMultiplier; // 0.1 to 1.0 (multiplied by question length in seconds)
  final bool isCustomized;

  const AIPersona({
    required this.id,
    required this.name,
    required this.country,
    required this.winRate,
    required this.speedMultiplier,
    this.isCustomized = false,
  });

  /// Calculate answer time based on question length
  /// Returns duration in milliseconds
  Duration calculateAnswerTime(int questionLength) {
    return Duration(
      milliseconds: (questionLength * speedMultiplier * 100).toInt(),
    );
  }

  /// Get win rate as percentage string
  String get winRatePercentage => '${(winRate * 100).toStringAsFixed(0)}%';

  /// Get speed description
  String get speedDescription {
    if (speedMultiplier < 0.3) return 'Very Fast';
    if (speedMultiplier < 0.5) return 'Fast';
    if (speedMultiplier < 0.7) return 'Normal';
    if (speedMultiplier < 0.9) return 'Slow';
    return 'Very Slow';
  }

  AIPersona copyWith({
    String? id,
    String? name,
    String? country,
    double? winRate,
    double? speedMultiplier,
    bool? isCustomized,
  }) {
    return AIPersona(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      winRate: winRate ?? this.winRate,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      isCustomized: isCustomized ?? this.isCustomized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'winRate': winRate,
      'speedMultiplier': speedMultiplier,
      'isCustomized': isCustomized ? 1 : 0,
    };
  }

  factory AIPersona.fromJson(Map<String, dynamic> json) {
    return AIPersona(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      winRate: (json['winRate'] as num).toDouble(),
      speedMultiplier: (json['speedMultiplier'] as num).toDouble(),
      isCustomized: json['isCustomized'] == 1,
    );
  }

  @override
  List<Object?> get props => [id, name, country, winRate, speedMultiplier, isCustomized];
}
