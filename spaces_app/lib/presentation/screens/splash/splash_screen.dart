import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../auth/login_screen.dart';
import '../main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await Future.delayed(const Duration(milliseconds: 1400));
    await auth.checkAuth();

    if (!mounted) return;

    if (auth.isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      final isAppLockEnabled = prefs.getBool('isAppLockEnabled') ?? false;

      if (isAppLockEnabled) {
        final localAuth = LocalAuthentication();
        bool authenticated = false;
        try {
          authenticated = await localAuth.authenticate(
            localizedReason: 'Unlock Spaces',
            biometricOnly: false,
            persistAcrossBackgrounding: true,
          );
        } catch (e) {
          // If auth fails or throws (e.g. user cancels), stay on splash screen or exit
          return;
        }

        if (!authenticated) {
          // Authentication failed/canceled
          return;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo Mark
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset('assets/icon/app_icon.png', width: 88, height: 88),
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .shimmer(delay: 500.ms, duration: 800.ms),
            const SizedBox(height: 24),
            // Title
            const Text(
              'SPACES',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Store it once. Find it instantly.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
