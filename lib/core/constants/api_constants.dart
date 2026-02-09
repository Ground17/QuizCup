class ApiConstants {
  ApiConstants._();

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-3-flash-preview';

  static String generateContentEndpoint(String apiKey) =>
      '$geminiBaseUrl/models/$geminiModel:generateContent?key=$apiKey';
}
