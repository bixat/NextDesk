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
  late TextEditingController _openRouterKeyController;
  late TextEditingController _maxIterationsController;
  late TextEditingController _waitSecondsController;

  bool _obscureOpenRouterKey = true;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<ConfigService>();
    _openRouterKeyController =
        TextEditingController(text: config.customOpenRouterKey);
    _maxIterationsController =
        TextEditingController(text: config.maxIterations.toString());
    _waitSecondsController =
        TextEditingController(text: config.defaultWaitSeconds.toString());

    // Add listeners to track changes
    _openRouterKeyController.addListener(_markAsChanged);
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
    _openRouterKeyController.dispose();
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
                  title: 'OpenRouter API Key',
                  envKey: config.envOpenRouterKey,
                  hasEnvKey: config.hasEnvOpenRouterKey,
                  useEnv: config.useEnvOpenRouter,
                  controller: _openRouterKeyController,
                  obscureText: _obscureOpenRouterKey,
                  onUseEnvChanged: (value) async {
                    await config.setUseEnvOpenRouter(value);
                    _markAsChanged();
                  },
                  onKeyChanged: (_) async {}, // No immediate save
                  onToggleVisibility: () => setState(
                      () => _obscureOpenRouterKey = !_obscureOpenRouterKey),
                  helpUrl: 'https://openrouter.ai/keys',
                ),

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
            border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
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
      await config.setCustomOpenRouterKey(_openRouterKeyController.text.trim());

      // Reinitialize the Gemini model in AppState
      await appState.reinitializeServices();

      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _showResetDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Reset Settings?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will reset all settings to their default values. API keys will be cleared.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final config = context.read<ConfigService>();
      await config.resetToDefaults();

      setState(() {
        _openRouterKeyController.text = config.customOpenRouterKey;
        _maxIterationsController.text = config.maxIterations.toString();
        _waitSecondsController.text = config.defaultWaitSeconds.toString();
        _obscureOpenRouterKey = true;
        _hasUnsavedChanges = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings reset to defaults'),
          backgroundColor: AppTheme.primaryPurple,
        ),
      );
    }
  }
}
