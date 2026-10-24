import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../widgets/top_alert_bar.dart';
import '../../widgets/settings_container_dialog.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../data/services/auth_storage.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  int _step = 0; // 0 = Request OTP, 1 = Verify OTP, 2 = Change Password
  
  final _otpController = TextEditingController();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  
  double _strength = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.grey;

  void _checkStrength(String val) {
    double strength = 0;
    if (val.length >= 8) strength += 1;
    if (val.contains(RegExp(r'[A-Z]'))) strength += 1;
    if (val.contains(RegExp(r'[0-9]'))) strength += 1;
    if (val.contains(RegExp(r'[!@#\$&*~]'))) strength += 1;
    
    setState(() {
      _strength = strength;
      if (strength == 0) {
        _strengthLabel = '';
        _strengthColor = Colors.grey;
      } else if (strength == 1) {
        _strengthLabel = 'Weak';
        _strengthColor = Colors.red;
      } else if (strength == 2) {
        _strengthLabel = 'Fair';
        _strengthColor = Colors.orange;
      } else if (strength == 3) {
        _strengthLabel = 'Good';
        _strengthColor = Colors.blue;
      } else {
        _strengthLabel = 'Strong';
        _strengthColor = Colors.green;
      }
    });
  }

  Future<void> _requestOtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user?.email == null) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.post(
        ApiEndpoints.forgotPassword,
        body: {'email': auth.user!.email},
      );

      if (response.success && mounted) {
        TopAlertBar.showSuccess(context, 'OTP sent to ${auth.user!.email}');
        setState(() => _step = 1);
      } else if (mounted) {
        TopAlertBar.showError(context, response.message ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) TopAlertBar.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 4) {
      TopAlertBar.showError(context, 'Please enter a 4-digit OTP');
      return;
    }
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiClient.post(
        ApiEndpoints.verifyOtp,
        body: {
          'email': auth.user!.email,
          'otp': _otpController.text,
        },
      );

      if (response.success && mounted) {
        TopAlertBar.showSuccess(context, 'Identity verified!');
        setState(() => _step = 2);
      } else if (mounted) {
        TopAlertBar.showError(context, response.message ?? 'Invalid OTP');
      }
    } catch (e) {
      if (mounted) TopAlertBar.showError(context, 'Error verifying OTP');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_newController.text == _currentController.text) {
      TopAlertBar.showError(context, 'New password must not be the same as current password');
      return;
    }
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.post(
        ApiEndpoints.changePassword,
        body: {
          'currentPassword': _currentController.text,
          'newPassword': _newController.text,
        },
      );

      if (response.success) {
        if (response.data != null && response.data['tokens'] != null) {
          final tokens = response.data['tokens'];
          await AuthStorage.saveTokens(
            accessToken: tokens['accessToken'],
            refreshToken: tokens['refreshToken'],
            email: auth.user?.email,
          );
        }
        if (mounted) {
          TopAlertBar.showSuccess(context, 'Password updated successfully!');
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          TopAlertBar.showError(context, response.message ?? 'Incorrect current password');
        }
      }
    } catch (e) {
      if (mounted) {
        TopAlertBar.showError(context, 'Error updating password: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final surface = isDark ? const Color(0xFF161616) : Colors.white;
    final auth = Provider.of<AuthProvider>(context);

    return SettingsScreenScaffold(
      title: 'Change Password',
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            if (_step == 0) _buildRequestOtpStep(auth.user?.email ?? '', isDark),
            if (_step == 1) _buildVerifyOtpStep(auth.user?.email ?? '', isDark, surface),
            if (_step == 2) _buildChangePasswordStep(isDark, surface),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestOtpStep(String email, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For your security, we need to verify your identity before you can change your password.',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registered Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send Verification OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOtpStep(String email, bool isDark, Color surface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We sent a 4-digit code to $email. Please enter it below.',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 20),
        _label('Verification Code'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: "",
            hintText: '----',
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify Identity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _requestOtp,
            child: Text(
              'Resend Code',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePasswordStep(bool isDark, Color surface) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Current Password'),
          const SizedBox(height: 6),
          _buildField(
            controller: _currentController,
            hint: 'Enter your current password',
            obscure: _obscureCurrent,
            isDark: isDark,
            surface: surface,
            onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 20),

          _label('New Password'),
          const SizedBox(height: 6),
          _buildField(
            controller: _newController,
            hint: 'Minimum 8 characters',
            obscure: _obscureNew,
            isDark: isDark,
            surface: surface,
            onChanged: _checkStrength,
            onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 8) return 'At least 8 characters required';
              if (v == _currentController.text) return 'Cannot be identical to current password';
              return null;
            },
          ),
          if (_newController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _strength / 4,
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _strengthLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _strengthColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Uppercase, numbers & symbols make a stronger password.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 20),

          _label('Confirm New Password'),
          const SizedBox(height: 6),
          _buildField(
            controller: _confirmController,
            hint: 'Re-enter your new password',
            obscure: _obscureConfirm,
            isDark: isDark,
            surface: surface,
            onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v != _newController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitChangePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_reset_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Update Password',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required bool isDark,
    required Color surface,
    required VoidCallback onToggleObscure,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey,
            size: 18,
          ),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }
}
