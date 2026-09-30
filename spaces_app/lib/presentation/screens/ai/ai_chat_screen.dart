import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/file_model.dart';
import '../../../providers/files_provider.dart';
import '../../../providers/ai_credits_provider.dart';
import '../../widgets/file_viewer_modal.dart';
import '../../widgets/navigation_tab_controller.dart';
import '../../widgets/top_alert_bar.dart';
import 'ai_usage_screen.dart';
import '../plans/plans_screen.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialQuery;
  const AiChatScreen({super.key, this.initialQuery});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  String? _errorMessage;
  String _searchMode = 'deep'; // 'quick' (1 cr) or 'deep' (5 cr)

  static const _suggestions = [
    'Find my notes about the project budget',
    'What did I write about my study plan?',
    'Summarize my project planning notes',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiCreditsProvider>().fetchBalance();
      if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
        _sendMessage(widget.initialQuery);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? suggestedMessage]) async {
    if (_isSending) return;

    final message = (suggestedMessage ?? _messageController.text).trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: message, isUser: true));
      _messageController.clear();
      _isSending = true;
      _errorMessage = null;
    });
    _scrollToBottom();

    try {
      ApiResponse response;
      if (_searchMode == 'quick') {
        response = await ApiClient.post(
          ApiEndpoints.aiQuickSearch,
          body: {'query': message, 'spaceIds': []},
        );
      } else {
        final history = _messages
            .take(_messages.length - 1)
            .skip((_messages.length - 1 - 12).clamp(0, 12))
            .map(
              (item) => {
                'role': item.isUser ? 'user' : 'assistant',
                'content': item.text,
              },
            )
            .toList();
        response = await ApiClient.post(
          ApiEndpoints.aiDeepSearch,
          body: {'message': message, 'history': history},
        );
      }

      if (!mounted) return;

      final data = response.data;
      if (data is Map && data['remainingCredits'] != null) {
        context.read<AiCreditsProvider>().updateBalanceLocally(data['remainingCredits'] as int);
      }

      if (!response.success) {
        final msg = response.message ?? 'The assistant could not respond.';
        setState(() => _errorMessage = msg);
        if (response.statusCode == 402 || msg.toLowerCase().contains('credit')) {
          _showCreditsExhaustedDialog();
        }
      } else if (_searchMode == 'quick') {
        final results = (data is Map && data['results'] is List)
            ? (data['results'] as List)
            : const [];
        if (results.isEmpty) {
          setState(() {
            _messages.add(
              const _ChatMessage(
                text: "No matching documents or notes found for your quick query.",
                isUser: false,
              ),
            );
          });
        } else {
          final sources = results.map((r) => _ChatSource(
            id: r['fileId'] ?? '',
            name: r['fileName'] ?? '',
            spaceName: r['spaceName'] ?? '',
            fileType: r['fileType'] ?? '',
            pageNumber: r['pageNumber'] as int?,
            citationNumber: r['rank'] as int? ?? 1,
            updatedAt: DateTime.now(),
          )).toList();

          final count = results.length;
          final topMatch = results.first['content'] ?? '';
          final summary = "Found $count matching snippet${count > 1 ? 's' : ''} in your documents:\n\n\"$topMatch\"";

          setState(() {
            _messages.add(
              _ChatMessage(text: summary, isUser: false, sources: sources),
            );
          });
        }
      } else {
        final reply = data is Map ? data['reply'] : null;
        final rawSources = data is Map && data['sources'] is List
            ? data['sources'] as List
            : const [];

        if (reply is! String || reply.trim().isEmpty) {
          setState(
            () => _errorMessage = 'The assistant returned an empty response.',
          );
        } else {
          final sources = rawSources
              .whereType<Map>()
              .map(
                (source) =>
                    _ChatSource.fromJson(Map<String, dynamic>.from(source)),
              )
              .toList();
          setState(
            () => _messages.add(
              _ChatMessage(text: reply, isUser: false, sources: sources),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Could not reach the assistant. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
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

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _errorMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _indexExistingDocuments() async {
    try {
      final count = await Provider.of<FilesProvider>(
        context,
        listen: false,
      ).reindexExistingDocuments();
      if (mounted) {
        TopAlertBar.showSuccess(
          context,
          count == 0
              ? 'No documents need indexing.'
              : 'Indexing queued for $count documents.',
        );
      }
    } catch (error) {
      if (mounted) {
        TopAlertBar.showError(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            final tabCtrl = NavigationTabController.of(context);
                            if (tabCtrl != null) tabCtrl.onSelectTab(0);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spaces Assistant',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _searchMode == 'quick'
                                  ? '⚡ Quick semantic search (1 credit)'
                                  : '✨ Deep RAG with citations (5 credits)',
                              style: TextStyle(color: secondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 16),
                        label: Text(
                          '$balance cr',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accent),
                        ),
                        backgroundColor: AppColors.accent.withOpacity(0.12),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiUsageScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'New chat',
                        onPressed: _messages.isEmpty || _isSending
                            ? null
                            : _startNewChat,
                        icon: const Icon(Icons.add_comment_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Re-index existing documents',
                        onPressed: _isSending ? null : _indexExistingDocuments,
                        icon: const Icon(Icons.sync_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                // Mode Toggle Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _searchMode = 'quick'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _searchMode == 'quick'
                                    ? (isDark ? const Color(0xFF27272A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _searchMode == 'quick'
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.flash_on_rounded,
                                    size: 15,
                                    color: _searchMode == 'quick' ? AppColors.accent : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Quick Search (1 cr)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _searchMode == 'quick' ? FontWeight.bold : FontWeight.w500,
                                      color: _searchMode == 'quick' ? foreground : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _searchMode = 'deep'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _searchMode == 'deep'
                                    ? (isDark ? const Color(0xFF27272A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _searchMode == 'deep'
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 15,
                                    color: _searchMode == 'deep' ? AppColors.accent : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Deep RAG (5 cr)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _searchMode == 'deep' ? FontWeight.bold : FontWeight.w500,
                                      color: _searchMode == 'deep' ? foreground : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _messages.isEmpty
                      ? _buildWelcome(foreground, secondary)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          itemCount: _messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _buildThinking(secondary);
                            }
                            return _buildMessage(_messages[index], isDark);
                          },
                        ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildComposer(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(Color foreground, Color secondary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 24),
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.accent,
          size: 34,
        ),
        const SizedBox(height: 16),
        Text(
          'What are you organizing today?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Search your saved notes and get answers with links back to their source.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        ..._suggestions.map(
          (suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _isSending ? null : () => _sendMessage(suggestion),
                icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                label: Text(suggestion, textAlign: TextAlign.center),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.24),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(_ChatMessage message, bool isDark) {
    final bubbleColor = message.isUser
        ? AppColors.primary
        : (isDark ? AppColors.darkCard : const Color(0xFFF1F5F9));
    final textColor = message.isUser
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.45),
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final source in message.sources)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: InkWell(
                    onTap: () => _openSource(source),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: textColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '[${source.citationNumber}] ${source.name} · ${source.spaceName}${source.pageNumber == null ? ' · ${DateFormat('MMM d, yyyy').format(source.updatedAt)}' : ' · Page ${source.pageNumber}'}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(_ChatSource source) async {
    final response = await ApiClient.get(ApiEndpoints.file(source.id));
    if (!mounted) return;

    final data = response.data;
    if (!response.success || data is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Could not open this note.'),
        ),
      );
      return;
    }

    FileViewerModal.show(
      context,
      FileModel.fromJson(Map<String, dynamic>.from(data)),
      initialPdfPage: source.pageNumber ?? 1,
    );
  }

  Widget _buildThinking(Color secondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('Thinking...', style: TextStyle(color: secondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Message the assistant...',
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Send message',
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
  });

  final String text;
  final bool isUser;
  final List<_ChatSource> sources;
}

class _ChatSource {
  const _ChatSource({
    required this.id,
    required this.name,
    required this.spaceName,
    required this.updatedAt,
    required this.citationNumber,
    this.pageNumber,
    this.fileType = '',
  });

  final String id;
  final String name;
  final String spaceName;
  final DateTime updatedAt;
  final int citationNumber;
  final int? pageNumber;
  final String fileType;

  factory _ChatSource.fromJson(Map<String, dynamic> json) {
    return _ChatSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled note',
      spaceName: json['spaceName'] as String? ?? 'Space',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      citationNumber: json['citationNumber'] as int? ?? 1,
      pageNumber: json['pageNumber'] as int?,
      fileType: json['fileType'] as String? ?? '',
    );
  }
}
