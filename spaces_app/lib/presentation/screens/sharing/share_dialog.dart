import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/space_model.dart';
import '../../../data/models/file_model.dart';
import '../../../data/models/share_link_model.dart';
import '../../../providers/sharing_provider.dart';
import '../../widgets/top_alert_bar.dart';
import 'my_links_screen.dart';

class ShareDialog extends StatefulWidget {
  final SpaceModel? space;
  final FileModel? file;

  const ShareDialog({super.key, this.space, this.file});

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  String _permission = 'VIEW';
  int? _expiresInDays = 7;
  int? _maxDownloads;
  bool _requirePassword = false;
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isCopied = false;
  ShareLinkModel? _generatedLink;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickShare() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<SharingProvider>(context, listen: false);

    final link = await provider.quickShare(
      fileId: widget.file?.id,
      spaceId: widget.space?.id,
    );

    setState(() {
      _isLoading = false;
      _generatedLink = link;
      _isCopied = true;
    });

    if (mounted && link != null) {
      TopAlertBar.showSuccess(
        context,
        'Instant link generated & copied to clipboard!',
      );
    }
  }

  Future<void> _handleCustomShare() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<SharingProvider>(context, listen: false);

    final link = await provider.createShareLink(
      fileId: widget.file?.id,
      spaceId: widget.space?.id,
      permission: _permission,
      expiresInDays: _expiresInDays,
      maxDownloads: _maxDownloads,
      password: _requirePassword ? _passwordController.text.trim() : null,
    );

    setState(() {
      _isLoading = false;
      _generatedLink = link;
    });

    if (link != null) {
      _copyToClipboard(link.shareUrl);
    }
  }

  void _copyToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    setState(() => _isCopied = true);
    TopAlertBar.showSuccess(context, 'Link copied to clipboard!');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = widget.file != null ? 'Share File' : 'Share Space';
    final targetName = widget.file?.name ?? widget.space?.name ?? 'Resource';

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.share_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            targetName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_generatedLink != null) ...[
                // Generated Link Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Real-Time Link',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Live Now',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _generatedLink!.shareUrl,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                _isCopied
                                    ? Icons.check_circle_rounded
                                    : Icons.copy_rounded,
                                size: 16,
                              ),
                              label: Text(_isCopied ? 'Copied!' : 'Copy Link'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCopied
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                              onPressed: () =>
                                  _copyToClipboard(_generatedLink!.shareUrl),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_generatedLink!.downloadUrl != null)
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 16,
                              ),
                              label: const Text('Direct URL'),
                              onPressed: () => _copyToClipboard(
                                _generatedLink!.downloadUrl!,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    label: const Text('Manage all my links'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyLinksScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                // Quick 1-Tap Share Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        const Color(0xFF8B5CF6).withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '⚡ Real-Time Instant Share',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Generates an active link instantly and copies it to your clipboard with one click.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text('Quick Share & Copy Link'),
                          onPressed: _isLoading ? null : _handleQuickShare,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Toggle for Advanced Security Options
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Advanced Security & Expiry Options',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Icon(
                          _showAdvanced
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
                  // Permission
                  const Text(
                    'Permission',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'VIEW', label: Text('Can View')),
                      ButtonSegment(
                        value: 'DOWNLOAD',
                        label: Text('Can Download'),
                      ),
                      ButtonSegment(value: 'EDIT', label: Text('Can Edit')),
                    ],
                    selected: {_permission},
                    onSelectionChanged: (set) =>
                        setState(() => _permission = set.first),
                  ),
                  const SizedBox(height: 14),

                  // Expiry & Download Limit Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expires In',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int?>(
                              initialValue: _expiresInDays,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('24 Hours'),
                                ),
                                DropdownMenuItem(
                                  value: 7,
                                  child: Text('7 Days'),
                                ),
                                DropdownMenuItem(
                                  value: 30,
                                  child: Text('30 Days'),
                                ),
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('Never'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _expiresInDays = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Download Limit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int?>(
                              initialValue: _maxDownloads,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('Unlimited'),
                                ),
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text('5 times'),
                                ),
                                DropdownMenuItem(
                                  value: 25,
                                  child: Text('25 times'),
                                ),
                                DropdownMenuItem(
                                  value: 100,
                                  child: Text('100 times'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _maxDownloads = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Password Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Require Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Link visitors must enter passphrase',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _requirePassword,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _requirePassword = val),
                  ),

                  if (_requirePassword) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter link passphrase',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Generate Custom Link'),
                      onPressed: _isLoading ? null : _handleCustomShare,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
