import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/spaces_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/unified_back_button.dart';
import '../../widgets/top_alert_bar.dart';

class VaultForgotPasswordScreen extends StatefulWidget {
  final String spaceId;
  final String spaceName;
  final void Function(BuildContext) onUnlocked;

  const VaultForgotPasswordScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.onUnlocked,
  });

  @override
  State<VaultForgotPasswordScreen> createState() =>
      _VaultForgotPasswordScreenState();
}

class _VaultForgotPasswordScreenState extends State<VaultForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 1; // 1: Email, 2: OTP, 3: Change Password, 4: Re-enter to Open
  bool _isLoading = false;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _reenterPasswordController = TextEditingController();

  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();
  final _formKeyReenter = GlobalKey<FormState>();

  int _resendCountdown = 60;
  Timer? _resendTimer;

  late AnimationController _shieldAnim;
  late Animation<double> _shieldScale;
  late Animation<double> _shieldGlow;

  @override
  void initState() {
    super.initState();
    _shieldAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _shieldScale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _shieldAnim, curve: Curves.easeInOut));
    _shieldGlow = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _shieldAnim, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final regEmail = (auth.user?.email ?? '').trim();
        if (regEmail.isNotEmpty) {
          setState(() {
            _emailController.text = regEmail;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _shieldAnim.dispose();
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _reenterPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // ─── Step 1: Request OTP with Registered Email Check ────────────────────────
  Future<void> _handleRequestOtp() async {
    if (_isLoading) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final registeredEmail = (auth.user?.email ?? '').trim();
    if (_emailController.text.trim().isEmpty && registeredEmail.isNotEmpty) {
      _emailController.text = registeredEmail;
    }

    final enteredEmail = _emailController.text.trim().toLowerCase();
    if (enteredEmail.isEmpty) {
      setState(() {
        _errorMessage = 'No registered email found for this account.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.post(
        ApiEndpoints.forgotPassword,
        body: {'email': enteredEmail},
      );

      if (!mounted) return;

      if (response.success) {
        _startResendTimer();
        _otpController.clear();
        setState(() {
          _currentStep = 2;
          _isLoading = false;
        });

        TopAlertBar.showSuccess(
          context,
          'Verification code sent to $enteredEmail. Please check your inbox.',
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              response.message ?? 'Failed to send verification code.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  // ─── Step 2: Verify OTP ───────────────────────────────────────────────────
  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4 || _isLoading) {
      setState(() => _errorMessage = 'Please enter a valid 4-digit code');
      return;
    }

    final enteredEmail = _emailController.text.trim().toLowerCase();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.post(
        ApiEndpoints.verifyOtp,
        body: {'email': enteredEmail, 'otp': otp},
      );

      if (!mounted) return;

      if (response.success) {
        _otpController.clear(); // Auto-clear OTP field
        setState(() {
          _currentStep = 3;
          _isLoading = false;
        });
        TopAlertBar.showSuccess(context, 'Security code verified!');
      } else {
        _otpController.clear(); // Auto clear on invalid code
        setState(() {
          _isLoading = false;
          _errorMessage = response.message ?? 'Invalid or expired code.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification error: $e';
      });
    }
  }

  // ─── Step 3: Change Space Vault Password ─────────────────────────────────
  Future<void> _handleChangePassword() async {
    if (!_formKeyPassword.currentState!.validate() || _isLoading) return;

    final newPassword = _newPasswordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final spacesProvider = Provider.of<SpacesProvider>(
        context,
        listen: false,
      );
      final success = await spacesProvider.updateSpace(
        widget.spaceId,
        password: newPassword,
      );

      if (!mounted) return;

      if (success) {
        _reenterPasswordController.text = newPassword;
        setState(() {
          _currentStep = 4;
          _isLoading = false;
        });
        TopAlertBar.showSuccess(
          context,
          'Vault password updated successfully!',
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              spacesProvider.errorMessage ?? 'Failed to update vault password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error updating password: $e';
      });
    }
  }

  // ─── Step 4: Re-enter Password & Open Folder ─────────────────────────────
  Future<void> _handleReenterAndOpen() async {
    if (!_formKeyReenter.currentState!.validate() || _isLoading) return;

    final enteredPassword = _reenterPasswordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final spacesProvider = Provider.of<SpacesProvider>(
        context,
        listen: false,
      );

      bool success = false;
      // Fast path: if entered password matches the newly confirmed password,
      // it was already hashed and verified on the server in Step 3!
      if (enteredPassword == _newPasswordController.text &&
          _newPasswordController.text.isNotEmpty) {
        success = true;
        // Background verify to sync provider state
        spacesProvider
            .verifySpacePassword(widget.spaceId, enteredPassword)
            .catchError((_) => false);
      } else {
        success = await spacesProvider.verifySpacePassword(
          widget.spaceId,
          enteredPassword,
        );
      }

      if (!mounted) return;

      if (success) {
        setState(() => _isLoading = false);
        TopAlertBar.showSuccess(
          context,
          'Vault unlocked! Opening ${widget.spaceName}...',
        );
        // Pop this screen and unlock folder space immediately
        Navigator.pop(context);
        widget.onUnlocked(context);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              spacesProvider.errorMessage ??
              'Incorrect password. Please enter the password you just set.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error verifying password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Card(
                          elevation: isDark ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 24),
                                // Animated Shield
                                AnimatedBuilder(
                                  animation: _shieldAnim,
                                  builder: (ctx, child) => Transform.scale(
                                    scale: _shieldScale.value,
                                    child: Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.primaryGradient,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: _shieldGlow.value),
                                            blurRadius: 32,
                                            spreadRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _getStepIcon(),
                                        color: Colors.white,
                                        size: 46,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                // Title & Subtitle
                                Text(
                                  _getStepTitle(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.spaceName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _getStepSubtitle(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Error message banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.error.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Wizard Step Content
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.04, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: KeyedSubtree(
                                    key: ValueKey<int>(_currentStep),
                                    child: _buildCurrentStepWidget(),
                                  ),
                                ),


                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel & Return',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Security note
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 12,
                                      color: isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.lightTextTertiary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'OTP verified identity recovery',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.lightTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 16,
                  left: 16,
                  child: UnifiedBackButton(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _getStepIcon() {
    switch (_currentStep) {
      case 1:
        return Icons.mark_email_read_rounded;
      case 2:
        return Icons.pin_rounded;
      case 3:
        return Icons.lock_reset_rounded;
      case 4:
        return Icons.lock_open_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Verify Registered Email';
      case 2:
        return 'Enter Security Code';
      case 3:
        return 'Set New Vault Password';
      case 4:
        return 'Re-enter Password to Open';
      default:
        return 'Vault Security Reset';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 1:
        return 'A 4-digit security code will be sent to your registered account email to verify vault ownership.';
      case 2:
        return 'Enter the 4-digit code sent to ${_emailController.text.trim()}.';
      case 3:
        return 'Choose a new password or PIN to protect this folder space.';
      case 4:
        return 'Almost done! Enter your new password to verify and unlock this space right now.';
      default:
        return '';
    }
  }

  // ─── Step 1 Widget ────────────────────────────────────────────────────────
  Widget _buildStep1Email() {
    return Form(
      key: _formKeyEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            controller: _emailController,
            label: 'Registered Email (Fixed)',
            hintText: 'user@example.com',
            prefixIcon: Icons.lock_outline_rounded,
            enabled: false,
            readOnly: true,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Registered email is required';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleRequestOtp(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Fixed to your registered Spaces account. For security, vault reset codes cannot be sent to other emails.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              onPressed: _handleRequestOtp,
              isLoading: _isLoading,
              text: 'Send Verification Code',
              icon: Icons.send_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2 Widget ────────────────────────────────────────────────────────
  Widget _buildStep2Otp() {
    return Column(
      children: [
        CustomTextField(
          controller: _otpController,
          label: '4-Digit Code',
          hintText: 'Enter 4-digit OTP',
          prefixIcon: Icons.lock_clock_outlined,
          keyboardType: TextInputType.number,
          validator: (val) {
            if (val == null || val.trim().length != 4) {
              return 'Please enter 4 digits';
            }
            return null;
          },
          onFieldSubmitted: (_) => _handleVerifyOtp(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _emailController.text.trim(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _resendCountdown == 0 ? _handleRequestOtp : null,
              child: Text(
                _resendCountdown == 0
                    ? 'Resend Code'
                    : 'Resend in ${_resendCountdown}s',
                style: TextStyle(
                  color: _resendCountdown == 0
                      ? AppColors.primary
                      : Colors.white38,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            onPressed: _handleVerifyOtp,
            isLoading: _isLoading,
            text: 'Verify Code',
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  // ─── Step 3 Widget ────────────────────────────────────────────────────────
  Widget _buildStep3NewPassword() {
    return Form(
      key: _formKeyPassword,
      child: Column(
        children: [
          CustomTextField(
            controller: _newPasswordController,
            label: 'New Vault Password',
            hintText: 'Minimum 4 characters',
            isPassword: true,
            prefixIcon: Icons.lock_outline_rounded,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'New password is required';
              }
              if (val.length < 4) {
                return 'Password must be at least 4 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            hintText: 'Re-type your new password',
            isPassword: true,
            prefixIcon: Icons.lock_reset_rounded,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please confirm your new password';
              }
              if (val != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleChangePassword(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              onPressed: _handleChangePassword,
              isLoading: _isLoading,
              text: 'Confirm New Password',
              icon: Icons.check_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 4 Widget ────────────────────────────────────────────────────────
  Widget _buildStep4Reenter() {
    return Form(
      key: _formKeyReenter,
      child: Column(
        children: [
          CustomTextField(
            controller: _reenterPasswordController,
            label: 'Enter Password to Open',
            hintText: 'Re-enter your new vault password',
            isPassword: true,
            prefixIcon: Icons.key_rounded,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleReenterAndOpen(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              onPressed: _handleReenterAndOpen,
              isLoading: _isLoading,
              text: 'Unlock & Open Folder',
              icon: Icons.folder_open_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Email();
      case 2:
        return _buildStep2Otp();
      case 3:
        return _buildStep3NewPassword();
      case 4:
        return _buildStep4Reenter();
      default:
        return const SizedBox.shrink();
    }
  }
}
