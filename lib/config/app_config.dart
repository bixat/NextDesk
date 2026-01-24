/// Application configuration
///
/// Store your API keys and configuration here.
/// For production, use environment variables or secure storage.
class AppConfig {
  /// OpenRouter API Key
  /// Get your API key from: https://openrouter.ai/keys
  static const String openRouterApiKey =
      String.fromEnvironment("OPENROUTER_API_KEY");

  /// Maximum iterations for ReAct agent
  static const int maxIterations = 20;

  /// Screenshot quality (0.0 to 1.0)
  static const double screenshotQuality = 0.8;

  /// Default wait time in seconds
  static const int defaultWaitSeconds = 2;
}
