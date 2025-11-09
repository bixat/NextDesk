/// Application configuration
///
/// Store your API keys and configuration here.
/// For production, use environment variables or secure storage.
class AppConfig {
  /// Gemini API Key
  /// Get your API key from: https://makersuite.google.com/app/apikey
  static const String geminiApiKey = String.fromEnvironment("GEMINI_API_KEY");

  /// Qwen API Key (Dashscope)
  /// Get your API key from: https://dashscope.console.aliyun.com/
  static const String qwenApiKey = String.fromEnvironment("QWEN_API_KEY");

  /// Vision provider: 'gemini' or 'qwen'
  static const String visionProvider = 'gemini';

  /// Shortcuts provider: 'gemini' or 'qwen'
  /// Used by getShortcuts tool to fetch keyboard shortcuts
  static const String shortcutsProvider = 'gemini';

  /// Maximum iterations for ReAct agent
  static const int maxIterations = 20;

  /// Screenshot quality (0.0 to 1.0)
  static const double screenshotQuality = 0.8;

  /// Default wait time in seconds
  static const int defaultWaitSeconds = 2;
}
