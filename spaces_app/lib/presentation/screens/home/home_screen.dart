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
import '../spaces/vault_lock_screen.dart';
import '../sharing/share_dialog.dart';
import '../ai/ai_chat_screen.dart';
import '../ai/ai_usage_screen.dart';
import '../search/deep_search_screen.dart';
import '../search/search_screen.dart';
import '../../../core/utils/app_routes.dart';
import '../../widgets/top_alert_bar.dart';
import '../../widgets/navigation_tab_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/services/intent_receiver_service.dart';

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
    if (!kIsWeb) {
      IntentReceiverService.instance.initialize(context);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      IntentReceiverService.instance.dispose();
    }
    super.dispose();
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
    final isDesktop = width >= 850;
    final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 3 : 2);

    Widget content = RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: Focus(
        autofocus: true,
        child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            cacheExtent: 1000,
            slivers: [
              // Removed SliverAppBar as it is now in MainNavigationScreen
              // ── Dashboard Search Bar ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SearchScreen(),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 250),
                      ),
                    ),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : AppColors.lightBorder,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.35 : 0.05,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 18),
                          Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Search spaces, files, notes...',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverSafeArea(
                top: false,
                bottom: false,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Context over Folders Banner
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.12)
                                : AppColors.lightBorder,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.05 : 0.03),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Context over Folders',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Create a Space and keep everything related to it together.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(50, 32),
                              ),
                              onPressed: _openCreateSpace,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── AI WIDGETS REMOVED ──────────────────────────────────────────────
                    const SizedBox(height: 12),
                  ]),
                ),
              ),

              // "YOUR SPACES" Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Spaces',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.15)
                                  : AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${spacesProvider.spaces.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.primary,
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
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : AppColors.primary.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.layers_clear_rounded,
                              size: 40,
                              color: isDark ? Colors.white : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your Spaces are empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first Space and keep everything related to one topic together.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: width < 450 ? 12 : 16,
                      mainAxisSpacing: width < 450 ? 12 : 16,
                      childAspectRatio: width < 450 ? 0.95 : 0.9,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final space = spacesProvider.spaces[index];
                      return SpaceCard(
                        space: space,
                        onTap: () {
                          if (space.isPrivate) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VaultLockScreen(
                                  spaceId: space.id,
                                  spaceName: space.name,
                                  onUnlocked: (lockContext) {
                                    spacesProvider.setActiveSpace(space);
                                    Navigator.of(lockContext)
                                        .pushReplacement<void, void>(
                                          AppRoute<void>(
                                            builder: (_) =>
                                                SpaceDetailScreen(space: space),
                                          ),
                                        )
                                        .then((_) => _loadData());
                                  },
                                ),
                              ),
                            );
                          } else {
                            spacesProvider.setActiveSpace(space);
                            Navigator.push(
                              context,
                              AppRoute(
                                builder: (_) => SpaceDetailScreen(space: space),
                              ),
                            ).then((_) => _loadData());
                          }
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
      );

    if (!isDesktop) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          // Swipe from left to right on mobile to show the menu bar
          if ((details.primaryVelocity ?? 0) > 200) {
            NavigationTabController.of(context)?.onOpenDrawer?.call();
            Scaffold.maybeOf(context)?.openDrawer();
          }
        },
        child: content,
      );
    }

    return content;
  }

  // _buildSplitFloatingHeader was removed since we use SliverAppBar instead
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                  AppRoute(builder: (_) => const AiUsageScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
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
                      const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        balance != null
                            ? '${balance.balance} credits'
                            : 'AI Credits',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'AI FEATURES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
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
                    AppRoute(builder: (_) => const AiUsageScreen()),
                  ),
                  child: Text(
                    'View usage →',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Quick-action cards ────────────────────────────────────────────
          SizedBox(
            height: 115,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Ask AI
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
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
                        AppRoute(builder: (_) => const AiChatScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Deep Search
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
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
                        AppRoute(builder: (_) => const DeepSearchScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // AI Usage
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
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
                        AppRoute(builder: (_) => const AiUsageScreen()),
                      ),
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
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: iconGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            // Labels
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: textSecondary, fontSize: 12.5),
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
