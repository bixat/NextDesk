import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../services/config_service.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _geminiKeyController;
  late TextEditingController _qwenKeyController;
  late TextEditingController _maxIterationsController;
  late TextEditingController _waitSecondsController;

  bool _obscureGeminiKey = true;
  bool _obscureQwenKey = true;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<ConfigService>();
    _geminiKeyController = TextEditingController(text: config.customGeminiKey);
    _qwenKeyController = TextEditingController(text: config.customQwenKey);
    _maxIterationsController =
        TextEditingController(text: config.maxIterations.toString());
    _waitSecondsController =
        TextEditingController(text: config.defaultWaitSeconds.toString());

    // Add listeners to track changes
    _geminiKeyController.addListener(_markAsChanged);
    _qwenKeyController.addListener(_markAsChanged);
    _maxIterationsController.addListener(_markAsChanged);
    _waitSecondsController.addListener(_markAsChanged);
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _qwenKeyController.dispose();
    _maxIterationsController.dispose();
    _waitSecondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_hasUnsavedChanges)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: AppTheme.spaceSm,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            onPressed: _showResetDialog,
            tooltip: 'Reset to Defaults',
          ),
          const SizedBox(width: AppTheme.spaceSm),
        ],
      ),
      body: Consumer<ConfigService>(
        builder: (context, config, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // API Keys Section
                _buildSectionHeader(
                  icon: Icons.key_rounded,
                  title: 'API Keys',
                  subtitle: 'Configure your AI provider API keys',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                _buildApiKeyCard(
                  config: config,
                  title: 'Gemini API Key',
                  envKey: config.envGeminiKey,
                  hasEnvKey: config.hasEnvGeminiKey,
                  useEnv: config.useEnvGemini,
                  controller: _geminiKeyController,
                  obscureText: _obscureGeminiKey,
                  onUseEnvChanged: (value) async {
                    await config.setUseEnvGemini(value);
                    _markAsChanged();
                  },
                  onKeyChanged: (_) async {}, // No immediate save
                  onToggleVisibility: () =>
                      setState(() => _obscureGeminiKey = !_obscureGeminiKey),
                  helpUrl: 'https://makersuite.google.com/app/apikey',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                _buildApiKeyCard(
                  config: config,
                  title: 'Qwen API Key',
                  envKey: config.envQwenKey,
                  hasEnvKey: config.hasEnvQwenKey,
                  useEnv: config.useEnvQwen,
                  controller: _qwenKeyController,
                  obscureText: _obscureQwenKey,
                  onUseEnvChanged: (value) async {
                    await config.setUseEnvQwen(value);
                    _markAsChanged();
                  },
                  onKeyChanged: (_) async {}, // No immediate save
                  onToggleVisibility: () =>
                      setState(() => _obscureQwenKey = !_obscureQwenKey),
                  helpUrl: 'https://dashscope.console.aliyun.com/',
                ),

                const SizedBox(height: AppTheme.spaceLg),

                // Providers Section
                _buildSectionHeader(
                  icon: Icons.settings_suggest_rounded,
                  title: 'AI Providers',
                  subtitle: 'Choose which AI models to use',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                _buildProviderCard(config),

                const SizedBox(height: AppTheme.spaceLg),

                // Performance Section
                _buildSectionHeader(
                  icon: Icons.tune_rounded,
                  title: 'Performance',
                  subtitle: 'Adjust automation behavior',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                _buildPerformanceCard(config),

                const SizedBox(height: AppTheme.spaceLg),

                // Info Section
                _buildInfoCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyCard({
    required ConfigService config,
    required String title,
    required String? envKey,
    required bool hasEnvKey,
    required bool useEnv,
    required TextEditingController controller,
    required bool obscureText,
    required Future<void> Function(bool) onUseEnvChanged,
    required Future<void> Function(String) onKeyChanged,
    required VoidCallback onToggleVisibility,
    required String helpUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _launchUrl(helpUrl),
                icon: const Icon(Icons.help_outline_rounded, size: 16),
                label: const Text('Get Key'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.secondaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Environment variable option
          if (hasEnvKey) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border:
                    Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppTheme.accentGreen, size: 16),
                  const SizedBox(width: AppTheme.spaceXs),
                  const Expanded(
                    child: Text(
                      'Environment variable detected',
                      style: TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            CheckboxListTile(
              value: useEnv,
              onChanged: (value) => onUseEnvChanged(value ?? true),
              title: const Text(
                'Use environment variable',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              subtitle: Text(
                'Key: ${_maskKey(envKey)}',
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primaryPurple,
            ),
            const SizedBox(height: AppTheme.spaceSm),
          ],

          // Custom key input
          if (!hasEnvKey || !useEnv) ...[
            if (hasEnvKey && !useEnv) ...[
              const Text(
                'Custom API Key',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXs),
            ],
            TextField(
              controller: controller,
              obscureText: obscureText,
              onChanged: onKeyChanged,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: hasEnvKey
                    ? 'Enter custom key (optional)'
                    : 'Enter your API key',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.surfaceMedium,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.primaryPurple),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  onPressed: onToggleVisibility,
                  color: AppTheme.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: AppTheme.spaceSm,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderCard(ConfigService config) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vision Provider',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          _buildProviderSelector(
            value: config.visionProvider,
            onChanged: (value) async {
              await config.setVisionProvider(value);
              _markAsChanged();
            },
            geminiEnabled: config.isGeminiConfigured,
            qwenEnabled: config.isQwenConfigured,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const Text(
            'Shortcuts Provider',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          _buildProviderSelector(
            value: config.shortcutsProvider,
            onChanged: (value) async {
              await config.setShortcutsProvider(value);
              _markAsChanged();
            },
            geminiEnabled: config.isGeminiConfigured,
            qwenEnabled: config.isQwenConfigured,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector({
    required String value,
    required Future<void> Function(String) onChanged,
    required bool geminiEnabled,
    required bool qwenEnabled,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildProviderOption(
            label: 'Gemini',
            value: 'gemini',
            groupValue: value,
            enabled: geminiEnabled,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: _buildProviderOption(
            label: 'Qwen',
            value: 'qwen',
            groupValue: value,
            enabled: qwenEnabled,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildProviderOption({
    required String label,
    required String value,
    required String groupValue,
    required bool enabled,
    required Future<void> Function(String) onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: enabled ? () => onChanged(value) : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurple.withOpacity(0.1)
              : AppTheme.surfaceMedium,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryPurple
                : enabled
                    ? AppTheme.borderSubtle
                    : AppTheme.borderSubtle.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 16,
              color: enabled
                  ? (isSelected
                      ? AppTheme.primaryPurple
                      : AppTheme.textTertiary)
                  : AppTheme.textTertiary.withOpacity(0.3),
            ),
            const SizedBox(width: AppTheme.spaceXs),
            Text(
              label,
              style: TextStyle(
                color: enabled
                    ? (isSelected
                        ? AppTheme.primaryPurple
                        : AppTheme.textSecondary)
                    : AppTheme.textTertiary.withOpacity(0.3),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (!enabled) ...[
              const SizedBox(width: AppTheme.spaceXs),
              Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: AppTheme.textTertiary.withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(ConfigService config) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNumberField(
            label: 'Max Iterations',
            controller: _maxIterationsController,
            onChanged: (value) {
              final intValue = int.tryParse(value);
              if (intValue != null && intValue > 0) {
                config.setMaxIterations(intValue);
                _markAsChanged();
              }
            },
            hint: '20',
            suffix: 'iterations',
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _buildSliderField(
            label: 'Screenshot Quality',
            value: config.screenshotQuality,
            onChanged: (value) {
              config.setScreenshotQuality(value);
              _markAsChanged();
            },
            min: 0.1,
            max: 1.0,
            divisions: 9,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _buildNumberField(
            label: 'Default Wait Time',
            controller: _waitSecondsController,
            onChanged: (value) {
              final intValue = int.tryParse(value);
              if (intValue != null && intValue > 0) {
                config.setDefaultWaitSeconds(intValue);
                _markAsChanged();
              }
            },
            hint: '2',
            suffix: 'seconds',
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
    required String hint,
    required String suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            suffixText: suffix,
            suffixStyle:
                const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            filled: true,
            fillColor: AppTheme.surfaceMedium,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: AppTheme.primaryPurple),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: AppTheme.spaceSm,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required Function(double) onChanged,
    required double min,
    required double max,
    required int divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(
                color: AppTheme.primaryPurple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppTheme.primaryPurple,
          inactiveColor: AppTheme.borderMedium,
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.secondaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.secondaryBlue, size: 20),
          const SizedBox(width: AppTheme.spaceMd),
          const Expanded(
            child: Text(
              'Settings are saved automatically. Changes take effect immediately.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskKey(String? key) {
    if (key == null || key.isEmpty) return '';
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open URL: $url'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening URL: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final config = context.read<ConfigService>();
      final appState = context.read<AppState>();

      // Save API keys
      await config.setCustomGeminiKey(_geminiKeyController.text.trim());
      await config.setCustomQwenKey(_qwenKeyController.text.trim());

      // Reinitialize the Gemini model in AppState
      await appState.reinitializeServices();

      if (!mounted) return;

      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Settings saved successfully'),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Reset Settings',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to reset all settings to their default values?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ConfigService>().resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
