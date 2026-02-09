class StringUtils {
  StringUtils._();

  /// Truncate string to max length with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Convert to title case
  static String toTitleCase(String text) {
    return text.split(' ').map(capitalize).join(' ');
  }

  /// Generate character hint for fill-in-blank (e.g., "_ _ _ _" for 4 chars)
  static String generateCharacterHint(String answer) {
    return answer.split('').map((c) => c == ' ' ? '  ' : '_').join(' ');
  }

  /// Get character count description
  static String getCharacterCountHint(String answer) {
    final length = answer.replaceAll(' ', '').length;
    final spaces = answer.split(' ').length - 1;
    if (spaces > 0) {
      return '$length characters (including $spaces spaces)';
    }
    return '$length characters';
  }

  /// Normalize answer for comparison (lowercase, trim, remove extra spaces)
  static String normalizeAnswer(String answer) {
    return answer.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if two answers match (case-insensitive, whitespace-normalized)
  static bool answersMatch(String userAnswer, String correctAnswer) {
    return normalizeAnswer(userAnswer) == normalizeAnswer(correctAnswer);
  }
}
