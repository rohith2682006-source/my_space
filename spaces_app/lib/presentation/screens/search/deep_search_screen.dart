import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/ai_credits_provider.dart';
import '../plans/plans_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _Source {
  final String fileId;
  final String fileName;
  final String spaceName;
  final String fileType;
  final int? pageNumber;
  final String excerpt;
  final double score;

  const _Source({
    required this.fileId,
    required this.fileName,
    required this.spaceName,
    required this.fileType,
    this.pageNumber,
    required this.excerpt,
    required this.score,
  });

  factory _Source.fromJson(Map<String, dynamic> j) => _Source(
        fileId: j['fileId'] as String? ?? '',
        fileName: j['fileName'] as String? ?? 'Unknown file',
        spaceName: j['spaceName'] as String? ?? '',
        fileType: (j['fileType'] as String? ?? '').toLowerCase(),
        pageNumber: j['pageNumber'] as int?,
        excerpt: j['excerpt'] as String? ?? '',
        score: ((j['score'] as num?) ?? 0).toDouble(),
      );
}

class _DeepResult {
  final String answer;
  final List<_Source> sources;
  final int creditsUsed;
  final int creditsRemaining;

  const _DeepResult({
    required this.answer,
    required this.sources,
    required this.creditsUsed,
    required this.creditsRemaining,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DeepSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const DeepSearchScreen({super.key, this.initialQuery});

  @override
  State<DeepSearchScreen> createState() => _DeepSearchScreenState();
}

class _DeepSearchScreenState extends State<DeepSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _pulseCtrl;

  bool _isSearching = false;
  _DeepResult? _result;
  String? _error;

  static const _suggestions = [
    '🔍 Summarize my project planning notes',
    '📊 What did I write about Q4 budget?',
    '📝 Find key decisions from my meeting notes',
    '🎯 What are my goals for this quarter?',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _queryCtrl.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focusNode.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty || _isSearching) return;
    _focusNode.unfocus();
    setState(() {
      _isSearching = true;
      _result = null;
      _error = null;
    });

    try {
      final response = await ApiClient.post(
        ApiEndpoints.aiDeepSearch,
        body: {'query': query, 'spaceIds': []},
      );

      if (!mounted) return;

      if (!response.success) {
        throw Exception(response.message ?? 'Deep search failed');
      }

      final data = response.data as Map<String, dynamic>? ?? {};
      final sources = ((data['sources'] as List?) ?? [])
          .map((s) => _Source.fromJson(s as Map<String, dynamic>))
          .toList();

      setState(() {
        _result = _DeepResult(
          answer: data['answer'] as String? ?? '',
          sources: sources,
          creditsUsed: (data['creditsUsed'] as num?)?.toInt() ?? 5,
          creditsRemaining: (data['creditsRemaining'] as num?)?.toInt() ?? 0,
        );
      });

      // Refresh balance
      if (mounted) context.read<AiCreditsProvider>().fetchBalance();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, textPrimary, textSecondary),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(isDark, surface),
          // Content
          Expanded(
            child: _isSearching
                ? _buildLoadingState(isDark)
                : _error != null
                    ? _buildErrorState(_error!, textPrimary, textSecondary)
                    : _result != null
                        ? _buildResultView(_result!, isDark, textPrimary,
                            textSecondary, surface)
                        : _buildEmptyState(isDark, textPrimary, textSecondary),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, Color textPrimary, Color textSecondary) {
    return AppBar(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) =>
                AppColors.primaryGradient.createShader(b),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
          Text(
            'Deep Search',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        Consumer<AiCreditsProvider>(
          builder: (_, credits, __) {
            final balance = credits.balance;
            return GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlansScreen())),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: balance != null && balance.balance < 5
                      ? const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      balance != null ? '${balance.balance} cr' : '--',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark, Color surface) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focusNode.hasFocus
              ? AppColors.primary
              : isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _queryCtrl,
        focusNode: _focusNode,
        maxLines: 3,
        minLines: 1,
        style: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Ask anything about your documents…',
          hintStyle: TextStyle(
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: _queryCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                  ),
                  onPressed: _search,
                )
              : null,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _search(),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary
                        .withAlpha((100 + (_pulseCtrl.value * 80)).toInt()),
                    AppColors.accentPurple
                        .withAlpha((40 + (_pulseCtrl.value * 60)).toInt()),
                  ],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Searching your documents…',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reading, chunking & reasoning',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withAlpha(60),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Deep AI Search',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask questions across all your AI-enabled files.\nGet answers with exact source citations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: textSecondary, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Try asking…',
            style: TextStyle(
                color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ..._suggestions.map((s) => _SuggestionChip(
                label: s,
                onTap: () {
                  _queryCtrl.text =
                      s.replaceAll(RegExp(r'^[^\s]+ '), ''); // strip emoji
                  _search();
                },
              )),
          const SizedBox(height: 24),
          _CreditCostBanner(),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      String error, Color textPrimary, Color textSecondary) {
    final isNoCredits = error.contains('credit') || error.contains('CREDIT');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isNoCredits
                    ? AppColors.warning.withAlpha(30)
                    : AppColors.error.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNoCredits
                    ? Icons.bolt_outlined
                    : Icons.error_outline_rounded,
                color: isNoCredits ? AppColors.warning : AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isNoCredits ? 'Not Enough Credits' : 'Search Failed',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            if (isNoCredits)
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PlansScreen())),
                icon: const Icon(Icons.upgrade_rounded),
                label: const Text('Buy Credits'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              TextButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(_DeepResult result, bool isDark, Color textPrimary,
      Color textSecondary, Color surface) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Credit badge
          _CreditUsedBadge(
              creditsUsed: result.creditsUsed,
              creditsRemaining: result.creditsRemaining),
          const SizedBox(height: 16),

          // Answer card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withAlpha(80),
              ),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.primaryGradient.createShader(b),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('AI Answer',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy answer',
                      color: textSecondary,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: result.answer));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Answer copied to clipboard'),
                              duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  result.answer.isEmpty
                      ? 'No relevant answer found in your documents.'
                      : result.answer,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),

          if (result.sources.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Sources (${result.sources.length})',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...result.sources.asMap().entries.map(
                  (entry) => _SourceCard(
                    index: entry.key + 1,
                    source: entry.value,
                    isDark: isDark,
                    surface: surface,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
          ],

          const SizedBox(height: 16),
          // Search again row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _result = null);
                    _queryCtrl.clear();
                    _focusNode.requestFocus();
                  },
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('New search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary),
          ],
        ),
      ),
    );
  }
}

