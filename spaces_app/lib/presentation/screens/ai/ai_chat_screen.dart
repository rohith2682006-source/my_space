import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/unified_back_button.dart';
import '../../widgets/navigation_tab_controller.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/file_model.dart';
import '../../../providers/ai_credits_provider.dart';
import '../../../providers/ai_chat_provider.dart';
import '../../../providers/spaces_provider.dart';
import '../../../providers/files_provider.dart';
import '../../widgets/file_viewer_modal.dart';
import '../../widgets/top_alert_bar.dart';
import 'ai_usage_screen.dart';
import '../plans/plans_screen.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../data/models/space_model.dart';
import '../../widgets/folder_unlock_dialog.dart';

class ThreeDotsLoadingIndicator extends StatefulWidget {
  final Color color;
  final double dotSize;

  const ThreeDotsLoadingIndicator({
    super.key,
    this.color = AppColors.accent,
    this.dotSize = 7.0,
  });

  @override
  State<ThreeDotsLoadingIndicator> createState() => _ThreeDotsLoadingIndicatorState();
}

class _ThreeDotsLoadingIndicatorState extends State<ThreeDotsLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final t = (_controller.value - (index * 0.2)) % 1.0;
            final bounce = math.sin(t * math.pi);
            final scale = 0.65 + (0.35 * bounce.clamp(0.0, 1.0));
            final opacity = 0.35 + (0.65 * bounce.clamp(0.0, 1.0));

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: widget.dotSize * scale,
              height: widget.dotSize * scale,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class AiChatScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialMode;
  final bool embedded;
  const AiChatScreen({
    super.key,
    this.initialQuery,
    this.initialMode,
    this.embedded = false,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Uint8List? _attachedImageBytes;

  static const _suggestions = [
    'Help me brainstorm and organize my ideas',
    'Summarize my project planning notes',
    'Find my notes about the project budget',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final aiChatProvider = context.read<AiChatProvider>();
      context.read<AiCreditsProvider>().fetchBalance();

      if (widget.initialMode != null) {
        aiChatProvider.setSearchMode(widget.initialMode!);
      }

      if (widget.initialQuery != null &&
          widget.initialQuery!.trim().isNotEmpty) {
        _handleSendMessage(widget.initialQuery);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage([String? suggestedMessage]) async {
    final aiChat = context.read<AiChatProvider>();
    final credits = context.read<AiCreditsProvider>();

    final text = (suggestedMessage ?? _messageController.text).trim();
    if (text.isEmpty && _attachedImageBytes == null) return;

    final image = _attachedImageBytes;
    setState(() {
      _attachedImageBytes = null;
      _messageController.clear();
    });

    _scrollToBottom();

    await aiChat.sendMessage(
      text,
      imageBytes: image,
      onCreditsUpdated: (remaining) {
        credits.updateBalanceLocally(remaining);
      },
      onCreditsExhausted: () {
        _showCreditsExhaustedDialog();
      },
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _deselectAttachedSpace() {
    final aiChat = context.read<AiChatProvider>();
    final spacesProvider = context.read<SpacesProvider>();
    final spaceId = aiChat.attachedSpaceId ?? aiChat.selectedSpaceId;
    if (spaceId != null) {
      spacesProvider.lockSpace(spaceId);
    }
    aiChat.removeAttachedSpace();
  }

  void _showCreditsExhaustedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('AI Credits Exhausted'),
          ],
        ),
        content: const Text(
          'You have run out of AI credits for this billing period. Upgrade your plan or purchase an instant credit pack to continue using AI search.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlansScreen()),
              );
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _attachedImageBytes = result.files.single.bytes;
        });
        _focusNode.requestFocus();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        TopAlertBar.showError(context, 'Could not attach image: $e');
      }
    }
  }

  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Add Attachments',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 22),
                ),
                title: Text(
                  '1. Add file from system',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
                subtitle: Text(
                  'Select files from your device to query and analyze',
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFileFromSystem();
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: AppColors.accent, size: 22),
                ),
                title: Text(
                  '2. Add file from space',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
                subtitle: Text(
                  'Select specific documents or notes from your spaces',
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFilePickerDialog();
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image_rounded, color: Colors.teal, size: 22),
                ),
                title: Text(
                  'Add Image (Vision AI)',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
                subtitle: Text(
                  'Extract text or ask questions from photos and screenshots',
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_comment_outlined, color: Color(0xFF8B5CF6), size: 22),
                ),
                title: Text(
                  'Start New Chat',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
                subtitle: Text(
                  'Begin a fresh conversation thread',
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AiChatProvider>().startNewChat();
                  _messageController.clear();
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.blue, size: 22),
                ),
                title: Text(
                  'Chat History',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
                subtitle: Text(
                  'Browse and resume previous conversations',
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChatHistorySheet(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFileFromSystem() async {
    final aiChat = context.read<AiChatProvider>();
    final spacesProvider = context.read<SpacesProvider>();
    final filesProvider = context.read<FilesProvider>();

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final spaces = spacesProvider.spaces;

        final activeSpaceId = aiChat.attachedSpaceId ??
            aiChat.selectedSpaceId ??
            (spaces.isNotEmpty ? spaces.first.id : null);

        if (activeSpaceId != null && spaces.isNotEmpty) {
          final targetSpace = spaces.firstWhere(
            (s) => s.id == activeSpaceId,
            orElse: () => spaces.first,
          );
          if (targetSpace.isPrivate && !spacesProvider.isSpaceUnlocked(targetSpace.id)) {
            final unlocked = await showFolderUnlockDialog(
              context,
              targetSpace,
              promptAction: 'unlock and upload files to this folder',
            );
            if (!unlocked) {
              if (mounted) {
                TopAlertBar.showInfo(
                  context,
                  'Folder "${targetSpace.name}" is locked. Password required to upload files.',
                );
              }
              return;
            }
          }
        }

        int attachedCount = 0;
        for (final file in result.files) {
          if (file.bytes == null) continue;
          final ext = file.extension?.toLowerCase() ?? '';

          if (['jpg', 'jpeg', 'png', 'webp'].contains(ext) &&
              _attachedImageBytes == null) {
            setState(() {
              _attachedImageBytes = file.bytes;
            });
          }

          if (activeSpaceId != null) {
            final uploaded = await filesProvider.uploadFile(
              spaceId: activeSpaceId,
              bytes: file.bytes!,
              filename: file.name,
            );
            if (uploaded && filesProvider.files.isNotEmpty) {
              final newFile = filesProvider.files.first;
              aiChat.attachFile(AttachedFileInfo(
                id: newFile.id,
                name: newFile.name,
                spaceId: activeSpaceId,
                fileType: ext,
              ));
              attachedCount++;
            } else {
              aiChat.attachFile(AttachedFileInfo(
                id: 'local_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
                name: file.name,
                spaceId: activeSpaceId,
                fileType: ext,
              ));
              attachedCount++;
            }
          } else {
            aiChat.attachFile(AttachedFileInfo(
              id: 'local_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
              name: file.name,
              spaceId: '',
              fileType: ext,
            ));
            attachedCount++;
          }
        }

        if (mounted && attachedCount > 0) {
          TopAlertBar.showSuccess(
            context,
            'Attached $attachedCount file(s) from system',
          );
          _focusNode.requestFocus();
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        TopAlertBar.showError(context, 'Could not attach file: $e');
      }
    }
  }

  void _showFolderAccessDialog() {
    final spacesProvider = context.read<SpacesProvider>();
    final aiChat = context.read<AiChatProvider>();
    final spaces = spacesProvider.spaces;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (spaces.isEmpty) {
      TopAlertBar.showInfo(context, 'No folders available. Create a space first.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grant Folder Access',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Spaces AI will strictly search only the folder you authorize.',
                          style: TextStyle(fontSize: 12, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: spaces.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, index) {
                    final sp = spaces[index];
                    final spacesProvider = context.read<SpacesProvider>();
                    final isCurrent = aiChat.attachedSpaceId == sp.id || aiChat.selectedSpaceId == sp.id;
                    final isLocked = sp.isPrivate && !spacesProvider.isSpaceUnlocked(sp.id);

                    Future<void> handleSelectSpace() async {
                      Navigator.pop(ctx);
                      if (isCurrent) {
                        _deselectAttachedSpace();
                        if (mounted) {
                          TopAlertBar.showInfo(
                            context,
                            'Deselected "${sp.name}". Folder locked.',
                          );
                        }
                        return;
                      }

                      // If a different folder was previously selected, lock it
                      final previousSpaceId = aiChat.attachedSpaceId ?? aiChat.selectedSpaceId;
                      if (previousSpaceId != null && previousSpaceId != sp.id) {
                        spacesProvider.lockSpace(previousSpaceId);
                      }

                      if (sp.isPrivate && !spacesProvider.isSpaceUnlocked(sp.id)) {
                        final unlocked = await showFolderUnlockDialog(
                          context,
                          sp,
                          promptAction: 'grant AI chat access',
                        );
                        if (!unlocked) return;
                      }

                      aiChat.attachSpace(
                        spaceId: sp.id,
                        spaceName: sp.name,
                        fileCount: sp.fileCount,
                      );
                      if (mounted) {
                        TopAlertBar.showSuccess(
                          context,
                          'Access granted to folder "${sp.name}"',
                        );
                      }
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.accent.withValues(alpha: isDark ? 0.20 : 0.10)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            sp.icon.isEmpty ? '📁' : sp.icon,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                sp.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (sp.isPrivate) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? Colors.amber.withValues(alpha: 0.15)
                                      : Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isLocked
                                        ? Colors.amber.withValues(alpha: 0.35)
                                        : Colors.green.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                      size: 11,
                                      color: isLocked ? Colors.amber : Colors.green,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isLocked ? 'Locked' : 'Unlocked',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isLocked ? Colors.amber : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${sp.fileCount} file(s)',
                          style: TextStyle(fontSize: 12, color: secondaryText),
                        ),
                        trailing: isCurrent
                            ? TextButton.icon(
                                onPressed: handleSelectSpace,
                                icon: const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 16),
                                label: const Text(
                                  'Deselect',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : TextButton.icon(
                                onPressed: handleSelectSpace,
                                icon: isLocked
                                    ? const Icon(Icons.lock_rounded, size: 13, color: AppColors.accent)
                                    : const SizedBox.shrink(),
                                label: Text(
                                  isLocked ? 'Unlock' : 'Authorize',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                        onTap: handleSelectSpace,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDeepSearchSelection(AiChatProvider aiChat) async {
    if (aiChat.searchMode == 'deep') return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable Deep Search?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Deep Search conducts deep neural vector search across authorized files and uses 5 credits per query.\n\nDo you want to switch to Deep Search mode?',
          style: TextStyle(
            fontSize: 13,
            color: secondaryText,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No, Keep Normal Chat',
              style: TextStyle(color: secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Enable', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      aiChat.setSearchMode('deep');
    }
  }

  Future<void> _showFilePickerDialog() async {
    final spacesProvider = context.read<SpacesProvider>();
    final spaces = spacesProvider.spaces;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    if (spaces.isEmpty) {
      TopAlertBar.showInfo(context, 'No folders found. Create a space first.');
      return;
    }

    final aiChat = context.read<AiChatProvider>();
    final targetSpaceId = aiChat.attachedSpaceId ?? aiChat.selectedSpaceId ?? spaces.first.id;
    final targetSpace = spaces.firstWhere(
      (s) => s.id == targetSpaceId,
      orElse: () => spaces.first,
    );

    if (targetSpace.isPrivate && !spacesProvider.isSpaceUnlocked(targetSpace.id)) {
      final unlocked = await showFolderUnlockDialog(
        context,
        targetSpace,
        promptAction: 'view and select files',
      );
      if (!unlocked) return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _FileSelectionModal(
          initialSpaceId: targetSpace.id,
          initialSpaceName: targetSpace.name,
          spaces: spaces,
          isDark: isDark,
          surfaceColor: surfaceColor,
          textColor: textColor,
          onFilesSelected: (selectedFiles) {
            aiChat.attachFiles(selectedFiles);
            TopAlertBar.showSuccess(
              context,
              'Attached ${selectedFiles.length} file(s) to chat',
            );
            _focusNode.requestFocus();
            _scrollToBottom();
          },
        );
      },
    );
  }

  void _showChatHistorySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer<AiChatProvider>(
          builder: (context, aiChat, _) {
            final sessions = aiChat.sessions;
            final activeId = aiChat.activeSessionId;

            return Container(
              height: MediaQuery.sizeOf(context).height * 0.75,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppColors.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '${sessions.length} conversation${sessions.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            aiChat.startNewChat();
                            _messageController.clear();
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New Chat'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            backgroundColor: AppColors.accent.withValues(
                              alpha: 0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  // Sessions list
                  Expanded(
                    child: sessions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_toggle_off_rounded,
                                  size: 48,
                                  color: secondaryText.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Chat History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your AI conversations will be saved here automatically.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: sessions.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final isActive = session.id == activeId;
                              final formattedDate = DateFormat(
                                'MMM d, h:mm a',
                              ).format(session.updatedAt);

                              return Container(
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.accent.withValues(alpha: 0.12)
                                      : (isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.accent.withValues(
                                            alpha: 0.5,
                                          )
                                        : (isDark
                                              ? Colors.white10
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                )),
                                    width: isActive ? 1.5 : 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  onTap: () {
                                    aiChat.loadSession(session.id);
                                    Navigator.pop(ctx);
                                    _scrollToBottom();
                                  },
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.accent
                                          : (isDark
                                                ? Colors.white10
                                                : Colors.black12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      session.mode == 'deep'
                                          ? Icons.psychology_rounded
                                          : Icons.chat_bubble_outline_rounded,
                                      color: isActive
                                          ? Colors.white
                                          : secondaryText,
                                      size: 18,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          session.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isActive
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 14,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      if (isActive)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          session.mode == 'deep'
                                              ? 'Deep Search'
                                              : 'Chat',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: secondaryText,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryText,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${session.messages.length})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: secondaryText.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    tooltip: 'Delete Chat',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (dCtx) => AlertDialog(
                                          title: const Text(
                                            'Delete Conversation?',
                                          ),
                                          content: Text(
                                            'Are you sure you want to delete "${session.title}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dCtx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.error,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(dCtx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        aiChat.deleteSession(session.id);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                            },
                          ),
                  ),
                  // Footer options
                  if (sessions.length > 1) ...[
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 18,
                            ),
                            label: const Text('Clear All History'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Clear All History?'),
                                  content: const Text(
                                    'This will delete all saved AI conversations.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dCtx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(dCtx, true),
                                      child: const Text('Clear All'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                aiChat.clearAllSessions();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final creditsProvider = context.watch<AiCreditsProvider>();
    final balance = creditsProvider.currentCredits;

    final aiChatProvider = context.watch<AiChatProvider>();
    final messages = aiChatProvider.currentMessages;
    final isSending = aiChatProvider.isSending;
    final errorMessage = aiChatProvider.errorMessage;
    final searchMode = aiChatProvider.searchMode;

    if (isSending || (messages.isNotEmpty && messages.last.isStreaming)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final currentScroll = _scrollController.position.pixels;
          // Smoothly follow the streaming generation downwards
          if (maxScroll - currentScroll < 400 || currentScroll == 0) {
            _scrollController.jumpTo(maxScroll);
          }
        }
      });
    }

    final tabCtrl = NavigationTabController.of(context);
    final isEmbedded = widget.embedded || tabCtrl != null;
    final canPop = !isEmbedded && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // Scope Selector Bar & Action Controls (Folder / Private Chat + History & New Chat)
            _buildScopeBar(aiChatProvider, isDark, foreground, secondary, balance, isSending, canPop),
            // Messages List & Welcome Area (Centered in unified 840px column)

            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  overscroll: false,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                ),
                child: SelectionArea(
                  child: messages.isEmpty
                      ? _buildWelcome(foreground, secondary)
                      : RepaintBoundary(
                          child: ListView.builder(
                            controller: _scrollController,
                            clipBehavior: Clip.hardEdge,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 840),
                                  child: _buildMessage(messages[index], isDark),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ),
            // Error message banner
            if (errorMessage != null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom Composer (Input Area)
            _buildComposer(isDark, searchMode, isSending),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(Color foreground, Color secondary) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(20, isMobile ? 36 : 56, 20, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isMobile ? 52 : 64,
                  height: isMobile ? 52 : 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.accent, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                SizedBox(height: isMobile ? 18 : 24),
                Text(
                  'How can I help you today?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ask questions, explore ideas, or attach files using the + button below to chat directly with your documents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondary,
                    fontSize: isMobile ? 13 : 14.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _suggestions.map((suggestion) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return InkWell(
                      onTap: () => _handleSendMessage(suggestion),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(ChatMessage message, bool isDark) {
    final textColor = message.isUser
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.imageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 220,
                            maxWidth: 280,
                          ),
                          child: Image.memory(
                            message.imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Assistant message: Clean, cardless, boxless natural text flow (no Gemini logo)
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.text.isEmpty && message.isStreaming) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ThreeDotsLoadingIndicator(
                      color: isDark ? AppColors.accent : AppColors.primary,
                      dotSize: 7.5,
                    ),
                  ),
                ],
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      height: 1.55,
                      letterSpacing: 0.1,
                    ),
                  ),
                if (message.searchMetadata != null) ...[
                  const SizedBox(height: 6),
                  _buildSearchMetadataBadge(message.searchMetadata!, isDark),
                ],
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.sources.map((source) {
                      return _buildSourceChip(source, isDark);
                    }).toList(),
                  ),
                ],
                if (!message.isStreaming && message.text.isNotEmpty)
                  _buildFeedbackRow(message, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchMetadataBadge(Map<String, dynamic> metadata, bool isDark) {
    final mode = metadata['mode']?.toString() ?? '';
    final totalFiles = metadata['total_files'] ?? metadata['totalFiles'];
    final readyFiles = metadata['ready_files'] ?? metadata['readyFiles'];
    final chunks = metadata['chunks_used'] ?? metadata['chunksUsed'];
    final latency = metadata['llm_latency_ms'] ?? metadata['llmLatencyMs'];

    String modeLabel = 'Search';
    IconData modeIcon = Icons.search_rounded;
    if (mode == 'DOCUMENT') {
      modeLabel = 'Document Analysis';
      modeIcon = Icons.auto_stories_rounded;
    } else if (mode == 'OVERVIEW') {
      modeLabel = 'Folder Overview';
      modeIcon = Icons.folder_open_rounded;
    } else if (mode == 'COMPARE') {
      modeLabel = 'Document Comparison';
      modeIcon = Icons.compare_arrows_rounded;
    } else if (mode == 'FULL_ANALYSIS') {
      modeLabel = 'Full Folder Analysis';
      modeIcon = Icons.analytics_outlined;
    } else if (mode == 'DEEP_FACT') {
      modeLabel = 'Targeted Fact Search';
      modeIcon = Icons.fact_check_outlined;
    }

    final parts = <String>[];
    if (readyFiles != null && readyFiles > 0) {
      parts.add('$readyFiles ${readyFiles == 1 ? 'file' : 'files'}');
    } else if (totalFiles != null && totalFiles > 0) {
      parts.add('$totalFiles ${totalFiles == 1 ? 'file' : 'files'}');
    }
    if (chunks != null && chunks > 0) {
      parts.add('$chunks chunks');
    }
    if (latency != null) {
      final ms = (latency is num) ? latency.round() : latency;
      parts.add('${ms}ms');
    }

    final detailStr = parts.isNotEmpty ? ' • ${parts.join(' • ')}' : '';

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            modeIcon,
            size: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            '$modeLabel$detailStr',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackRow(ChatMessage message, bool isDark) {
    final aiChat = context.read<AiChatProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              message.feedback == 'THUMBS_UP'
                  ? Icons.thumb_up_rounded
                  : Icons.thumb_up_outlined,
              size: 15,
              color: message.feedback == 'THUMBS_UP'
                  ? AppColors.accent
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            tooltip: 'Accurate answer',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () {
              aiChat.sendFeedback(messageId: message.id, rating: 'THUMBS_UP');
            },
          ),
          IconButton(
            icon: Icon(
              message.feedback == 'THUMBS_DOWN'
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_outlined,
              size: 15,
              color: message.feedback == 'THUMBS_DOWN'
                  ? AppColors.error
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            tooltip: 'Inaccurate answer',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () {
              aiChat.sendFeedback(messageId: message.id, rating: 'THUMBS_DOWN');
            },
          ),
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 15,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            tooltip: 'Copy answer',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message.text));
              TopAlertBar.showSuccess(context, 'Copied answer to clipboard');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(ChatSource source, bool isDark) {
    IconData iconData = Icons.description_rounded;
    final ext = source.fileType.toLowerCase();
    if (ext.contains('pdf')) {
      iconData = Icons.picture_as_pdf_rounded;
    } else if (ext.contains('ppt')) {
      iconData = Icons.slideshow_rounded;
    } else if (ext.contains('doc')) {
      iconData = Icons.article_rounded;
    } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      iconData = Icons.image_rounded;
    } else if (['mp4', 'mov', 'webm'].contains(ext)) {
      iconData = Icons.videocam_rounded;
    }

    final loc = source.location.isNotEmpty
        ? source.location
        : (source.pageNumber != null ? 'page ${source.pageNumber}' : '');

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => FileViewerModal(
            file: FileModel(
              id: source.id,
              name: source.name,
              originalName: source.name,
              mimeType: 'text/plain',
              extension: source.fileType,
              size: '0',
              storageKey: '',
              spaceId: source.spaceId,
              uploadedBy: '',
              category: 'NOTE',
              isStarred: false,
              createdAt: source.updatedAt,
              updatedAt: source.updatedAt,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: isDark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 14, color: AppColors.accent),
            const SizedBox(width: 5),
            Text(
              '[${source.citationNumber}] ${source.name}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (loc.isNotEmpty) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  loc,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreditsBadge(int balance, bool isDark) {
    String formatBalance(int b) {
      if (b >= 1000000) return '${(b / 1000000).toStringAsFixed(1)}M';
      if (b >= 1000) return '${(b / 1000).toStringAsFixed(b >= 10000 ? 0 : 1)}k';
      return '$b';
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiUsageScreen()),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.22),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bolt_rounded,
              color: AppColors.accent,
              size: 13,
            ),
            const SizedBox(width: 3),
            Text(
              formatBalance(balance),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: AppColors.accent,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeBar(
    AiChatProvider aiChat,
    bool isDark,
    Color foreground,
    Color secondary,
    int balance,
    bool isSending, [
    bool canPop = false,
  ]) {
    final hasFolder = aiChat.attachedSpaceId != null || aiChat.selectedSpaceId != null;
    final folderName = aiChat.attachedSpaceName ?? aiChat.selectedSpaceName;
    final fileCount = aiChat.attachedSpaceFileCount;
    final hasFiles = aiChat.attachedFiles.isNotEmpty || aiChat.selectedFileId != null;
    final isNarrow = MediaQuery.sizeOf(context).width < 520;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 10 : 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF130B2A) : const Color(0xFFF8F7F4)).withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Row(
            children: [
              if (canPop) ...[
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: UnifiedBackButton(),
                ),
              ],
              // Left: Privacy & Folder Scope Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hasFolder && !hasFiles) ...[
                        // Private mode badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 11, color: secondary),
                              const SizedBox(width: 4),
                              Text(
                                isNarrow ? 'Private' : 'Private (No folder)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Add Folder button
                        InkWell(
                          onTap: _showFolderAccessDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 13, color: AppColors.primary),
                                SizedBox(width: 3),
                                Text(
                                  '+ Folder',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        if (hasFolder) ...[
                          // Sleek unified folder pill with inline Change & close
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: isDark ? 0.38 : 0.28),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: isNarrow ? 90 : 160),
                                  child: Text(
                                    '$folderName${fileCount > 0 ? " ($fileCount)" : ""}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _showFolderAccessDialog,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    child: Text(
                                      'Change',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : AppColors.primary.withValues(alpha: 0.8),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  onTap: () {
                                    final currentSpaceName = aiChat.attachedSpaceName ?? 'Folder';
                                    _deselectAttachedSpace();
                                    TopAlertBar.showInfo(context, 'Deselected "$currentSpaceName". Folder locked.');
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (aiChat.attachedFiles.isNotEmpty) ...[
                          for (final af in aiChat.attachedFiles) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: isDark ? 0.18 : 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.insert_drive_file_outlined, size: 12, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: isNarrow ? 70 : 120),
                                    child: Text(
                                      af.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  InkWell(
                                    onTap: () => aiChat.removeAttachedFile(af.id),
                                    child: const Icon(Icons.close_rounded, size: 13, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Right: Credits, History, New Chat
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCreditsBadge(balance, isDark),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Chat History',
                    icon: const Icon(Icons.history_rounded, size: 19),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: foreground,
                    onPressed: () => _showChatHistorySheet(context),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'New Chat',
                    icon: const Icon(Icons.add_rounded, size: 21),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: foreground,
                    onPressed: isSending
                        ? null
                        : () {
                            aiChat.startNewChat();
                            _messageController.clear();
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(bool isDark, String searchMode, bool isSending) {
    final aiChat = context.watch<AiChatProvider>();
    final isFocused = _focusNode.hasFocus;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 520;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 12 : 24,
        0,
        isNarrow ? 12 : 24,
        isNarrow ? 8 : 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Floating attachment chips above the input capsule
                if (aiChat.hasAttachments || _attachedImageBytes != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (aiChat.attachedSpaceId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2E224D) : const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: isNarrow ? 130 : 220),
                                  child: Text(
                                    '${aiChat.attachedSpaceName}${aiChat.attachedSpaceFileCount > 0 ? " (${aiChat.attachedSpaceFileCount})" : ""}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    final currentSpaceName = aiChat.attachedSpaceName ?? 'Folder';
                                    _deselectAttachedSpace();
                                    TopAlertBar.showInfo(context, 'Deselected "$currentSpaceName". Folder locked.');
                                  },
                                  child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ...aiChat.attachedFiles.map((f) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_rounded, size: 12, color: AppColors.accent),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: isNarrow ? 100 : 160),
                                child: Text(
                                  f.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => aiChat.removeAttachedFile(f.id),
                                child: const Icon(Icons.close_rounded, size: 13, color: AppColors.accent),
                              ),
                            ],
                          ),
                        )),
                        if (_attachedImageBytes != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.teal.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_rounded, size: 12, color: Colors.teal),
                                const SizedBox(width: 4),
                                const Text(
                                  'Image',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setState(() => _attachedImageBytes = null),
                                  child: const Icon(Icons.close_rounded, size: 13, color: Colors.teal),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Modern Floating Capsule
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1730) : Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isFocused
                          ? AppColors.primary
                          : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                      width: isFocused ? 1.4 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isFocused
                            ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
                            : Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
                        blurRadius: isFocused ? 16 : 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Plus attachment button
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 21),
                        color: isDark ? Colors.white70 : Colors.black54,
                        tooltip: 'Add files or attachments',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        onPressed: _showAttachmentMenu,
                      ),
                      const SizedBox(width: 2),

                      // Text input field
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.enter): () {
                              if (!isSending) _handleSendMessage();
                            },
                          },
                          child: TextField(
                            focusNode: _focusNode,
                            controller: _messageController,
                            maxLines: isNarrow ? 3 : 5,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              if (!isSending) _handleSendMessage();
                            },
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontSize: 14.5,
                              height: 1.3,
                            ),
                            decoration: InputDecoration(
                              hintText: searchMode == 'chat' ? 'Ask anything...' : 'Search across notes...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Mode switch pill (Chat / Deep)
                      _ModeTogglePill(
                        searchMode: searchMode,
                        isDark: isDark,
                        isNarrow: isNarrow,
                        onChatTap: () => aiChat.setSearchMode('chat'),
                        onDeepTap: () => _handleDeepSearchSelection(aiChat),
                      ),
                      const SizedBox(width: 4),

                      // Circular Send Button
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSending
                                ? [AppColors.error, const Color(0xFFD32F2F)]
                                : [AppColors.accent, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isSending ? AppColors.error : AppColors.primary).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: isSending ? 'Stop' : 'Send',
                          icon: Icon(
                            isSending ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          onPressed: isSending ? () => aiChat.stopGeneration() : () => _handleSendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTogglePill extends StatelessWidget {
  final String searchMode;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onChatTap;
  final VoidCallback onDeepTap;

  const _ModeTogglePill({
    required this.searchMode,
    required this.isDark,
    required this.isNarrow,
    required this.onChatTap,
    required this.onDeepTap,
  });

  @override
  Widget build(BuildContext context) {
    final isChat = searchMode == 'chat';
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat mode button
          InkWell(
            onTap: onChatTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 8, vertical: 2),
              decoration: BoxDecoration(
                color: isChat
                    ? (isDark ? const Color(0xFF2D204A) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isChat
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Chat',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isChat ? FontWeight.w700 : FontWeight.w500,
                  color: isChat
                      ? AppColors.primary
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ),
          ),

          // Deep mode button
          InkWell(
            onTap: onDeepTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 8, vertical: 2),
              decoration: BoxDecoration(
                color: !isChat
                    ? (isDark ? const Color(0xFF2D204A) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: !isChat
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Deep',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: !isChat ? FontWeight.w700 : FontWeight.w500,
                  color: !isChat
                      ? AppColors.accent
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileSelectionModal extends StatefulWidget {
  final String initialSpaceId;
  final String initialSpaceName;
  final List<SpaceModel> spaces;
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final void Function(List<AttachedFileInfo> files) onFilesSelected;

  const _FileSelectionModal({
    required this.initialSpaceId,
    required this.initialSpaceName,
    required this.spaces,
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
    required this.onFilesSelected,
  });

  @override
  State<_FileSelectionModal> createState() => _FileSelectionModalState();
}

class _FileSelectionModalState extends State<_FileSelectionModal> {
  late String _currentSpaceId;
  late String _currentSpaceName;
  bool _loading = false;
  List<FileModel> _files = [];
  final Set<String> _selectedFileIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentSpaceId = widget.initialSpaceId;
    _currentSpaceName = widget.initialSpaceName;
    _fetchFiles();
  }

  @override
  void dispose() {
    final aiChat = context.read<AiChatProvider>();
    final spacesProvider = context.read<SpacesProvider>();
    if (aiChat.attachedSpaceId != _currentSpaceId) {
      spacesProvider.lockSpace(_currentSpaceId);
    }
    super.dispose();
  }

  Future<void> _fetchFiles() async {
    final spacesProvider = context.read<SpacesProvider>();
    final space = widget.spaces.firstWhere(
      (s) => s.id == _currentSpaceId,
      orElse: () => widget.spaces.first,
    );
    if (space.isPrivate && !spacesProvider.isSpaceUnlocked(space.id)) {
      final unlocked = await showFolderUnlockDialog(
        context,
        space,
        promptAction: 'view and select files',
      );
      if (!unlocked) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.spaceFiles(_currentSpaceId));
      if (res.success && res.data != null) {
        final List<dynamic> list = res.data is List
            ? res.data
            : (res.data is Map && res.data['data'] is List ? res.data['data'] : []);
        if (mounted) {
          setState(() {
            _files = list.map((item) => FileModel.fromJson(item)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching files for space: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'txt':
      case 'md':
        return Icons.text_snippet_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatBytes(String sizeStr) {
    final bytes = int.tryParse(sizeStr) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final filtered = _files.where((f) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(q) || f.originalName.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select Files from Folder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Switch Folder',
                onSelected: (spId) async {
                  final sp = widget.spaces.firstWhere((s) => s.id == spId);
                  final spacesProvider = context.read<SpacesProvider>();
                  if (_currentSpaceId != sp.id) {
                    final currentSpace = widget.spaces.firstWhere(
                      (s) => s.id == _currentSpaceId,
                      orElse: () => widget.spaces.first,
                    );
                    if (currentSpace.isPrivate) {
                      spacesProvider.lockSpace(_currentSpaceId);
                    }
                  }
                  if (sp.isPrivate && !spacesProvider.isSpaceUnlocked(sp.id)) {
                    final unlocked = await showFolderUnlockDialog(
                      context,
                      sp,
                      promptAction: 'view and select files',
                    );
                    if (!unlocked) return;
                  }
                  setState(() {
                    _currentSpaceId = sp.id;
                    _currentSpaceName = sp.name;
                    _selectedFileIds.clear();
                  });
                  _fetchFiles();
                },
                itemBuilder: (ctx) {
                  final spacesProvider = context.read<SpacesProvider>();
                  return widget.spaces.map((sp) {
                    final isLocked = sp.isPrivate && !spacesProvider.isSpaceUnlocked(sp.id);
                    return PopupMenuItem(
                      value: sp.id,
                      child: Row(
                        children: [
                          Text(sp.icon.isEmpty ? '📁' : spaceIcon(sp.icon)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(sp.name, overflow: TextOverflow.ellipsis)),
                          if (sp.isPrivate) ...[
                            const SizedBox(width: 6),
                            Icon(
                              isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                              size: 13,
                              color: isLocked ? Colors.amber : Colors.green,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          _currentSpaceName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(fontSize: 13, color: widget.textColor),
            decoration: InputDecoration(
              hintText: 'Search files in this folder...',
              hintStyle: TextStyle(fontSize: 13, color: secondaryText),
              prefixIcon: Icon(Icons.search, size: 18, color: secondaryText),
              isDense: true,
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _files.isEmpty ? 'No files found in this folder' : 'No matching files',
                          style: TextStyle(color: secondaryText),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final f = filtered[idx];
                          final isChecked = _selectedFileIds.contains(f.id);
                          return CheckboxListTile(
                            value: isChecked,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedFileIds.add(f.id);
                                } else {
                                  _selectedFileIds.remove(f.id);
                                }
                              });
                            },
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getFileIcon(f.extension),
                                size: 20,
                                color: AppColors.accent,
                              ),
                            ),
                            title: Text(
                              f.originalName.isNotEmpty ? f.originalName : f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: widget.textColor,
                              ),
                            ),
                            subtitle: Text(
                              '${_formatBytes(f.size)} • ${f.extension.toUpperCase()} • ${f.indexStatus}',
                              style: TextStyle(fontSize: 11, color: secondaryText),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _selectedFileIds.isEmpty
                ? null
                : () {
                    final selected = _files
                        .where((f) => _selectedFileIds.contains(f.id))
                        .map((f) => AttachedFileInfo(
                              id: f.id,
                              name: f.originalName.isNotEmpty ? f.originalName : f.name,
                              spaceId: f.spaceId,
                              spaceName: _currentSpaceName,
                              fileType: f.extension,
                            ))
                        .toList();
                    widget.onFilesSelected(selected);
                    Navigator.pop(context);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _selectedFileIds.isEmpty
                  ? 'Select files to attach'
                  : 'Attach ${_selectedFileIds.length} File${_selectedFileIds.length > 1 ? "s" : ""} to Chat',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String spaceIcon(String icon) => icon.isEmpty ? '📁' : icon;
}
