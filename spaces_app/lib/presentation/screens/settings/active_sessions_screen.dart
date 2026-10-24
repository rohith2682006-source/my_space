import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/top_alert_bar.dart';
import '../../widgets/settings_container_dialog.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  bool _isLoading = false;

  Future<void> _logoutAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out All Other Devices'),
        content: const Text(
          'This will sign out all other devices currently logged into your account. Your current session will remain active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out All'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    // Call the logoutAll endpoint
    final response = await ApiClient.post(ApiEndpoints.logoutAll);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.success) {
      TopAlertBar.showSuccess(
        context,
        'Successfully signed out of all other devices.',
      );
    } else {
      TopAlertBar.showError(
        context,
        response.message ?? 'Failed to sign out of other devices.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;

    return SettingsScreenScaffold(
      title: 'Active Sessions',
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active now',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'This Device',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Other Devices',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'If you notice any unfamiliar devices or want to secure your account, you can sign out of all other sessions.',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Sign Out All Other Devices',
              icon: Icons.exit_to_app_rounded,
              color: AppColors.error,
              isLoading: _isLoading,
              onPressed: _logoutAll,
            ),
          ),
        ],
      ),
    );
  }
}
