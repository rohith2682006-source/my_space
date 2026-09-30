import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/files_provider.dart';
import '../widgets/navigation_tab_controller.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import 'recent/recent_screen.dart';
import 'search/search_screen.dart';
import 'favorites/favorites_screen.dart';
import 'trash/trash_screen.dart';
import 'storage/storage_screen.dart';
import 'ai/ai_chat_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int? _hoveredIndex;

  final List<Widget> _screens = const [
    HomeScreen(),
    RecentScreen(),
    SearchScreen(),
    FavoritesScreen(),
    TrashScreen(),
    StorageScreen(),
    AiChatScreen(),
  ];

  final List<Map<String, dynamic>> _navItems = [
    {
      'label': 'Spaces',
      'icon': Icons.grid_view_rounded,
      'activeIcon': Icons.grid_view_rounded,
    },
    {
      'label': 'Recent',
      'icon': Icons.history_rounded,
      'activeIcon': Icons.history_toggle_off_rounded,
    },
    {
      'label': 'Search',
      'icon': Icons.search_rounded,
      'activeIcon': Icons.saved_search_rounded,
    },
    {
      'label': 'Favorites',
      'icon': Icons.star_outline_rounded,
      'activeIcon': Icons.star_rounded,
    },
    {
      'label': 'Trash',
      'icon': Icons.delete_outline_rounded,
      'activeIcon': Icons.delete_rounded,
      'isTrash': true,
    },
    {
      'label': 'Storage',
      'icon': Icons.pie_chart_outline_rounded,
      'activeIcon': Icons.pie_chart_rounded,
    },
    {
      'label': 'AI Search',
      'icon': Icons.auto_awesome_outlined,
      'activeIcon': Icons.auto_awesome_rounded,
      'isAi': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FilesProvider>(context, listen: false).fetchTrash();
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

    return NavigationTabController(
      currentIndex: _currentIndex,
      onSelectTab: (idx) => setState(() => _currentIndex = idx),
      child: PopScope(
        canPop: _currentIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _currentIndex != 0) {
            setState(() => _currentIndex = 0);
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              // Screen contents with bottom padding so floating dock doesn't obscure content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 84),
                  child: IndexedStack(index: _currentIndex, children: _screens),
                ),
              ),

          // Apple-Style Floating Dynamic Dock / Taskbar
          Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xCC111827)
                              : const Color(0xE0FFFFFF),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.14)
                                : Colors.black.withOpacity(0.08),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.45 : 0.15,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_navItems.length, (index) {
                            final item = _navItems[index];
                            final isSelected = _currentIndex == index;
                            final isHovered = _hoveredIndex == index;
                            final isTrash = item['isTrash'] == true;

                            return MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoveredIndex = index),
                              onExit: (_) =>
                                  setState(() => _hoveredIndex = null),
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _currentIndex = index);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSelected ? 16 : 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark
                                              ? AppColors.primary.withOpacity(
                                                  0.22,
                                                )
                                              : AppColors.primary.withOpacity(
                                                  0.12,
                                                ))
                                        : (isHovered
                                              ? (isDark
                                                    ? Colors.white10
                                                    : Colors.black12)
                                              : Colors.transparent),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  transform: Matrix4.identity()
                                    ..scale(
                                      isHovered
                                          ? 1.12
                                          : (isSelected ? 1.05 : 1.0),
                                    ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Animated Icon
                                          AnimatedScale(
                                            scale: isSelected ? 1.15 : 1.0,
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: Icon(
                                              isSelected
                                                  ? item['activeIcon']
                                                  : item['icon'],
                                              size: 22,
                                              color: isSelected
                                                  ? (isTrash
                                                        ? AppColors.error
                                                        : (item['isAi'] == true
                                                            ? const Color(0xFF8B5CF6)
                                                            : AppColors.primary))
                                                  : (isDark
                                                        ? AppColors
                                                              .darkTextSecondary
                                                        : AppColors
                                                              .lightTextSecondary),
                                            ),
                                          ),
                                          // Text label shown on active tab
                                          AnimatedSize(
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            curve: Curves.easeInOut,
                                            child: isSelected
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 8,
                                                        ),
                                                    child: Text(
                                                      item['label'],
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isTrash
                                                            ? AppColors.error
                                                            : (isDark
                                                                  ? Colors.white
                                                                  : AppColors
                                                                        .primaryDark),
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),

                                      // Badge for Trash when items are present
                                      if (isTrash && trashCount > 0)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child:
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF111827,
                                                          )
                                                        : Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  '$trashCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ).animate().scale(
                                                duration: 300.ms,
                                                curve: Curves.elasticOut,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.3, curve: Curves.easeOutBack),

          if (_currentIndex != _screens.length - 1)
            Positioned(
              right: 18,
              bottom: 98,
              child: FloatingActionButton.extended(
                heroTag: 'spaces-ai-assistant',
                tooltip: 'Open Spaces Assistant',
                onPressed: () =>
                    setState(() => _currentIndex = _screens.length - 1),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Assistant'),
              ),
            ),
        ],
      ),
    ),
  ),
);
  }
}
