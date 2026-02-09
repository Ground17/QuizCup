import 'dart:math';

class RandomUtils {
  static final Random _random = Random();

  /// Generate a random double between min and max (inclusive)
  static double randomDouble(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  /// Generate a random integer between min and max (inclusive)
  static int randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  /// Generate a random boolean with given probability of true
  static bool randomBool([double probabilityOfTrue = 0.5]) {
    return _random.nextDouble() < probabilityOfTrue;
  }

  /// Pick a random element from a list
  static T randomElement<T>(List<T> list) {
    if (list.isEmpty) throw ArgumentError('List cannot be empty');
    return list[_random.nextInt(list.length)];
  }

  /// Pick n random elements from a list (without replacement)
  static List<T> randomElements<T>(List<T> list, int n) {
    if (n > list.length) {
      throw ArgumentError('n cannot be greater than list length');
    }
    final shuffled = List<T>.from(list)..shuffle(_random);
    return shuffled.take(n).toList();
  }

  /// Generate a normal distribution value (Box-Muller transform)
  static double normalDistribution(double mean, double stdDev) {
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    final z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    return mean + z0 * stdDev;
  }

  /// Clamp a value between min and max
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
