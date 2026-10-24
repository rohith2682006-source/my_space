import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import 'change_password_screen.dart';
import 'two_factor_auth_screen.dart';
import 'active_sessions_screen.dart';
import 'app_lock_screen.dart';
import '../../widgets/settings_container_dialog.dart';
import '../../widgets/settings_group.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScreenScaffold(
      title: 'Security & Credentials',
      subtitle: 'Vault encryption keys, authentication, and connected devices',
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Authentication Group
          SettingsGroup(
            header: 'Authentication & Access',
            footer:
                'Use strong passwords and two-factor authentication to secure your encrypted vault.',
            children: [
              SettingsRow(
                icon: Icons.password_rounded,
                iconColor: AppColors.primary,
                title: 'Change Password',
                subtitle: 'Update your primary master password and encryption phrase',
                onTap: () => Navigator.of(context).push(_slidePageRoute(const ChangePasswordScreen())),
              ),
              SettingsRow(
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Two-Factor Authentication',
                subtitle: 'Protect your account using an authenticator app (TOTP)',
                onTap: () => Navigator.of(context).push(_slidePageRoute(const TwoFactorAuthScreen())),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          // Device & Sessions Group
          SettingsGroup(
            header: 'Devices & App Lock',
            footer:
                'Manage active logins across your desktop, mobile, and web applications.',
            children: [
              SettingsRow(
                icon: Icons.devices_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Active Sessions',
                subtitle: 'Review and revoke active sign-ins on other computers',
                onTap: () => Navigator.of(context).push(_slidePageRoute(const ActiveSessionsScreen())),
              ),
              SettingsRow(
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Biometric Screen Lock',
                subtitle: 'Require Windows Hello / Face ID / Touch ID to unlock Spaces',
                onTap: () => Navigator.of(context).push(_slidePageRoute(const AppLockScreen())),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 70.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Route _slidePageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (c, a, b) => page,
      transitionsBuilder: (c, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(position: slide, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
    );
  }
}

