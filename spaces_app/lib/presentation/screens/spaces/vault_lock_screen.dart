import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/spaces_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/unified_back_button.dart';
import 'vault_forgot_password_screen.dart';

class VaultLockScreen extends StatefulWidget {
  final String spaceId;
  final String spaceName;
  final void Function(BuildContext) onUnlocked;

  const VaultLockScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.onUnlocked,
  });

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen>
    with SingleTickerProviderStateMixin {
  bool _isAuthenticating = false;
  String? _errorMessage;

  final _passwordController = TextEditingController();

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
  }

  @override
  void dispose() {
    _shieldAnim.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    if (_isAuthenticating) return;

    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter a password');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final spacesProvider = Provider.of<SpacesProvider>(
        context,
        listen: false,
      );
      final success = await spacesProvider.verifySpacePassword(
        widget.spaceId,
        password,
      );

      if (mounted) {
        if (success) {
          widget.onUnlocked(context);
        } else {
          setState(() {
            _isAuthenticating = false;
            _errorMessage =
                spacesProvider.errorMessage ??
                'Incorrect password. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('Vault unlock error: $e');
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'An error occurred. Please try again.';
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
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                // Animated Shield
                                AnimatedBuilder(
                                  animation: _shieldAnim,
                                  builder: (ctx, child) => Transform.scale(
                                    scale: _shieldScale.value,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.primaryGradient,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(_shieldGlow.value),
                                            blurRadius: 40,
                                            spreadRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.shield_rounded,
                                        color: Colors.white,
                                        size: 60,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 36),
                                Text(
                                  'Vault Locked',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.spaceName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'This space is protected by your vault password.\nYour data is encrypted and only accessible to you.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 40),

                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.error.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                CustomTextField(
                                  controller: _passwordController,
                                  label: 'Password / PIN',
                                  isPassword: true,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  onFieldSubmitted: (_) => _handleUnlock(),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: CustomButton(
                                    onPressed: _handleUnlock,
                                    isLoading: _isAuthenticating,
                                    text: 'Unlock Vault',
                                    icon: _isAuthenticating
                                        ? null
                                        : Icons.lock_open_rounded,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VaultForgotPasswordScreen(
                                          spaceId: widget.spaceId,
                                          spaceName: widget.spaceName,
                                          onUnlocked: widget.onUnlocked,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.key_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Forgot Vault Password?',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
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
                                      'End-to-end encrypted • Zero knowledge',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.lightTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(top: 16, left: 16, child: UnifiedBackButton()),
              ],
            );
          },
        ),
      ),
    );
  }
}
