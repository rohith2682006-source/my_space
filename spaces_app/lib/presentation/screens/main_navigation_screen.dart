import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:provider/provider.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/files_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/navigation_tab_controller.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import 'recent/recent_screen.dart';
import 'favorites/favorites_screen.dart';
import 'trash/trash_screen.dart';
import 'storage/storage_screen.dart';
import 'ai/ai_chat_screen.dart';
import '../widgets/global_top_bar.dart';
import '../widgets/settings_container_dialog.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = const [
    HomeScreen(),
    RecentScreen(),
    FavoritesScreen(),
    TrashScreen(),
    StorageScreen(),
    AiChatScreen(),
  ];

  final List<Map<String, dynamic>> _navItems = [
    {
      'label': 'My Spaces',
      'shortLabel': 'Spaces',
      'icon': Icons.grid_view_rounded,
      'activeIcon': Icons.grid_view_rounded,
      'group': 'EXPLORE',
    },
    {
      'label': 'Recent Files',
      'shortLabel': 'Recent',
      'icon': Icons.history_rounded,
      'activeIcon': Icons.history_toggle_off_rounded,
      'group': 'EXPLORE',
    },
    {
      'label': 'Favorites',
      'shortLabel': 'Favorites',
      'icon': Icons.star_outline_rounded,
      'activeIcon': Icons.star_rounded,
      'group': 'EXPLORE',
    },
    {
      'label': 'Trash Bin',
      'shortLabel': 'Trash',
      'icon': Icons.delete_outline_rounded,
      'activeIcon': Icons.delete_rounded,
      'isTrash': true,
      'group': 'SYSTEM',
    },
    {
      'label': 'Cloud Storage',
      'shortLabel': 'Storage',
      'icon': Icons.pie_chart_outline_rounded,
      'activeIcon': Icons.pie_chart_rounded,
      'group': 'SYSTEM',
    },
    {
      'label': 'AI Chat',
      'shortLabel': 'AI Chat',
      'icon': Icons.auto_awesome_outlined,
      'activeIcon': Icons.auto_awesome_rounded,
      'isAi': true,
      'group': 'INTELLIGENCE',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FilesProvider>(context, listen: false).fetchTrash();
      AppUpdateService.checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filesProvider = Provider.of<FilesProvider>(context);
    final trashCount = filesProvider.trashFiles.length;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 850;

    return NavigationTabController(
      currentIndex: _currentIndex,
      onSelectTab: (idx) => setState(() => _currentIndex = idx),
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      child: PopScope(
        canPop: _currentIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _currentIndex != 0) {
            setState(() => _currentIndex = 0);
          }
        },
        child: AmbientBackground(
          isDark: isDark,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            extendBody: true,
            drawer: isDesktop
                ? null
                : _buildNavigationDrawer(context, auth, isDark, trashCount),
            drawerEnableOpenDragGesture: !isDesktop,
            drawerEdgeDragWidth: isDesktop
                ? null
                : (screenWidth * 0.65).clamp(80.0, 260.0),
            // On desktop, we embed the GlobalTopBar inside the content column so sidebar runs full height
            appBar: isDesktop
                ? null
                : const GlobalTopBar(),
            body: isDesktop
                ? Row(
                    children: [
                      _buildDesktopSidebar(context, auth, isDark, trashCount),
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 64,
                              child: GlobalTopBar(),
                            ),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  clipBehavior: Clip.hardEdge,
                                  child: RepaintBoundary(
                                    child: _buildScreensStack(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _buildScreensStack(),
            bottomNavigationBar: null,
          ),
        ),
      ),
    );
  }

  Widget _buildScreensStack() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: _screens[_currentIndex],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP FULL-HEIGHT ACRYLIC SIDEBAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopSidebar(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
    int trashCount,
  ) {
    return RepaintBoundary(
      child: Container(
        width: 250,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF130B2A)
              : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : AppColors.lightBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.05),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const SizedBox(height: 20),
              // Brand Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cloud_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SPACES',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Personal Vault',
                                style: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.6) : AppColors.lightTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
              ),
              const SizedBox(height: 14),

              // Navigation Items List
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('EXPLORE', isDark),
                      _buildDesktopNavItem(0, trashCount, isDark),
                      _buildDesktopNavItem(1, trashCount, isDark),
                      _buildDesktopNavItem(2, trashCount, isDark),

                      const SizedBox(height: 16),
                      _buildSectionLabel('MANAGEMENT', isDark),
                      _buildDesktopNavItem(3, trashCount, isDark),
                      _buildDesktopNavItem(4, trashCount, isDark),

                      const SizedBox(height: 16),
                      _buildSectionLabel('INTELLIGENCE', isDark),
                      _buildDesktopNavItem(5, trashCount, isDark),
                    ],
                  ),
                ),
              ),

              // Bottom User Profile Card
              _buildUserProfileCard(context, auth, isDark),
            ],
          ),
        ),
      );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE ADAPTIVE NAVIGATION DRAWER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNavigationDrawer(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
    int trashCount,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth > 360 ? 300.0 : screenWidth * 0.85;

    return Drawer(
      width: drawerWidth,
      backgroundColor: isDark ? const Color(0xFF130B2A) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 20,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Header with Brand + Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SPACES',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Personal Vault',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.6)
                                    : AppColors.lightTextSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                      size: 22,
                    ),
                    tooltip: 'Close Menu',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
            ),
            const SizedBox(height: 12),

            // Navigation Items List
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('EXPLORE', isDark),
                    _buildDrawerNavItem(context, 0, trashCount, isDark),
                    _buildDrawerNavItem(context, 1, trashCount, isDark),
                    _buildDrawerNavItem(context, 2, trashCount, isDark),

                    const SizedBox(height: 16),
                    _buildSectionLabel('MANAGEMENT', isDark),
                    _buildDrawerNavItem(context, 3, trashCount, isDark),
                    _buildDrawerNavItem(context, 4, trashCount, isDark),

                    const SizedBox(height: 16),
                    _buildSectionLabel('INTELLIGENCE', isDark),
                    _buildDrawerNavItem(context, 5, trashCount, isDark),
                  ],
                ),
              ),
            ),

            // Bottom User Profile Card
            _buildUserProfileCard(
              context,
              auth,
              isDark,
              onSettingsPressed: () {
                Navigator.pop(context);
                SettingsContainerDialog.show(
                  context,
                  const ProfileScreen(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem(
    BuildContext context,
    int index,
    int trashCount,
    bool isDark,
  ) {
    final item = _navItems[index];
    final isSelected = _currentIndex == index;
    final isTrash = item['isTrash'] == true;
    final isAi = item['isAi'] == true;

    return _SideNavItemTile(
      item: item,
      isSelected: isSelected,
      isTrash: isTrash,
      isAi: isAi,
      trashCount: trashCount,
      isDark: isDark,
      onTap: () {
        Navigator.pop(context);
        FocusScope.of(context).unfocus();
        setState(() => _currentIndex = index);
      },
    );
  }

  Widget _buildUserProfileCard(
    BuildContext context,
    AuthProvider auth,
    bool isDark, {
    VoidCallback? onSettingsPressed,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.35),
            child: Text(
              (auth.user?.firstName?.isNotEmpty == true)
                  ? auth.user!.firstName![0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.user?.firstName ?? 'User',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  auth.user?.email ?? 'Free Tier',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.55) : AppColors.lightTextTertiary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            ),
            tooltip: 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onSettingsPressed ??
                () {
                  SettingsContainerDialog.show(
                    context,
                    const ProfileScreen(),
                  );
                },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white.withOpacity(0.4) : AppColors.lightTextTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem(int index, int trashCount, bool isDark) {
    final item = _navItems[index];
    final isSelected = _currentIndex == index;
    final isTrash = item['isTrash'] == true;
    final isAi = item['isAi'] == true;

    return _SideNavItemTile(
      item: item,
      isSelected: isSelected,
      isTrash: isTrash,
      isAi: isAi,
      trashCount: trashCount,
      isDark: isDark,
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _currentIndex = index);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE SLEEK FLOATING GLASS BOTTOM NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileBottomNavigation(bool isDark, int trashCount) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      height: 70,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF130B2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.16) : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _currentIndex == index;
              final isTrash = item['isTrash'] == true;
              final isAi = item['isAi'] == true;

              return InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _currentIndex = index);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 12 : 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isAi
                            ? const Color(0xFF8B5CF6).withOpacity(isDark ? 0.28 : 0.16)
                            : isTrash
                                ? AppColors.error.withOpacity(isDark ? 0.22 : 0.14)
                                : const Color(0xFF8B5CF6).withOpacity(isDark ? 0.25 : 0.14))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.25)
                                : AppColors.primary.withOpacity(0.3),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isSelected ? item['activeIcon'] : item['icon'],
                            color: isSelected
                                ? (isAi
                                    ? (isDark ? const Color(0xFFA78BFA) : AppColors.primary)
                                    : isTrash
                                        ? const Color(0xFFF87171)
                                        : (isDark ? Colors.white : AppColors.primary))
                                : (isDark ? Colors.white60 : AppColors.lightTextSecondary),
                            size: 22,
                          ),
                          if (isTrash && trashCount > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  trashCount > 99 ? '99+' : '$trashCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Text(
                          item['shortLabel'],
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        );
  }
}

