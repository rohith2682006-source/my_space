import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../offline/offline_files_screen.dart';
import '../sharing/request_links_screen.dart';
import '../ai/dropzone_screen.dart';
import '../../widgets/settings_container_dialog.dart';
import '../../widgets/settings_group.dart';

class UtilitiesSettingsScreen extends StatelessWidget {
  const UtilitiesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScreenScaffold(
      title: 'Tools & Utilities',
      subtitle: 'Manage offline document caching, dropzones & request links',
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Offline & Sync Group
          SettingsGroup(
            header: 'Offline Storage',
            footer:
                'Pinned and cached documents remain accessible on this machine even without internet connectivity.',
            children: [
              SettingsRow(
                icon: Icons.offline_pin_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Offline Files & Vault Cache',
                subtitle: 'Browse and inspect documents pinned for offline work',
                onTap: () => Navigator.of(context).push(_slidePageRoute(const OfflineFilesScreen())),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

          // File Ingestion Group
          SettingsGroup(
            header: 'Ingestion & Sharing',
            footer:
                'Allow clients and teammates to upload files directly into your vault with encrypted dropzones.',
            children: [
              SettingsRow(
                icon: Icons.link_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'File Request Links',
                subtitle: 'Create and revoke upload portals for external contributors',
                onTap: () => Navigator.of(context).push(_slidePageRoute(const RequestLinksScreen())),
              ),
              SettingsRow(
                icon: Icons.auto_awesome_motion_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'AI Smart Dropzone',
                subtitle: 'Intelligent multi-file drag-and-drop auto-categorization',
                onTap: () => Navigator.of(context).push(_slidePageRoute(const DropzoneScreen())),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 70.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Route _slidePageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (c, a, b) => page,
      transitionsBuilder: (c, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(position: slide, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
    );
  }
}

