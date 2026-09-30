import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/spaces_provider.dart';
import '../../../data/services/auth_storage.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/top_alert_bar.dart';
import '../auth/login_screen.dart';

class CreateSpaceDialog extends StatefulWidget {
  const CreateSpaceDialog({super.key});

  @override
  State<CreateSpaceDialog> createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends State<CreateSpaceDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIcon = '📁';
  String _selectedColor = '#6366F1';
  bool _isPrivate = true;
  bool _isLoading = false;

  final List<String> _icons = [
    '📁',
    '🎓',
    '💻',
    '✈️',
    '🔒',
    '📚',
    '🎨',
    '💼',
    '🔬',
    '🎵',
    '🏠',
    '⚡',
    '🎬',
    '🚀',
    '💡',
    '📝',
  ];

  final List<Map<String, String>> _colors = [
    {'name': 'Indigo', 'hex': '#6366F1'},
    {'name': 'Cyan', 'hex': '#06B6D4'},
    {'name': 'Emerald', 'hex': '#10B981'},
    {'name': 'Amber', 'hex': '#F59E0B'},
    {'name': 'Pink', 'hex': '#EC4899'},
    {'name': 'Purple', 'hex': '#8B5CF6'},
    {'name': 'Rose', 'hex': '#F43F5E'},
    {'name': 'Blue', 'hex': '#3B82F6'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  }

  Future<void> _handleCreate() async {
    if (_nameController.text.trim().isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await AuthStorage.getAccessToken();
    if (!auth.isAuthenticated || token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please sign in again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final spacesProvider = Provider.of<SpacesProvider>(context, listen: false);

    final success = await spacesProvider.createSpace(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      icon: _selectedIcon,
      color: _selectedColor,
      isPrivate: _isPrivate,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      final error =
          spacesProvider.errorMessage ??
          'Failed to create Space. Please try again.';
      if (error.toLowerCase().contains('token') ||
          error.toLowerCase().contains('unauthorized')) {
        await AuthStorage.clearAll();
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }
      TopAlertBar.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFA1E293B) : Colors.white,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Space',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Space Name
              CustomTextField(
                controller: _nameController,
                label: 'Space Name',
                hintText: 'e.g. College 2026, Projects, Travel',
              ),
              const SizedBox(height: 16),
              // Icon Picker
              const Text(
                'Choose Icon',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((icon) {
                  final isSelected = _selectedIcon == icon;
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = icon),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _parseHex(_selectedColor).withOpacity(0.2)
                            : (isDark
                                  ? AppColors.darkCard
                                  : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? _parseHex(_selectedColor)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              // Color Picker
              const Text(
                'Theme Color',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colors.map((colorMap) {
                  final hex = colorMap['hex']!;
                  final color = _parseHex(hex);
                  final isSelected = _selectedColor == hex;
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = hex),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              // Description
              CustomTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hintText: 'What belongs in this Space?',
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              // Privacy Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Private Space',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _isPrivate
                      ? 'Only you can access this Space'
                      : 'Anyone with link can view',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                value: _isPrivate,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Create Space',
                      isLoading: _isLoading,
                      color: _parseHex(_selectedColor),
                      onPressed: _handleCreate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
