import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application configuration
/// Supports environment variables as defaults and user-provided custom values
class ConfigService extends ChangeNotifier {
  static const String _keyUseEnvGemini = 'use_env_gemini';
  static const String _keyUseEnvQwen = 'use_env_qwen';
  static const String _keyCustomGeminiKey = 'custom_gemini_key';
  static const String _keyCustomQwenKey = 'custom_qwen_key';
  static const String _keyVisionProvider = 'vision_provider';
  static const String _keyShortcutsProvider = 'shortcuts_provider';
  static const String _keyMaxIterations = 'max_iterations';
  static const String _keyScreenshotQuality = 'screenshot_quality';
  static const String _keyDefaultWaitSeconds = 'default_wait_seconds';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Default values from environment variables
  String? _envGeminiKey;
  String? _envQwenKey;

  // User preferences
  bool _useEnvGemini = true;
  bool _useEnvQwen = true;
  String _customGeminiKey = '';
  String _customQwenKey = '';
  String _visionProvider = 'gemini';
  String _shortcutsProvider = 'gemini';
  int _maxIterations = 20;
  double _screenshotQuality = 0.8;
  int _defaultWaitSeconds = 2;

  ConfigService() {
    _loadEnvVariables();
  }

  /// Load environment variables
  void _loadEnvVariables() {
    _envGeminiKey = Platform.environment['GEMINI_API_KEY'];
    _envQwenKey = Platform.environment['QWEN_API_KEY'];
  }

  /// Initialize the service and load saved preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
    _isInitialized = true;
    notifyListeners();
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    if (_prefs == null) return;

    _useEnvGemini = _prefs!.getBool(_keyUseEnvGemini) ?? true;
    _useEnvQwen = _prefs!.getBool(_keyUseEnvQwen) ?? true;
    _customGeminiKey = _prefs!.getString(_keyCustomGeminiKey) ?? '';
    _customQwenKey = _prefs!.getString(_keyCustomQwenKey) ?? '';
    _visionProvider = _prefs!.getString(_keyVisionProvider) ?? 'gemini';
    _shortcutsProvider = _prefs!.getString(_keyShortcutsProvider) ?? 'gemini';
    _maxIterations = _prefs!.getInt(_keyMaxIterations) ?? 20;
    _screenshotQuality = _prefs!.getDouble(_keyScreenshotQuality) ?? 0.8;
    _defaultWaitSeconds = _prefs!.getInt(_keyDefaultWaitSeconds) ?? 2;
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasEnvGeminiKey =>
      _envGeminiKey != null && _envGeminiKey!.isNotEmpty;
  bool get hasEnvQwenKey => _envQwenKey != null && _envQwenKey!.isNotEmpty;
  String? get envGeminiKey => _envGeminiKey;
  String? get envQwenKey => _envQwenKey;

  bool get useEnvGemini => _useEnvGemini;
  bool get useEnvQwen => _useEnvQwen;
  String get customGeminiKey => _customGeminiKey;
  String get customQwenKey => _customQwenKey;
  String get visionProvider => _visionProvider;
  String get shortcutsProvider => _shortcutsProvider;
  int get maxIterations => _maxIterations;
  double get screenshotQuality => _screenshotQuality;
  int get defaultWaitSeconds => _defaultWaitSeconds;

  /// Get the active Gemini API key (env or custom)
  String get geminiApiKey {
    if (_useEnvGemini && hasEnvGeminiKey) {
      return _envGeminiKey!;
    }
    return _customGeminiKey;
  }

  /// Get the active Qwen API key (env or custom)
  String get qwenApiKey {
    if (_useEnvQwen && hasEnvQwenKey) {
      return _envQwenKey!;
    }
    return _customQwenKey;
  }

  /// Check if Gemini is properly configured
  bool get isGeminiConfigured => geminiApiKey.isNotEmpty;

  /// Check if Qwen is properly configured
  bool get isQwenConfigured => qwenApiKey.isNotEmpty;

  // Setters with persistence
  Future<void> setUseEnvGemini(bool value) async {
    _useEnvGemini = value;
    await _prefs?.setBool(_keyUseEnvGemini, value);
    notifyListeners();
  }

  Future<void> setUseEnvQwen(bool value) async {
    _useEnvQwen = value;
    await _prefs?.setBool(_keyUseEnvQwen, value);
    notifyListeners();
  }

  Future<void> setCustomGeminiKey(String value) async {
    _customGeminiKey = value;
    await _prefs?.setString(_keyCustomGeminiKey, value);
    notifyListeners();
  }

  Future<void> setCustomQwenKey(String value) async {
    _customQwenKey = value;
    await _prefs?.setString(_keyCustomQwenKey, value);
    notifyListeners();
  }

  Future<void> setVisionProvider(String value) async {
    _visionProvider = value;
    await _prefs?.setString(_keyVisionProvider, value);
    notifyListeners();
  }

  Future<void> setShortcutsProvider(String value) async {
    _shortcutsProvider = value;
    await _prefs?.setString(_keyShortcutsProvider, value);
    notifyListeners();
  }

  Future<void> setMaxIterations(int value) async {
    _maxIterations = value;
    await _prefs?.setInt(_keyMaxIterations, value);
    notifyListeners();
  }

  Future<void> setScreenshotQuality(double value) async {
    _screenshotQuality = value;
    await _prefs?.setDouble(_keyScreenshotQuality, value);
    notifyListeners();
  }

  Future<void> setDefaultWaitSeconds(int value) async {
    _defaultWaitSeconds = value;
    await _prefs?.setInt(_keyDefaultWaitSeconds, value);
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _useEnvGemini = true;
    _useEnvQwen = true;
    _customGeminiKey = '';
    _customQwenKey = '';
    _visionProvider = 'gemini';
    _shortcutsProvider = 'gemini';
    _maxIterations = 20;
    _screenshotQuality = 0.8;
    _defaultWaitSeconds = 2;

    await _prefs?.clear();
    notifyListeners();
  }
}
