import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/top_alert_bar.dart';
import '../../widgets/settings_container_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  bool _is2FAEnabled = false;
  bool _isLoading = true;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _is2FAEnabled = prefs.getBool('is2FAEnabled') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggle2FA(bool enable) async {
    if (enable) {
      _showSetupDialog();
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Disable 2FA?'),
          content: const Text(
            'Disabling Two-Factor Authentication will reduce the security of your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disable'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is2FAEnabled', false);
        setState(() => _is2FAEnabled = false);
        if (mounted) {
          TopAlertBar.showSuccess(context, 'Two-Factor Authentication has been disabled.');
        }
      }
    }
  }

  void _showSetupDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Setup 2FA',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan the QR code below with your authenticator app (like Google Authenticator or Authy), then enter the 6-digit code to verify.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              // Dummy QR Code
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Icon(Icons.qr_code_2_rounded, size: 100, color: Colors.grey.shade800),
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_codeController.text.length == 6) {
                          Navigator.pop(ctx);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('is2FAEnabled', true);
                          setState(() => _is2FAEnabled = true);
                          if (mounted) {
                            TopAlertBar.showSuccess(context, '2FA has been successfully enabled.');
                          }
                        } else {
                          TopAlertBar.showError(ctx, 'Please enter a valid 6-digit code.');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
      title: 'Two-Factor Auth',
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _is2FAEnabled ? Icons.shield_rounded : Icons.shield_outlined,
                      size: 64,
                      color: _is2FAEnabled ? AppColors.success : Colors.grey,
                    ).animate(target: _is2FAEnabled ? 1 : 0).scale(duration: 300.ms),
                    const SizedBox(height: 16),
                    Text(
                      _is2FAEnabled ? '2FA is Enabled' : '2FA is Disabled',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _is2FAEnabled ? AppColors.success : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Two-Factor Authentication adds an extra layer of security to your account by requiring more than just a password to log in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _is2FAEnabled ? 'Disable 2FA' : 'Enable 2FA',
                  icon: _is2FAEnabled ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded,
                  color: _is2FAEnabled ? AppColors.error : AppColors.primary,
                  onPressed: () => _toggle2FA(!_is2FAEnabled),
                ),
              ),
      ],
      ),
    );
  }
}
