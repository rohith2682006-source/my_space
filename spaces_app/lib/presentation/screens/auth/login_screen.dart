import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
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
import 'forgot_password_screen.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base dark gradient - fills entire space
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF020617)],
            ),
          ),
        ),

        // Animated grid lines (tech feel)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _GridPainter(_controller.value),
              child: const SizedBox.expand(),
            );
          },
        ),
        // Floating particles
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _ParticlePainter(_controller.value),
              child: const SizedBox.expand(),
            );
          },
        ),
        // Subtle dark overlay
        Container(color: Colors.black.withOpacity(0.15)),
        widget.child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const spacing = 50.0;
    final offset = (progress * spacing) % spacing;

    // Horizontal lines
    for (
      double y = -spacing + offset;
      y < size.height + spacing;
      y += spacing
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = -spacing + offset; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.progress != progress;
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  static const _seeds = [
    [0.1, 0.2, 0.3, 2.0],
    [0.3, 0.5, 0.5, 3.0],
    [0.5, 0.1, 0.7, 1.5],
    [0.7, 0.7, 0.2, 2.5],
    [0.9, 0.3, 0.8, 4.0],
    [0.2, 0.8, 0.6, 1.8],
    [0.6, 0.9, 0.4, 3.5],
    [0.8, 0.6, 0.1, 2.2],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _seeds) {
      final t = (progress + s[2]) % 1.0;
      final x = s[0] * size.width + math.sin(t * 2 * math.pi) * 40;
      final y = (s[1] - t * 0.6) * size.height;
      final opacity = (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.5;
      final radius = 1.5 + s[3] * 0.5;

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      if (_emailFocusNode.hasFocus && _isLogin && _savedAccounts.isNotEmpty) {
        _showOverlay();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  Widget _buildSavedAccountTile(Map<String, dynamic> acc) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        _hideOverlay();

        final localAuth = LocalAuthentication();
        bool didAuthenticate = false;
        try {
          didAuthenticate = await localAuth.authenticate(
            localizedReason:
                'Please authenticate to sign in to ${acc['email']}',
          );
        } catch (e) {
          if (mounted) {
            _showErrorPopup('Authentication failed: $e');
          }
          return;
        }

        if (didAuthenticate && mounted) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          auth.clearError();
          final refreshToken = acc['refreshToken'];
          if (refreshToken != null && refreshToken.toString().isNotEmpty) {
            final success = await auth.loginWithRefreshToken(
              refreshToken.toString(),
              email: acc['email'],
            );
            if (!success && mounted) {
              // The session has expired or was revoked. Update storage so stale token isn't reused.
              await AuthStorage.updateSavedAccountToken(
                acc['email'] ?? '',
                null,
              );
              await _loadSavedAccounts();

              if (mounted) {
                auth.clearError();
                _emailController.text = acc['email'] ?? '';
                _passwordController.clear();
                _passwordFocusNode.requestFocus();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Session expired for ${acc['email']}. Please enter your password to sign in.',
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            } else if (success && mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
              );
            }
          } else {
            // No saved token — smoothly autofill email and focus password
            auth.clearError();
            _emailController.text = acc['email'] ?? '';
            _passwordController.clear();
            _passwordFocusNode.requestFocus();
          }
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.25),
                child: Text(
                  (acc['firstName'] ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${acc['firstName'] ?? ''} ${acc['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      acc['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final accounts = List<Map<String, dynamic>>.from(_savedAccounts);
    if (accounts.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideOverlay,
                child: Container(),
              ),
            ),
            Positioned(
              width: 380,
              child: CompositedTransformFollower(
                link: _emailLayerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 90),
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B).withOpacity(0.97),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Accounts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _hideOverlay(),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...accounts.map((acc) => _buildSavedAccountTile(acc)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
        _savedAccounts = List<Map<String, dynamic>>.from(accounts);
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
      success = await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
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
    context.read<AuthProvider>().clearError();
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
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
                    const SizedBox(height: 28),

                    // Modern Auth Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xAA1E293B)
                            : const Color(0xAAFFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      _isLogin
                                          ? 'Welcome Back'
                                          : 'Create Your Space',
                                      key: ValueKey(
                                        _isLogin
                                            ? 'titleLogin'
                                            : 'titleRegister',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
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
                                      key: ValueKey(
                                        _isLogin ? 'subLogin' : 'subRegister',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Error Banner
                                  if (auth.errorMessage != null &&
                                      !_isSubmitting &&
                                      !_isGoogleSubmitting) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(
                                          0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.error.withOpacity(
                                            0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            color: AppColors.error,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              auth.errorMessage!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              auth.clearError();
                                            },
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
                                                  controller:
                                                      _firstNameController,
                                                  label: 'First Name',
                                                  hintText: 'John',
                                                  prefixIcon:
                                                      Icons.person_outline,
                                                  isGlass: true,
                                                  validator: (val) {
                                                    if (!_isLogin &&
                                                        (val == null ||
                                                            val
                                                                .trim()
                                                                .isEmpty)) {
                                                      return 'Required';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: CustomTextField(
                                                  controller:
                                                      _lastNameController,
                                                  label: 'Last Name',
                                                  hintText: 'Doe',
                                                  prefixIcon:
                                                      Icons.person_outline,
                                                  isGlass: true,
                                                  validator: (val) {
                                                    if (!_isLogin &&
                                                        (val == null ||
                                                            val
                                                                .trim()
                                                                .isEmpty)) {
                                                      return 'Required';
                                                    }
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
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            isGlass: true,
                                            onTap: () {
                                              if (_isLogin &&
                                                  _savedAccounts.isNotEmpty) {
                                                _showOverlay();
                                              }
                                            },
                                            validator: (val) {
                                              if (val == null ||
                                                  val.trim().isEmpty) {
                                                return 'Email is required';
                                              }
                                              if (!val.contains('@')) {
                                                return 'Enter a valid email';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 18),

                                        CustomTextField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocusNode,
                                          label: 'Password',
                                          hintText: '********',
                                          prefixIcon:
                                              Icons.lock_outline_rounded,
                                          isPassword: true,
                                          isGlass: true,
                                          validator: (val) {
                                            if (val == null || val.isEmpty) {
                                              return 'Password is required';
                                            }
                                            if (!_isLogin && val.length < 6) {
                                              return 'Password too short (min 6)';
                                            }
                                            return null;
                                          },
                                        ),
                                        if (_isLogin) ...[
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () async {
                                                final resetSuccess =
                                                    await Navigator.push<bool>(
                                                  context,
                                                  PageRouteBuilder(
                                                    transitionDuration:
                                                        const Duration(
                                                          milliseconds: 280,
                                                        ),
                                                    reverseTransitionDuration:
                                                        const Duration(
                                                          milliseconds: 220,
                                                        ),
                                                    pageBuilder:
                                                        (
                                                          context,
                                                          animation,
                                                          secondaryAnimation,
                                                        ) => ForgotPasswordScreen(
                                                          initialEmail:
                                                              _emailController
                                                                  .text
                                                                  .trim(),
                                                        ),
                                                    transitionsBuilder:
                                                        (
                                                          context,
                                                          animation,
                                                          secondaryAnimation,
                                                          child,
                                                        ) {
                                                          final curved =
                                                              CurvedAnimation(
                                                                parent:
                                                                    animation,
                                                                curve: Curves
                                                                    .easeOutCubic,
                                                                reverseCurve: Curves
                                                                    .easeInCubic,
                                                              );
                                                          return FadeTransition(
                                                            opacity: curved,
                                                            child: child,
                                                          );
                                                        },
                                                  ),
                                                );
                                                if (!mounted) return;
                                                await _loadSavedAccounts();
                                                if (mounted && resetSuccess == true) {
                                                    _passwordController.clear();
                                                    _passwordFocusNode.requestFocus();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: const Text(
                                                          'Password reset successfully! Please sign in with your new password.',
                                                        ),
                                                        backgroundColor: AppColors.success,
                                                        behavior: SnackBarBehavior.floating,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                              },
                                              child: const Text(
                                                'Forgot Password?',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black,
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  SizedBox(
                                    width: double.infinity,
                                    child: CustomButton(
                                      text: _isLogin
                                          ? 'Sign In'
                                          : 'Create Account',
                                      isLoading: _isSubmitting,
                                      onPressed: _isSubmitting
                                          ? null
                                          : _handleSubmit,
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
                                              final payload = auth.parseJwt(
                                                credentials.idToken!,
                                              );
                                              if (payload != null && mounted) {
                                                setState(() {
                                                  if (payload['email'] !=
                                                      null) {
                                                    _emailController.text =
                                                        payload['email'];
                                                  }
                                                  if (payload['given_name'] !=
                                                      null) {
                                                    _firstNameController.text =
                                                        payload['given_name'];
                                                  }
                                                  if (payload['family_name'] !=
                                                      null) {
                                                    _lastNameController.text =
                                                        payload['family_name'];
                                                  }
                                                });
                                              }
                                            } else {
                                              final success = await auth
                                                  .googleLoginWithCredentials(
                                                    credentials,
                                                  );
                                              if (success && mounted) {
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const MainNavigationScreen(),
                                                  ),
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
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: Icon(
                                                  Icons.close,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.g_mobiledata,
                                                size: 28,
                                                color: Colors.white,
                                              ),
                                        label: Text(
                                          _isGoogleSubmitting
                                              ? 'Cancel Sign-in'
                                              : (_isLogin
                                                    ? 'Sign in with Google'
                                                    : 'Sign up with Google'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.1),
                                        ),
                                        onPressed: _isSubmitting
                                            ? null
                                            : (_isGoogleSubmitting
                                                  ? () => setState(
                                                      () =>
                                                          _isGoogleSubmitting =
                                                              false,
                                                    )
                                                  : _handleGoogleAction),
                                      ),
                                    ),
                                  const SizedBox(height: 24),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isLogin
                                            ? 'Don\'t have an account?'
                                            : 'Already have an account?',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            (_isSubmitting ||
                                                _isGoogleSubmitting)
                                            ? null
                                            : _toggleMode,
                                        child: Text(
                                          _isLogin
                                              ? 'Create Account'
                                              : 'Sign In',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                    // Saved accounts overlay handles saved accounts
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