class _SideNavItemTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final bool isTrash;
  final bool isAi;
  final int trashCount;
  final bool isDark;
  final VoidCallback onTap;

  const _SideNavItemTile({
    required this.item,
    required this.isSelected,
    required this.isTrash,
    required this.isAi,
    required this.trashCount,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SideNavItemTile> createState() => _SideNavItemTileState();
}

class _SideNavItemTileState extends State<_SideNavItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color activeAccent = const Color(0xFFA78BFA);
    if (widget.isTrash) activeAccent = const Color(0xFFF87171);
    if (widget.isAi) activeAccent = const Color(0xFF8B5CF6);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: widget.isSelected
                ? const Color(0xFF8B5CF6).withOpacity(widget.isDark ? 0.24 : 0.12)
                : (_isHovered
                    ? (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04))
                    : Colors.transparent),
            border: widget.isSelected
                ? Border.all(
                    color: activeAccent.withOpacity(widget.isDark ? 0.45 : 0.35),
                    width: 1,
                  )
                : Border.all(
                    color: _isHovered
                        ? (widget.isDark ? Colors.white.withOpacity(0.12) : AppColors.lightBorder)
                        : Colors.transparent,
                    width: 1,
                  ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: activeAccent.withOpacity(widget.isDark ? 0.2 : 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Active Indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: widget.isSelected ? 18 : 0,
                decoration: BoxDecoration(
                  color: activeAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: widget.isSelected ? 8 : 4),
              Icon(
                widget.isSelected
                    ? widget.item['activeIcon']
                    : widget.item['icon'],
                color: widget.isSelected
                    ? (widget.isDark ? Colors.white : AppColors.primary)
                    : (widget.isDark
                        ? (_isHovered ? Colors.white : Colors.white60)
                        : (_isHovered ? AppColors.lightTextPrimary : AppColors.lightTextSecondary)),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item['label'],
                  style: TextStyle(
                    color: widget.isSelected
                        ? (widget.isDark ? Colors.white : AppColors.primary)
                        : (widget.isDark
                            ? (_isHovered ? Colors.white : Colors.white70)
                            : (_isHovered ? AppColors.lightTextPrimary : AppColors.lightTextSecondary)),
                    fontSize: 13.5,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isTrash && widget.trashCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.trashCount > 99 ? '99+' : '${widget.trashCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (widget.isAi)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
