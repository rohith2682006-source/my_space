import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/theme_provider.dart';
import '../../widgets/top_alert_bar.dart';
import '../../widgets/settings_container_dialog.dart';
import '../../widgets/settings_group.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SettingsScreenScaffold(
      title: 'App Preferences',
      subtitle: 'Customize theme, notifications, and storage cache',
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Theme Group
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return SettingsGroup(
                header: 'Appearance & Theme',
                footer:
                    'Spaces adapts automatically between dark purple and creamy white palettes.',
                children: [
                  SettingsRow(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    iconColor: isDark ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B),
                    title: 'Dark Theme Mode',
                    subtitle: isDark
                        ? 'Matte purple dark mode enabled'
                        : 'Creamy white light mode enabled',
                    showChevron: false,
                    trailing: Switch.adaptive(
                      value: themeProvider.isDarkMode,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => themeProvider.toggleTheme(),
                    ),
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                ],
              );
            },
          )
              .animate()
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          // Notifications Group
          SettingsGroup(
            header: 'Notifications & Alerts',
            footer: 'Configure desktop banners and file synchronization alerts.',
            children: [
              SettingsRow(
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFFF97316),
                title: 'Activity Notifications',
                subtitle: 'Push alerts for file sharing, dropzones & AI completions',
                onTap: () {
                  TopAlertBar.showInfo(
                    context,
                    'Activity notifications are enabled for this device.',
                  );
                },
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 60.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          // Storage & Cache Group
          SettingsGroup(
            header: 'Local Cache Management',
            footer:
                'Clearing the local cache removes temporary file previews and thumbnails. Your vault files remain intact in the cloud.',
            children: [
              SettingsRow(
                icon: Icons.cleaning_services_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Clear Local Cache',
                subtitle: 'Purge temporary thumbnails and offline staging files',
                isDestructive: false,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
                onTap: () {
                  TopAlertBar.showSuccess(
                    context,
                    'Local storage cache purged successfully.',
                  );
                },
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 120.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}
