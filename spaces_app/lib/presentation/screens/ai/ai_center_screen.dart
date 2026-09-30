import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/ai_credits_provider.dart';
import '../../../providers/files_provider.dart';
import '../../../providers/plans_provider.dart';
import 'ai_chat_screen.dart';
import 'ai_usage_screen.dart';
import '../plans/plans_screen.dart';

class AiCenterScreen extends StatefulWidget {
  const AiCenterScreen({super.key});

  @override
  State<AiCenterScreen> createState() => _AiCenterScreenState();
}

class _AiCenterScreenState extends State<AiCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiCreditsProvider>().fetchBalance();
      context.read<PlansProvider>().fetchCurrentSubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creditsProvider = context.watch<AiCreditsProvider>();
    final plansProvider = context.watch<PlansProvider>();
    final filesProvider = context.watch<FilesProvider>();

    final balance = creditsProvider.currentCredits;
    final planName = plansProvider.currentSubscription?.plan?.displayName ?? 'Free';

    // Count AI-enabled files
    final aiEnabledCount = filesProvider.files.where((f) => f.aiSearchEnabled).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('AI Center', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ActionChip(
              avatar: const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 18),
              label: Text(
                '$balance cr',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
              ),
              backgroundColor: AppColors.accent.withOpacity(0.12),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiUsageScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                    : [const Color(0xFF4338CA), const Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'PLAN: ${planName.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PlansScreen()),
                        );
                      },
                      child: const Text(
                        'Manage Plan →',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Intelligent Document Retrieval & Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Search inside your PDFs, notes, and documents with citation-backed AI answers.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Ask Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiChatScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features Grid
          const Text(
            'AI Capabilities',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          // Quick Search Tile
          _buildActionCard(
            title: 'Quick Search',
            subtitle: 'Fast keyword & vector retrieval across all indexed documents.',
            costLabel: '1 Credit / query',
            icon: Icons.search_rounded,
            color: const Color(0xFF06B6D4),
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiChatScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Deep Search Tile
          _buildActionCard(
            title: 'Deep RAG Search & Synthesis',
            subtitle: 'Multi-document analysis with precise page-level excerpts & citations.',
            costLabel: '5 Credits / query',
            icon: Icons.auto_awesome_rounded,
            color: AppColors.accent,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiChatScreen()),
              );
            },
          ),
          const SizedBox(height: 24),

          // Document Privacy & Management
          const Text(
            'Security & Controls',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.success, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Zero Training Guarantee',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Text(
                      '$aiEnabledCount active',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your private notes and documents are never used to train public AI models. Only files you explicitly allow are indexed with secure chunk encryption.',
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.insert_chart_outlined_rounded, size: 18),
                        label: const Text('Usage Stats'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiUsageScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.stars_rounded, size: 18),
                        label: const Text('Plans & Tiers'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlansScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String costLabel,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          costLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
