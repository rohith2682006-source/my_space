import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/unified_back_button.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main_navigation_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final credentials = await auth.getGoogleSignInCredentials();
    if (credentials != null && credentials.idToken != null) {
      final payload = auth.parseJwt(credentials.idToken!);
      if (payload != null && mounted) {
        setState(() {
          if (payload['email'] != null) {
            _emailController.text = payload['email'];
          }
          if (payload['given_name'] != null) {
            _firstNameController.text = payload['given_name'];
          }
          if (payload['family_name'] != null) {
            _lastNameController.text = payload['family_name'];
          } else if (payload['name'] != null) {
            final nameParts = payload['name'].toString().split(' ');
            if (nameParts.isNotEmpty) {
              _firstNameController.text = nameParts.first;
              if (nameParts.length > 1) {
                _lastNameController.text = nameParts.sublist(1).join(' ');
              }
            }
          }
        });
      }
    }
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Up Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      email: _emailController.text,
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
    );

    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: UnifiedBackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/wooden_texture.jpg'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black45 : Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Create Your Space',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Organize everything around what matters to you',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (auth.errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            hintText: 'Rohith',
                            isGlass: true,
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            hintText: 'Kumar',
                            isGlass: true,
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hintText: 'name@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      isGlass: true,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email is required';
                        if (!val.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'At least 8 chars',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      isGlass: true,
                      validator: (val) {
                        if (val == null || val.length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: 'Create Account',
                        isLoading: auth.isLoading,
                        onPressed: _handleRegister,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: auth.googleSignIn.signInButton(
                          config: GSIAPButtonConfig(
                            uiConfig: const GSIAPButtonUiConfig(text: GSIAPButtonText.signupWith),
                            onSignIn: (credentials) async {
                              if (credentials.idToken != null) {
                                final payload = auth.parseJwt(credentials.idToken!);
                                if (payload != null && mounted) {
                                  setState(() {
                                    if (payload['email'] != null) {
                                      _emailController.text = payload['email'];
                                    }
                                    if (payload['given_name'] != null) {
                                      _firstNameController.text = payload['given_name'];
                                    }
                                    if (payload['family_name'] != null) {
                                      _lastNameController.text = payload['family_name'];
                                    } else if (payload['name'] != null) {
                                      final nameParts = payload['name'].toString().split(' ');
                                      if (nameParts.isNotEmpty) {
                                        _firstNameController.text = nameParts.first;
                                        if (nameParts.length > 1) {
                                          _lastNameController.text = nameParts.sublist(1).join(' ');
                                        }
                                      }
                                    }
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Sign up with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: auth.isLoading ? null : _handleGoogleLogin,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    );
  }
}
