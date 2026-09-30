import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/spaces_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/ai_credits_provider.dart';
import '../../widgets/space_card.dart';
import '../spaces/create_space_dialog.dart';
import '../spaces/space_detail_screen.dart';
import '../activity/activity_feed_screen.dart';
import '../sharing/my_links_screen.dart';
import '../sharing/share_dialog.dart';
import '../profile/profile_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../ai/ai_usage_screen.dart';
import '../search/deep_search_screen.dart';
import '../../widgets/top_alert_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SpacesProvider>(context, listen: false).fetchSpaces();
      Provider.of<AiCreditsProvider>(context, listen: false).fetchBalance();
    });
  }

  void _openCreateSpace() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const CreateSpaceDialog(),
    );
    if (result == true) {
      _loadData();
      if (mounted) {
        TopAlertBar.showSuccess(context, 'Space created successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final spacesProvider = Provider.of<SpacesProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 3 : 2);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: CustomScrollView(
            slivers: [
              // Split Floating Top Header with Futuristic AI Search
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: _buildSplitFloatingHeader(
                    context,
                    auth,
                    themeProvider,
                    isDark,
                    width,
                  ),
                ),
              ),

              // Floating Hero Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(isDark ? 0.25 : 0.10),
                          AppColors.accent.withOpacity(isDark ? 0.18 : 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(
                          isDark ? 0.35 : 0.20,
                        ),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Context over Folders',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create a Space for what matters and keep everything related to it together.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New Space'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _openCreateSpace,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── AI WIDGETS ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _AiWidgetsSection(),
              ),

              // "YOUR SPACES" Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'YOUR SPACES',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${spacesProvider.spaces.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Spaces Grid or Empty State
              if (spacesProvider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (spacesProvider.spaces.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.layers_clear_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Your Spaces are empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first Space and keep everything related to one topic together.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create Space'),
                            onPressed: _openCreateSpace,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.15,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final space = spacesProvider.spaces[index];
                      return SpaceCard(
                        space: space,
                        onTap: () {
                          spacesProvider.setActiveSpace(space);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SpaceDetailScreen(space: space),
                            ),
                          ).then((_) => _loadData());
                        },
                        onMoreTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => ShareDialog(space: space),
                          );
                        },
                      );
                    }, childCount: spacesProvider.spaces.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitFloatingHeader(
    BuildContext context,
    AuthProvider auth,
    ThemeProvider themeProvider,
    bool isDark,
    double screenWidth,
  ) {
    final isWide = screenWidth >= 960;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Floating Profile Island
          _buildLeftProfilePill(context, auth, isDark),
          const SizedBox(width: 14),

          // Futuristic Floating AI Deep Search Island
          Expanded(
            child: _FuturisticAiSearchBar(
              onSubmitted: (query) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiChatScreen(initialQuery: query),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 14),

          // Right Floating Actions Island
          _buildRightActionsPill(context, themeProvider, isDark),
        ],
      );
    }

    // Tablet / Mobile: Dual row layout for optimal ergonomics
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Floating Profile Island
            Flexible(child: _buildLeftProfilePill(context, auth, isDark)),
            const SizedBox(width: 8),

            // Right Floating Actions Island
            _buildRightActionsPill(context, themeProvider, isDark),
          ],
        ),
        const SizedBox(height: 10),

        // Prominent Futuristic Floating AI Search Bar
        _FuturisticAiSearchBar(
          onSubmitted: (query) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiChatScreen(initialQuery: query),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLeftProfilePill(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xCC111827) : const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          auth.user?.initials ?? 'SP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hello, ${auth.user?.firstName ?? 'Organizer'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF8B5CF6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Spaces Cloud',
                            style: TextStyle(
                              fontSize: 10.5,
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
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightActionsPill(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xCC111827) : const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.bolt_rounded,
                  size: 19,
                  color: Color(0xFF8B5CF6),
                ),
                tooltip: 'Activity Feed',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActivityFeedScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.link_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                tooltip: 'My Share Links',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyLinksScreen()),
                  );
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 19,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () => themeProvider.toggleTheme(),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.settings_outlined, size: 19),
                tooltip: 'Account Settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Widgets Section