class _CreditCostBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(25),
            AppColors.accentPurple.withAlpha(15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Deep Search costs 5 credits per query.\nQuick Search costs 1 credit.',
              style: TextStyle(
                  color: AppColors.primary, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditUsedBadge extends StatelessWidget {
  final int creditsUsed;
  final int creditsRemaining;
  const _CreditUsedBadge(
      {required this.creditsUsed, required this.creditsRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 16),
          const SizedBox(width: 6),
          Text(
            '$creditsUsed credits used  •  $creditsRemaining remaining',
            style: const TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatefulWidget {
  final int index;
  final _Source source;
  final bool isDark;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _SourceCard({
    required this.index,
    required this.source,
    required this.isDark,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _expanded = false;

  Color get _typeColor {
    switch (widget.source.fileType) {
      case 'pdf':
        return AppColors.catDocument;
      case 'docx':
      case 'doc':
        return AppColors.catNote;
      case 'txt':
      case 'md':
      case 'markdown':
        return AppColors.catCode;
      default:
        return AppColors.catOther;
    }
  }

  IconData get _typeIcon {
    switch (widget.source.fileType) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      case 'txt':
      case 'md':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Index badge
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _typeColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index}',
                        style: TextStyle(
                            color: _typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(_typeIcon, color: _typeColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.source.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              widget.source.spaceName,
                              style: TextStyle(
                                  color: widget.textSecondary, fontSize: 11),
                            ),
                            if (widget.source.pageNumber != null) ...[
                              Text(' · ',
                                  style: TextStyle(
                                      color: widget.textSecondary,
                                      fontSize: 11)),
                              Text(
                                'Page ${widget.source.pageNumber}',
                                style: TextStyle(
                                    color: AppColors.primary, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Relevance score
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(widget.source.score * 100).round()}%',
                      style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: widget.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Text(
                  '"${widget.source.excerpt}"',
                  style: TextStyle(
                    color: widget.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

