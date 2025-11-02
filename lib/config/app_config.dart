/// Application configuration
///
/// Store your API keys and configuration here.
/// For production, use environment variables or secure storage.
class AppConfig {
  /// Gemini API Key
  /// Get your API key from: https://makersuite.google.com/app/apikey
  static const String geminiApiKey = 'AIzaSyCqF8yEv4MwA_rp6vzdUckXMt0qGHRg6X4';

  /// Qwen API Key (Dashscope)
  /// Get your API key from: https://dashscope.console.aliyun.com/
  static const String qwenApiKey = 'sk-dedc60e827f94b66b2964ee43377cdb8';

  /// Vision provider: 'gemini' or 'qwen'
  static const String visionProvider = 'qwen';

  /// Maximum iterations for ReAct agent
  static const int maxIterations = 20;

  /// Screenshot quality (0.0 to 1.0)
  static const double screenshotQuality = 0.8;

  /// Default wait time in seconds
  static const int defaultWaitSeconds = 2;
}