// ─────────────────────────────────────────────────────────────────────────────

class _AiWidgetsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final credits = context.watch<AiCreditsProvider>();
    final balance = credits.balance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Credits + label row ───────────────────────────────────────────
          Row(
            children: [
              // Credits chip
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiUsageScreen()),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        balance != null
                            ? '${balance.balance} credits'
                            : 'AI Credits',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI FEATURES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              const Spacer(),
              if (balance != null)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiUsageScreen()),
                  ),
                  child: Text(
                    'View usage →',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Quick-action cards ────────────────────────────────────────────
          SizedBox(
            height: 94,
            child: Row(
              children: [
                // Ask AI
                Expanded(
                  child: _AiActionCard(
                    isDark: isDark,
                    icon: Icons.chat_bubble_outline_rounded,
                    iconGradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                    label: 'Ask AI',
                    subtitle: 'Chat with your files',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiChatScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Deep Search
                Expanded(
                  child: _AiActionCard(
                    isDark: isDark,
                    icon: Icons.travel_explore_rounded,
                    iconGradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                    ),
                    label: 'Deep Search',
                    subtitle: 'AI-powered answers',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DeepSearchScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // AI Usage
                Expanded(
                  child: _AiActionCard(
                    isDark: isDark,
                    icon: Icons.insights_rounded,
                    iconGradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    label: 'AI Usage',
                    subtitle: 'Credits & history',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiUsageScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiActionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final LinearGradient iconGradient;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _AiActionCard({
    required this.isDark,
    required this.icon,
    required this.iconGradient,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon with gradient background
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: iconGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            // Labels
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FuturisticAiSearchBar extends StatefulWidget {
  final ValueChanged<String>? onSubmitted;

  const _FuturisticAiSearchBar({
    this.onSubmitted,
  });

  @override
  State<_FuturisticAiSearchBar> createState() => _FuturisticAiSearchBarState();
}

class _FuturisticAiSearchBarState extends State<_FuturisticAiSearchBar> {
  bool _isHovered = false;
  bool _hasFocus = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      widget.onSubmitted?.call(query);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.text,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF1E1B4B).withValues(
                      alpha: _isHovered ? 0.85 : 0.65,
                    ),
                    const Color(0xFF111827).withValues(alpha: 0.90),
                    const Color(0xFF0F172A).withValues(alpha: 0.85),
                  ]
                : [
                    const Color(0xFFEEF2FF).withValues(alpha: 0.90),
                    const Color(0xFFF8FAFC).withValues(alpha: 0.95),
                    const Color(0xFFECFEFF).withValues(alpha: 0.90),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: (_isHovered || _hasFocus)
                ? const Color(0xFF8B5CF6).withValues(alpha: _hasFocus ? 0.80 : 0.65)
                : (isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.28)),
            width: (_isHovered || _hasFocus) ? 1.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(
                alpha: _hasFocus
                    ? (isDark ? 0.40 : 0.25)
                    : _isHovered
                        ? (isDark ? 0.30 : 0.18)
                        : (isDark ? 0.16 : 0.08),
              ),
              blurRadius: _hasFocus ? 28 : (_isHovered ? 24 : 14),
              offset: const Offset(0, 4),
              spreadRadius: (_isHovered || _hasFocus) ? 1 : 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Decorative AI Glowing Badge (non-interactive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8B5CF6),
                          Color(0xFF6366F1),
                          Color(0xFF06B6D4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          '✦ AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Search Text Field — takes all available space
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmitted: (_) => _handleSubmit(),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search spaces, files, notes or ask AI...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  // Send / Search Action Button
                  InkWell(
                    onTap: _handleSubmit,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.20)
                            : const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
