import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/space_model.dart';
import '../../providers/spaces_provider.dart';

class FolderUnlockDialog extends StatefulWidget {
  final SpaceModel space;
  final String? promptAction;

  const FolderUnlockDialog({
    super.key,
    required this.space,
    this.promptAction,
  });

  @override
  State<FolderUnlockDialog> createState() => _FolderUnlockDialogState();
}

class _FolderUnlockDialogState extends State<FolderUnlockDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter folder password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final spacesProvider = context.read<SpacesProvider>();
      final success = await spacesProvider.verifySpacePassword(
        widget.space.id,
        password,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = spacesProvider.errorMessage ?? 'Incorrect password. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top icon & close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: secondaryText,
                      ),
                      splashRadius: 20,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Unlock Folder',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Folder "${widget.space.name}" is locked with a password. Please enter your password to ${widget.promptAction ?? 'access files and chat'}.',
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Password Input
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 14),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Enter folder password',
                    hintStyle: TextStyle(color: secondaryText, fontSize: 14),
                    prefixIcon: Icon(
                      Icons.key_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: secondaryText,
                      ),
                      splashRadius: 20,
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_open_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Unlock & Continue',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showFolderUnlockDialog(
  BuildContext context,
  SpaceModel space, {
  String? promptAction,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => FolderUnlockDialog(
      space: space,
      promptAction: promptAction,
    ),
  );
  return result == true;
}
