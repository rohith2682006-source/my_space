import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/top_alert_bar.dart';
import '../../widgets/settings_container_dialog.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAppLockEnabled = false;
  bool _isLoading = true;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    
    setState(() {
      _isAppLockEnabled = prefs.getBool('isAppLockEnabled') ?? false;
      _canCheckBiometrics = canCheck;
      _isLoading = false;
    });
  }

  Future<void> _toggleAppLock(bool enable) async {
    if (!_canCheckBiometrics) {
      TopAlertBar.showError(context, 'Biometrics are not supported on this device.');
      return;
    }

    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate(
        localizedReason: enable 
            ? 'Authenticate to enable App Lock' 
            : 'Authenticate to disable App Lock',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      if (!mounted) return;
      TopAlertBar.showError(context, 'Authentication error: $e');
      return;
    }

    if (authenticated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAppLockEnabled', enable);
      setState(() => _isAppLockEnabled = enable);
      
      if (!mounted) return;
      if (enable) {
        TopAlertBar.showSuccess(context, 'App Lock is now enabled.');
      } else {
        TopAlertBar.showSuccess(context, 'App Lock is now disabled.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SettingsScreenScaffold(
      title: 'Biometric App Lock',
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'App Lock',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Require biometric to open app',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isAppLockEnabled,
                      activeColor: AppColors.primary,
                      onChanged: _toggleAppLock,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'When enabled, you will need to use Face ID, Touch ID, or your device passcode to unlock Spaces when it launches or resumes from the background.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.5,
                ),
              ),
      ],
      ),
    );
  }
}
