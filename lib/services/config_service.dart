import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application configuration
/// Supports environment variables as defaults and user-provided custom values
class ConfigService extends ChangeNotifier {
  static const String _keyUseEnvOpenRouter = 'use_env_openrouter';
  static const String _keyCustomOpenRouterKey = 'custom_openrouter_key';
  static const String _keyUseEnvHCompany = 'use_env_hcompany';
  static const String _keyCustomHCompanyKey = 'custom_hcompany_key';
  static const String _keyVisionModel = 'vision_model';
  static const String _keyChatModel = 'chat_model';
  static const String _keyMaxIterations = 'max_iterations';
  static const String _keyScreenshotQuality = 'screenshot_quality';
  static const String _keyDefaultWaitSeconds = 'default_wait_seconds';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Default values from environment variables
  String? _envOpenRouterKey;
  String? _envHCompanyKey;

  // User preferences
  bool _useEnvOpenRouter = true;
  String _customOpenRouterKey = '';
  bool _useEnvHCompany = true;
  String _customHCompanyKey = '';
  String _visionModel = 'hcompany/holo3-35b-a3b';
  String _chatModel = 'google/gemini-3-flash-preview';
  int _maxIterations = 20;
  double _screenshotQuality = 0.8;
  int _defaultWaitSeconds = 2;

  ConfigService() {
    _loadEnvVariables();
  }

  /// Load environment variables
  void _loadEnvVariables() {
    _envOpenRouterKey = Platform.environment['OPENROUTER_API_KEY'];
    _envHCompanyKey = Platform.environment['HCOMPANY_API_KEY'];
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
    _useEnvHCompany = _prefs!.getBool(_keyUseEnvHCompany) ?? true;
    _customHCompanyKey = _prefs!.getString(_keyCustomHCompanyKey) ?? '';
    _visionModel =
        _prefs!.getString(_keyVisionModel) ?? 'hcompany/holo3-35b-a3b';
    _chatModel =
        _prefs!.getString(_keyChatModel) ?? 'google/gemini-3-flash-preview';
    _maxIterations = _prefs!.getInt(_keyMaxIterations) ?? 20;
    _screenshotQuality = _prefs!.getDouble(_keyScreenshotQuality) ?? 0.8;
    _defaultWaitSeconds = _prefs!.getInt(_keyDefaultWaitSeconds) ?? 2;
  }

  // Getters
  bool get isInitialized => _isInitialized;

  bool get hasEnvOpenRouterKey =>
      _envOpenRouterKey != null && _envOpenRouterKey!.isNotEmpty;

  bool get hasEnvHCompanyKey =>
      _envHCompanyKey != null && _envHCompanyKey!.isNotEmpty;

  String? get envOpenRouterKey => _envOpenRouterKey;

  String? get envHCompanyKey => _envHCompanyKey;

  bool get useEnvOpenRouter => _useEnvOpenRouter;
  String get customOpenRouterKey => _customOpenRouterKey;
  bool get useEnvHCompany => _useEnvHCompany;
  String get customHCompanyKey => _customHCompanyKey;
  String get visionModel => _visionModel;
  String get chatModel => _chatModel;
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

  /// Get the active HCompany API key (env or custom)
  String get hCompanyApiKey {
    if (_useEnvHCompany && hasEnvHCompanyKey) {
      return _envHCompanyKey!;
    }
    return _customHCompanyKey;
  }

  /// Check if OpenRouter is properly configured
  bool get isOpenRouterConfigured => openRouterApiKey.isNotEmpty;

  /// Check if HCompany is properly configured
  bool get isHCompanyConfigured => hCompanyApiKey.isNotEmpty;

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
    _useEnvHCompany = true;
    _customHCompanyKey = '';
    _visionModel = 'hcompany/holo3-35b-a3b';
    _chatModel = 'google/gemini-3-flash-preview';
    _maxIterations = 20;
    _screenshotQuality = 0.8;
    _defaultWaitSeconds = 2;

    await _prefs?.clear();
    notifyListeners();
  }

  // Model setters with persistence

  Future<void> setVisionModel(String value) async {
    _visionModel = value;
    await _prefs?.setString(_keyVisionModel, value);
    notifyListeners();
  }

  Future<void> setChatModel(String value) async {
    _chatModel = value;
    await _prefs?.setString(_keyChatModel, value);
    notifyListeners();
  }

  // HCompany API key setters

  Future<void> setUseEnvHCompany(bool value) async {
    _useEnvHCompany = value;
    await _prefs?.setBool(_keyUseEnvHCompany, value);
    notifyListeners();
  }

  Future<void> setCustomHCompanyKey(String value) async {
    _customHCompanyKey = value;
    await _prefs?.setString(_keyCustomHCompanyKey, value);
    notifyListeners();
  }
}
