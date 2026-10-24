import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../screens/activity/activity_feed_screen.dart';
import '../screens/sharing/my_links_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'settings_container_dialog.dart';

import 'navigation_tab_controller.dart';

class GlobalTopBar extends StatefulWidget implements PreferredSizeWidget {
  const GlobalTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<GlobalTopBar> createState() => _GlobalTopBarState();
}

class _GlobalTopBarState extends State<GlobalTopBar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 850;
    final isNarrow = width < 520;

    return AppBar(
      // Only reserve status-bar space when used as the Scaffold appBar (mobile).
      // On desktop it is embedded in a Column, where extra top inset bloated it.
      primary: !isDesktop,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF130B2A) : const Color(0xFFF6F4EE),
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white12 : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
        ),
      ),
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: 64,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12.0 : 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isDesktop) ...[
              IconButton(
                icon: const Icon(Icons.menu_rounded, size: 26),
                tooltip: 'Open Menu',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(right: 8),
                constraints: const BoxConstraints(),
                onPressed: () {
                  NavigationTabController.of(context)?.onOpenDrawer?.call();
                  Scaffold.maybeOf(context)?.openDrawer();
                },
              ),
            ],
            Flexible(child: _buildProfileContent(context, auth, isDark, isNarrow)),
            _buildActionsContent(context, themeProvider, isDark, isNarrow),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
    bool isNarrow,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: isNarrow ? 34 : 44,
                height: isNarrow ? 34 : 44,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: isNarrow ? 12 : 16,
                height: isNarrow ? 12 : 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF111827) : Colors.white,
                    width: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: isNarrow ? 8 : 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello, ${auth.user?.firstName ?? 'Organizer'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isNarrow ? 15 : 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isNarrow ? 8 : 10,
                    height: isNarrow ? 8 : 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Spaces Cloud',
                    style: TextStyle(
                      fontSize: isNarrow ? 11 : 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsContent(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
    bool isNarrow,
  ) {
    final iconSize = isNarrow ? 22.0 : 26.0;
    return Wrap(
      spacing: isNarrow ? 2 : 6,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
          padding: EdgeInsets.all(isNarrow ? 5 : 8),
          icon: Icon(
            Icons.bolt_rounded,
            size: iconSize,
            color: const Color(0xFF8B5CF6),
          ),
          tooltip: 'Activity Feed',
          onPressed: () {
            Navigator.push(
              context,
              AppRoute(builder: (_) => const ActivityFeedScreen()),
            );
          },
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
          padding: EdgeInsets.all(isNarrow ? 5 : 8),
          icon: Icon(
            Icons.link_rounded,
            size: iconSize,
            color: AppColors.primary,
          ),
          tooltip: 'My Share Links',
          onPressed: () {
            Navigator.push(
              context,
              AppRoute(builder: (_) => const MyLinksScreen()),
            );
          },
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
          padding: EdgeInsets.all(isNarrow ? 5 : 8),
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: iconSize,
          ),
          tooltip: 'Toggle Theme',
          onPressed: () => themeProvider.toggleTheme(),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
          padding: EdgeInsets.all(isNarrow ? 5 : 8),
          icon: Icon(Icons.settings_outlined, size: iconSize),
          tooltip: 'Account Settings',
          onPressed: () {
            SettingsContainerDialog.show(context, const ProfileScreen());
          },
        ),
      ],
    );
  }
}
