import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/files_provider.dart';
import '../../../providers/ai_credits_provider.dart';
import '../../../providers/plans_provider.dart';
import '../../widgets/settings_container_dialog.dart';
import '../../widgets/settings_group.dart';
import '../auth/login_screen.dart';
import '../plans/plans_screen.dart';
import '../ai/ai_usage_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../settings/security_settings_screen.dart';
import '../settings/utilities_settings_screen.dart';
import '../settings/app_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FilesProvider>(context, listen: false).fetchStorageStats();
      Provider.of<AiCreditsProvider>(context, listen: false).fetchBalance();
      final plansProvider = Provider.of<PlansProvider>(context, listen: false);
      plansProvider.fetchPlans();
      plansProvider.fetchCurrentSubscription();
    });
  }

  void _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Sign Out',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out of your account on this device?',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actionsPadding: const EdgeInsets.only(right: 18, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await Provider.of<AuthProvider>(context, listen: false).logout();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final filesProvider = Provider.of<FilesProvider>(context);
    final aiProvider = Provider.of<AiCreditsProvider>(context);
    final stats = filesProvider.storageStats;

    final totalUsed = stats != null
        ? FileHelper.formatBytes(stats.totalUsedBytes)
        : '0 B';
    final storageLimit = stats != null
        ? FileHelper.formatBytes(stats.storageLimitBytes)
        : '5 GB';
    final usagePercent = (stats?.usagePercentage ?? 0.0).clamp(0.0, 100.0);

    return SettingsScreenScaffold(
      title: 'Settings',
      subtitle: 'Manage account, security, preferences & storage',
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero User Banner
          _buildHeroUserBanner(auth, isDark)
              .animate()
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 20),

          // 2. Metrics & Telemetry Strip (Cloud Storage & AI Credits)
          _buildMetricsStrip(
            isDark,
            totalUsed,
            storageLimit,
            usagePercent,
            aiProvider.balance?.balance ?? aiProvider.currentCredits,
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 50.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 28),

          // 3. Preferences & Utilities Group
          SettingsGroup(
            header: 'Preferences & System',
            children: [
              SettingsRow(
                icon: Icons.tune_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'App Preferences',
                subtitle: 'Theme modes, notifications, and local cached files',
                onTap: () => Navigator.of(context).push(
                  _slidePageRoute(const AppSettingsScreen()),
                ),
              ),
              SettingsRow(
                icon: Icons.handyman_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Tools & Utilities',
                subtitle: 'Offline documents, dropzones, and external file request links',
                onTap: () => Navigator.of(context).push(
                  _slidePageRoute(const UtilitiesSettingsScreen()),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 90.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          // 4. Security & Privacy Group
          SettingsGroup(
            header: 'Security & Privacy',
            children: [
              SettingsRow(
                icon: Icons.shield_rounded,
                iconColor: AppColors.accent,
                title: 'Security & Credentials',
                subtitle: 'Vault passwords, Two-Factor Authentication, and active devices',
                onTap: () => Navigator.of(context).push(
                  _slidePageRoute(const SecuritySettingsScreen()),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 130.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          // 5. Intelligence & Subscriptions Group
          SettingsGroup(
            header: 'Intelligence & Plans',
            children: [
              SettingsRow(
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'AI Intelligence & Models',
                subtitle: 'Token usage breakdown, model configurations & indexing health',
                onTap: () => Navigator.of(context).push(
                  _slidePageRoute(const AiUsageScreen()),
                ),
              ),
              SettingsRow(
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Subscription & Tier',
                subtitle: 'Upgrade quota, view invoice history, and manage plans',
                onTap: () => Navigator.of(context).push(
                  _slidePageRoute(const PlansScreen()),
                ),
              ),
              if (auth.user?.role == 'ADMIN')
                SettingsRow(
                  icon: Icons.admin_panel_settings_rounded,
                  iconColor: AppColors.error,
                  title: 'Administration Console',
                  subtitle: 'System health, global audit logs, and user directory',
                  onTap: () => Navigator.of(context).push(
                    _slidePageRoute(const AdminDashboardScreen()),
                  ),
                ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 170.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          // 6. Account & Session Group
          SettingsGroup(
            header: 'Account Session',
            children: [
              SettingsRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                title: 'Sign Out of Spaces',
                subtitle: 'Safely disconnect your account session from this client',
                isDestructive: true,
                showChevron: false,
                onTap: _confirmSignOut,
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 210.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // Footer
          Center(
            child: Column(
              children: [
                Text(
                  'Spaces Desktop v1.0.0 Production',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zero-Knowledge Client-Side Encryption • All Rights Reserved',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextTertiary.withValues(alpha: 0.7)
                        : AppColors.lightTextTertiary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: 250.ms),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroUserBanner(AuthProvider auth, bool isDark) {
    final fullName = '${auth.user?.firstName ?? 'Spaces'} ${auth.user?.lastName ?? 'Member'}'.trim();
    final email = auth.user?.email ?? 'vault.user@spaces.local';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B1233).withValues(alpha: 0.85)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.6)
              : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 18),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: isDark ? 0.4 : 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'End-to-End Encrypted Cloud Vault',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.9)
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip(
    bool isDark,
    String totalUsed,
    String storageLimit,
    double usagePercent,
    int aiCredits,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B1233).withValues(alpha: 0.70)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.5)
              : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Storage Metric
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Storage',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '$totalUsed / $storageLimit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (usagePercent / 100).clamp(0.01, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vertical divider
          Container(
            height: 38,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),

          // AI Balance Metric
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'AI Intelligence',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$aiCredits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'credits',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
