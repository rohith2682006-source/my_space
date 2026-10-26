import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:math' as math;
import '../../widgets/unified_back_button.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../main_navigation_screen.dart';
import '../../../data/services/auth_storage.dart';
import 'dart:async';
import 'forgot_password_screen.dart';
import '../../../core/services/app_update_service.dart';

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final strokeWidth = w * 0.22;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Red arc: top-left to top-right
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.5, false, redPaint);
    // Blue arc: right side
    canvas.drawArc(rect, -math.pi * 0.25, math.pi * 0.5, false, bluePaint);
    // Green arc: bottom
    canvas.drawArc(rect, math.pi * 0.25, math.pi * 0.5, false, greenPaint);
    // Yellow arc: bottom-left
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 0.5, false, yellowPaint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.5 - strokeWidth / 2, w * 0.56, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _buildGoogleLogo() {
  return Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    padding: const EdgeInsets.all(2.5),
    child: CustomPaint(
      size: const Size(17, 17),
      painter: _GoogleLogoPainter(),
    ),
  );
}

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

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  Timer? _resumeCancelTimer;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  final _passwordFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  final LayerLink _emailLayerLink = LayerLink();
  final GlobalKey _emailFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedAccounts();

    _emailFocusNode.addListener(_onEmailFocusOrTextChanged);
    _emailController.addListener(_onEmailFocusOrTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
      if (mounted) AppUpdateService.checkForUpdates(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isGoogleSubmitting) {
        // When user switches back to the app from the browser:
        // If login succeeded, OAuth redirect responds in ~1-2 seconds.
        // If user cancelled/closed the browser page, cancel quickly (within 2.5s)
        // so the user is never left waiting indefinitely.
        _resumeCancelTimer?.cancel();
        _resumeCancelTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && _isGoogleSubmitting) {
            _cancelGoogleAction();
          }
        });
      }
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _resumeCancelTimer?.cancel();
    }
  }

  void _cancelGoogleAction() {
    _resumeCancelTimer?.cancel();
    if (mounted) {
      setState(() => _isGoogleSubmitting = false);
    }
    context.read<AuthProvider>().cancelGoogleSignIn();
  }

  void _onEmailFocusOrTextChanged() {
    if (!_isLogin || _savedAccounts.isEmpty) {
      _hideOverlay();
      return;
    }

    if (_emailFocusNode.hasFocus) {
      if (_emailController.text.isEmpty) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    } else {
      _hideOverlay();
    }
  }

  Widget _buildSavedAccountTile(Map<String, dynamic> acc) {
    final initials = (acc['firstName'] ?? 'U').toString().trim().isNotEmpty
        ? (acc['firstName'] ?? 'U').toString().trim().substring(0, 1).toUpperCase()
        : 'U';
    final fullName = '${acc['firstName'] ?? ''} ${acc['lastName'] ?? ''}'.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'User';
    final email = acc['email'] ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          _hideOverlay();

          final localAuth = LocalAuthentication();
          bool didAuthenticate = false;
          try {
            didAuthenticate = await localAuth.authenticate(
              localizedReason:
                  'Please authenticate to sign in to $email',
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
                final isNetworkError = auth.errorMessage?.toLowerCase().contains('network') == true ||
                    auth.errorMessage?.toLowerCase().contains('connection') == true ||
                    auth.errorMessage?.toLowerCase().contains('failed host lookup') == true;

                if (!isNetworkError) {
                  // The session has truly expired or was revoked. Update storage so stale token isn't reused.
                  await AuthStorage.updateSavedAccountToken(
                    acc['email'] ?? '',
                    null,
                  );
                  await _loadSavedAccounts();
                }

                if (mounted) {
                  auth.clearError();
                  _emailController.text = acc['email'] ?? '';
                  _passwordController.clear();
                  _passwordFocusNode.requestFocus();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isNetworkError
                            ? 'Network error. Please check your internet connection.'
                            : 'Session expired for $email. Please enter your password to sign in.',
                      ),
                      backgroundColor: isNetworkError ? AppColors.error : AppColors.primary,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8B5CF6),
                      Color(0xFF6D28D9),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 16,
                  color: Color(0xFFA78BFA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    if (!_isLogin || _savedAccounts.isEmpty || _emailController.text.isNotEmpty) return;

    final accounts = List<Map<String, dynamic>>.from(_savedAccounts);
    if (accounts.isEmpty) return;

    final renderBox = _emailFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldWidth = renderBox?.size.width ?? 380.0;
    final fieldHeight = renderBox?.size.height ?? 86.0;

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
              width: fieldWidth,
              child: CompositedTransformFollower(
                link: _emailLayerLink,
                showWhenUnlinked: false,
                offset: Offset(0, fieldHeight + 6),
                child: Material(
                  color: Colors.transparent,
                  elevation: 12,
                  borderRadius: BorderRadius.circular(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xF518152E),
                              Color(0xF5110E24),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withOpacity(0.28),
                              blurRadius: 32,
                              spreadRadius: 1,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.65),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.manage_accounts_rounded,
                                      size: 14,
                                      color: Color(0xFFA78BFA),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SAVED ACCOUNTS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFA78BFA),
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const Spacer(),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: _hideOverlay,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 1,
                              color: Colors.white.withOpacity(0.08),
                            ),
                            ...accounts.map((acc) => _buildSavedAccountTile(acc)),
                          ],
                        ),
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
    WidgetsBinding.instance.removeObserver(this);
    _resumeCancelTimer?.cancel();
    _hideOverlay();
    _emailFocusNode.removeListener(_onEmailFocusOrTextChanged);
    _emailController.removeListener(_onEmailFocusOrTextChanged);
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

    if (!_isLogin) {
      // Signup flow
      final credentials = await auth.getGoogleSignInCredentials();
      _resumeCancelTimer?.cancel();
      if (!mounted || !_isGoogleSubmitting) return;

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
      _resumeCancelTimer?.cancel();
      if (!mounted || !_isGoogleSubmitting) return;

      if (mounted) setState(() => _isGoogleSubmitting = false);

      if (success && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      } else if (!success &&
          mounted &&
          auth.errorMessage != null &&
          !auth.errorMessage!.toLowerCase().contains('cancel')) {
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
    _hideOverlay();
    context.read<AuthProvider>().clearError();
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    // Beautiful Logo Presentation with glowing aura
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFA78BFA),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.55),
                              blurRadius: 36,
                              spreadRadius: 4,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Ultra-Premium Dark Glassmorphic Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 450),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xF018152E), // Deep cyber-obsidian
                                Color(0xF0110E24),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withOpacity(0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.22),
                                blurRadius: 40,
                                spreadRadius: 0,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 30,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 32,
                            ),
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
                                      style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: Colors.white,
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
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w400,
                                        height: 1.4,
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
                                          key: _emailFieldKey,
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
                                                  _savedAccounts.isNotEmpty &&
                                                  _emailController.text.isEmpty) {
                                                _showOverlay();
                                              } else {
                                                _hideOverlay();
                                              }
                                            },
                                            onChanged: (val) {
                                              if (val.isNotEmpty) {
                                                _hideOverlay();
                                              } else if (_isLogin &&
                                                  _savedAccounts.isNotEmpty &&
                                                  _emailFocusNode.hasFocus) {
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
                                              child: Text(
                                                'Forgot Password?',
                                                style: GoogleFonts.outfit(
                                                  color: const Color(0xFFA78BFA),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8B5CF6),
                                          Color(0xFF6D28D9),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF7C3AED).withOpacity(0.4),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting ? null : _handleSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              _isLogin ? 'Sign In' : 'Create Account',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
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
                                    Container(
                                      width: double.infinity,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F1B38).withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.12),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: _isSubmitting
                                              ? null
                                              : (_isGoogleSubmitting
                                                  ? _cancelGoogleAction
                                                  : _handleGoogleAction),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (_isGoogleSubmitting) ...[
                                                  const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Connecting...',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.close_rounded,
                                                          size: 14,
                                                          color: Colors.redAccent.shade100,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Cancel',
                                                          style: GoogleFonts.outfit(
                                                            color: Colors.redAccent.shade100,
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ] else ...[
                                                  _buildGoogleLogo(),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    _isLogin ? 'Sign in with Google' : 'Sign up with Google',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isLogin
                                            ? "Don't have an account?"
                                            : 'Already have an account?',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton(
                                        onPressed:
                                            (_isSubmitting ||
                                                _isGoogleSubmitting)
                                            ? null
                                            : _toggleMode,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          _isLogin
                                              ? 'Create Account'
                                              : 'Sign In',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFA78BFA),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
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
