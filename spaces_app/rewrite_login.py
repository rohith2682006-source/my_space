import sys

content = '''import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../widgets/unified_back_button.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main_navigation_screen.dart';
import '../../../data/services/auth_storage.dart';
import 'dart:async';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E1B4B),
                Color(0xFF020617),
              ],
            ),
          ),
        ),
        // Animated shapes
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: -100 + (math.sin(_controller.value * 2 * math.pi) * 50),
                  left: -100 + (math.cos(_controller.value * 2 * math.pi) * 50),
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.15),
                      backgroundBlendMode: BlendMode.screen,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150 + (math.cos(_controller.value * 2 * math.pi) * 80),
                  right: -50 + (math.sin(_controller.value * 2 * math.pi) * 80),
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      backgroundBlendMode: BlendMode.screen,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // Glass overlay to smooth things out
        Container(
          color: Colors.black.withOpacity(0.2),
        ),
        widget.child,
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  final _passwordFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  final LayerLink _emailLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus && _savedAccounts.isNotEmpty && _isLogin) {
        _showOverlay();
      } else {
        // Small delay to allow tap event to register before hiding
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && !_emailFocusNode.hasFocus) {
            _hideOverlay();
          }
        });
      }
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 380,
          child: CompositedTransformFollower(
            link: _emailLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 90),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _savedAccounts.map((acc) {
                    return Listener(
                      onPointerDown: (_) {
                        _emailController.text = acc['email'] ?? '';
                        _hideOverlay();
                        _passwordFocusNode.requestFocus();
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                child: const Icon(Icons.person, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc['firstName'] ?? 'User',
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                    Text(
                                      acc['email'] ?? '',
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await AuthStorage.getSavedAccounts();
    if (mounted) {
      setState(() {
        _savedAccounts = accounts;
      });
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _handleGoogleAction() async {
    setState(() => _isGoogleSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    bool didTimeout = false;
    Timer? timeoutTimer = Timer(const Duration(minutes: 1), () {
      if (mounted && _isGoogleSubmitting) {
        setState(() {
          _isGoogleSubmitting = false;
          didTimeout = true;
        });
      }
    });

    if (!_isLogin) {
      // Signup flow
      final credentials = await auth.getGoogleSignInCredentials();
      timeoutTimer.cancel();
      if (didTimeout) return;

      if (credentials != null && credentials.idToken != null) {
        final payload = auth.parseJwt(credentials.idToken!);
        if (payload != null && mounted) {
          setState(() {
            if (payload['email'] != null) _emailController.text = payload['email'];
            if (payload['given_name'] != null) _firstNameController.text = payload['given_name'];
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
            _isGoogleSubmitting = false;
          });
        } else {
          if (mounted) setState(() => _isGoogleSubmitting = false);
        }
      } else {
        if (mounted) setState(() => _isGoogleSubmitting = false);
      }
    } else {
      // Login flow
      final success = await auth.googleLogin();
      timeoutTimer.cancel();
      if (didTimeout) return;

      if (mounted) setState(() => _isGoogleSubmitting = false);

      if (success && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      } else if (!success && mounted && auth.errorMessage != null) {
        _showErrorPopup(auth.errorMessage!);
      }
    }
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isLogin ? 'Sign In Failed' : 'Sign Up Failed'),
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    bool success;
    if (_isLogin) {
      success = await auth.login(_emailController.text, _passwordController.text);
    } else {
      success = await auth.register(
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
      );
    }

    if (mounted) setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } else if (!success && mounted && auth.errorMessage != null) {
      _showErrorPopup(auth.errorMessage!);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const UnifiedBackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Beautiful Logo Presentation
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Wooden Card
                  Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('assets/images/wooden_texture.jpg'),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isLogin ? 'Welcome Back' : 'Create Your Space',
                              key: ValueKey(_isLogin ? 'titleLogin' : 'titleRegister'),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isLogin
                                  ? 'Sign in to access your digital Spaces and files'
                                  : 'Sign up to start organizing your digital life',
                              key: ValueKey(_isLogin ? 'subLogin' : 'subRegister'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Error Banner
                          if (auth.errorMessage != null && !_isSubmitting && !_isGoogleSubmitting) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      auth.errorMessage!,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutBack,
                            child: Column(
                              children: [
                                if (!_isLogin) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomTextField(
                                          controller: _firstNameController,
                                          label: 'First Name',
                                          hintText: 'John',
                                          prefixIcon: Icons.person_outline,
                                          isGlass: true,
                                          validator: (val) {
                                            if (!_isLogin && (val == null || val.trim().isEmpty)) return 'Required';
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: CustomTextField(
                                          controller: _lastNameController,
                                          label: 'Last Name',
                                          hintText: 'Doe',
                                          prefixIcon: Icons.person_outline,
                                          isGlass: true,
                                          validator: (val) {
                                            if (!_isLogin && (val == null || val.trim().isEmpty)) return 'Required';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                
                                CompositedTransformTarget(
                                  link: _emailLayerLink,
                                  child: CustomTextField(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
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
                                ),
                                const SizedBox(height: 18),
                                
                                CustomTextField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  label: 'Password',
                                  hintText: '••••••••',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  isGlass: true,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Password is required';
                                    if (!_isLogin && val.length < 6) return 'Password too short (min 6)';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          SizedBox(
                            width: double.infinity,
                            child: CustomButton(
                              text: _isLogin ? 'Sign In' : 'Create Account',
                              isLoading: _isSubmitting,
                              onPressed: _isSubmitting ? null : _handleSubmit,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          if (kIsWeb)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: auth.googleSignIn.signInButton(
                                config: GSIAPButtonConfig(
                                  onSignIn: (credentials) async {
                                    if (!_isLogin) {
                                      final payload = auth.parseJwt(credentials.idToken!);
                                      if (payload != null && mounted) {
                                        setState(() {
                                          if (payload['email'] != null) _emailController.text = payload['email'];
                                          if (payload['given_name'] != null) _firstNameController.text = payload['given_name'];
                                          if (payload['family_name'] != null) _lastNameController.text = payload['family_name'];
                                        });
                                      }
                                    } else {
                                      final success = await auth.googleLoginWithCredentials(credentials);
                                      if (success && mounted) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                                          (route) => false,
                                        );
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
                                icon: _isGoogleSubmitting
                                    ? const SizedBox(width: 24, height: 24, child: Icon(Icons.close, size: 20, color: Colors.white))
                                    : const Icon(Icons.g_mobiledata, size: 28, color: Colors.white),
                                label: Text(
                                  _isGoogleSubmitting ? 'Cancel Sign-in' : (_isLogin ? 'Sign in with Google' : 'Sign up with Google'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                ),
                                onPressed: _isSubmitting
                                    ? null
                                    : (_isGoogleSubmitting ? () => setState(() => _isGoogleSubmitting = false) : _handleGoogleAction),
                              ),
                            ),
                          const SizedBox(height: 24),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin ? 'Don\'t have an account?' : 'Already have an account?',
                                style: const TextStyle(color: Colors.white70, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                              ),
                              TextButton(
                                onPressed: (_isSubmitting || _isGoogleSubmitting) ? null : _toggleMode,
                                child: Text(
                                  _isLogin ? 'Create Account' : 'Sign In',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''
with open('lib/presentation/screens/auth/login_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
