import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/unified_back_button.dart';
import 'login_screen.dart';
import '../main_navigation_screen.dart';
import '../../../data/services/auth_storage.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Steps: 1 = Email, 2 = OTP, 3 = New Password, 4 = Success
  int _currentStep = 1;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyOtp = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String _verifiedOtp = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 1) {
          _resendCooldown--;
        } else {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSendOtp() async {
    if (!_formKeyEmail.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final success = await auth.forgotPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _startCooldown();
      _otpController.clear();
      setState(() {
        _currentStep = 2;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage =
            auth.errorMessage ?? 'Failed to send OTP. Please verify email.';
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (!_formKeyOtp.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    _verifiedOtp = otp;

    // Auto-clear the OTP text field immediately after clicking Continue / Verify
    _otpController.clear();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await auth.verifyOtp(email, otp);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        _currentStep = 3;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage =
            auth.errorMessage ?? 'Invalid or expired OTP. Please try again.';
      });
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKeyPassword.currentState!.validate()) return;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass != confirmPass) {
      setState(
        () => _errorMessage =
            'Passwords do not match. Please re-enter carefully.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final otp = _verifiedOtp.isNotEmpty
        ? _verifiedOtp
        : _otpController.text.trim();
    final success = await auth.resetPassword(email, otp, newPass);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        _currentStep = 4;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage =
            auth.errorMessage ?? 'Failed to reset password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const UnifiedBackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Password Recovery',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 460,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xAA1E293B)
                      : const Color(0xAAFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.06),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentStep),
                      child: _buildStepContent(isDark),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Email(isDark);
      case 2:
        return _buildStep2Otp(isDark);
      case 3:
        return _buildStep3NewPassword(isDark);
      case 4:
        return _buildStep4Success(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required String stepText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                stepText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Step 1: Email ────────────────────────────────────────────────────────
  Widget _buildStep1Email(bool isDark) {
    return Form(
      key: _formKeyEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            icon: Icons.mark_email_read_outlined,
            title: 'Forgot Password',
            subtitle:
                'Enter your registered email address. We will generate and send a realtime OTP verification code to your mail.',
            stepText: 'Step 1 of 3',
          ),
          CustomTextField(
            controller: _emailController,
            label: 'Registered Email',
            hintText: 'name@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isGlass: true,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email is required';
              if (!val.contains('@') || !val.contains('.'))
                return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Send Verification Code',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleSendOtp,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: Colors.white70,
              ),
              label: const Text(
                'Back to Sign In',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: OTP ──────────────────────────────────────────────────────────
  Widget _buildStep2Otp(bool isDark) {
    return Form(
      key: _formKeyOtp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            icon: Icons.security_rounded,
            title: 'Enter Verification OTP',
            subtitle:
                'We sent a 4-digit verification code to ${_emailController.text}. Please check your email inbox.',
            stepText: 'Step 2 of 3',
          ),
          CustomTextField(
            controller: _otpController,
            label: '4-Digit OTP Code',
            hintText: '••••',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            isGlass: true,
            validator: (val) {
              if (val == null || val.trim().isEmpty)
                return 'Enter the 4-digit code';
              if (val.trim().length != 4)
                return 'Code must be exactly 4 digits';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _currentStep = 1;
                  _errorMessage = null;
                }),
                child: const Text(
                  'Change Email',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: (_resendCooldown > 0 || _isLoading)
                    ? null
                    : _handleSendOtp,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend in ${_resendCooldown}s'
                      : 'Resend Code',
                  style: TextStyle(
                    color: _resendCooldown > 0
                        ? Colors.white38
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Verify Code',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleVerifyOtp,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: New Password & Re-enter Password ─────────────────────────────
  Widget _buildStep3NewPassword(bool isDark) {
    return Form(
      key: _formKeyPassword,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            icon: Icons.lock_reset_rounded,
            title: 'Reset Password',
            subtitle:
                'Code verified! Enter your new password and re-enter it to confirm.',
            stepText: 'Step 3 of 3',
          ),
          CustomTextField(
            controller: _newPasswordController,
            label: 'New Password',
            hintText: 'Minimum 6 characters',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            isGlass: true,
            validator: (val) {
              if (val == null || val.isEmpty) return 'New password is required';
              if (val.length < 6)
                return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 18),
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'Re-enter New Password',
            hintText: 'Re-type new password to confirm',
            prefixIcon: Icons.lock_clock_outlined,
            isPassword: true,
            isGlass: true,
            validator: (val) {
              if (val == null || val.isEmpty)
                return 'Please re-enter your password';
              if (val != _newPasswordController.text)
                return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Confirm & Reset Password',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleResetPassword,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 4: Success ──────────────────────────────────────────────────────
  Widget _buildStep4Success(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.success,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Password Reset Successful!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your password has been securely updated. You can now log into Spaces with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: 'Continue to Spaces',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const MainNavigationScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Back to Sign In Screen',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
