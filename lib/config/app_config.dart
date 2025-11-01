/// Application configuration
/// 
/// Store your API keys and configuration here.
/// For production, use environment variables or secure storage.
class AppConfig {
  /// Gemini API Key
  /// Get your API key from: https://makersuite.google.com/app/apikey
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
  
  /// Maximum iterations for ReAct agent
  static const int maxIterations = 20;
  
  /// Screenshot quality (0.0 to 1.0)
  static const double screenshotQuality = 0.8;
  
  /// Default wait time in seconds
  static const int defaultWaitSeconds = 2;
}

