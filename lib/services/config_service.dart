import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application configuration
/// Supports environment variables as defaults and user-provided custom values
class ConfigService extends ChangeNotifier {
  static const String _keyUseEnvOpenRouter = 'use_env_openrouter';
  static const String _keyCustomOpenRouterKey = 'custom_openrouter_key';
  static const String _keyMaxIterations = 'max_iterations';
  static const String _keyScreenshotQuality = 'screenshot_quality';
  static const String _keyDefaultWaitSeconds = 'default_wait_seconds';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Default values from environment variables
  String? _envOpenRouterKey;

  // User preferences
  bool _useEnvOpenRouter = true;
  String _customOpenRouterKey = '';
  int _maxIterations = 20;
  double _screenshotQuality = 0.8;
  int _defaultWaitSeconds = 2;

  ConfigService() {
    _loadEnvVariables();
  }

  /// Load environment variables
  void _loadEnvVariables() {
    _envOpenRouterKey = Platform.environment['OPENROUTER_API_KEY'];
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

    _useEnvOpenRouter = _prefs!.getBool(_keyUseEnvOpenRouter) ?? true;
    _customOpenRouterKey = _prefs!.getString(_keyCustomOpenRouterKey) ?? '';
    _maxIterations = _prefs!.getInt(_keyMaxIterations) ?? 20;
    _screenshotQuality = _prefs!.getDouble(_keyScreenshotQuality) ?? 0.8;
    _defaultWaitSeconds = _prefs!.getInt(_keyDefaultWaitSeconds) ?? 2;
  }

  // Getters
  bool get isInitialized => _isInitialized;

  bool get hasEnvOpenRouterKey =>
      _envOpenRouterKey != null && _envOpenRouterKey!.isNotEmpty;

  String? get envOpenRouterKey => _envOpenRouterKey;

  bool get useEnvOpenRouter => _useEnvOpenRouter;
  String get customOpenRouterKey => _customOpenRouterKey;
  int get maxIterations => _maxIterations;
  double get screenshotQuality => _screenshotQuality;
  int get defaultWaitSeconds => _defaultWaitSeconds;

  /// Get the active OpenRouter API key (env or custom)
  String get openRouterApiKey {
    if (_useEnvOpenRouter && hasEnvOpenRouterKey) {
      return _envOpenRouterKey!;
    }
    return _customOpenRouterKey;
  }

  /// Check if OpenRouter is properly configured
  bool get isOpenRouterConfigured => openRouterApiKey.isNotEmpty;

  // Setters with persistence

  Future<void> setUseEnvOpenRouter(bool value) async {
    _useEnvOpenRouter = value;
    await _prefs?.setBool(_keyUseEnvOpenRouter, value);
    notifyListeners();
  }

  Future<void> setCustomOpenRouterKey(String value) async {
    _customOpenRouterKey = value;
    await _prefs?.setString(_keyCustomOpenRouterKey, value);
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
    _useEnvOpenRouter = true;
    _customOpenRouterKey = '';
    _maxIterations = 20;
    _screenshotQuality = 0.8;
    _defaultWaitSeconds = 2;

    await _prefs?.clear();
    notifyListeners();
  }
}
