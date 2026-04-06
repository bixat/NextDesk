/// Application configuration
///
/// Store your API keys and configuration here.
/// For production, use environment variables or secure storage.
class AppConfig {
  /// OpenRouter API Key
  /// Get your API key from: https://openrouter.ai/keys
  static const String openRouterApiKey =
      String.fromEnvironment("OPENROUTER_API_KEY");

  /// HCompany API Key (for Holo3 model)
  /// Get your API key from: https://hub.hcompany.ai/
  static const String hCompanyApiKey =
      String.fromEnvironment("HCOMPANY_API_KEY");

  /// Vision Model Provider
  /// Options: 'google/gemini-3-pro-preview', 'hcompany/holo3-35b-a3b'
  static const String visionModel = String.fromEnvironment(
    "VISION_MODEL",
    defaultValue: 'hcompany/holo3-35b-a3b',
  );

  /// Chat/Agent Model
  /// Default chat model for automation tasks
  static const String chatModel = String.fromEnvironment(
    "CHAT_MODEL",
    defaultValue: 'google/gemini-3-flash-preview',
  );

  /// Maximum iterations for ReAct agent
  static const int maxIterations = 20;

  /// Screenshot quality (0.0 to 1.0)
  static const double screenshotQuality = 0.8;

  /// Default wait time in seconds
  static const int defaultWaitSeconds = 2;
}
