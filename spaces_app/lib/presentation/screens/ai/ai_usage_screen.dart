import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/ai_credits_provider.dart';
import '../plans/plans_screen.dart';

class AiUsageScreen extends StatefulWidget {
  const AiUsageScreen({super.key});

  @override
  State<AiUsageScreen> createState() => _AiUsageScreenState();
}

class _AiUsageScreenState extends State<AiUsageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiCreditsProvider>().fetchBalance();
      context.read<AiCreditsProvider>().fetchHistory();
      context.read<AiCreditsProvider>().fetchUsageStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AiCreditsProvider>();
    final balance = provider.balance;
    final stats = provider.usageStats;
    final history = provider.history;

    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('AI Credits & Usage', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'View Plans',
            icon: const Icon(Icons.stars_rounded, color: AppColors.accent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlansScreen()),
              );
            },
          ),
        ],
      ),
      body: provider.isLoading && balance == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await provider.fetchBalance();
                await provider.fetchHistory();
                await provider.fetchUsageStats();
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Balance Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                            : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 16,
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
                            const Text(
                              'Available Balance',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI Credits',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${balance?.balance ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total used this cycle: ${balance?.totalUsed ?? 0} credits',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        if (balance != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Renews on ${DateFormat("MMM d, yyyy").format(balance.periodEnd)}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.accent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PlansScreen()),
                                  );
                                },
                                child: const Text('Upgrade Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Queries',
                          '${stats?.totalQueries ?? 0}',
                          Icons.query_builder_rounded,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          'Tokens',
                          '${((stats?.totalTokens ?? 0) / 1000).toStringAsFixed(1)}k',
                          Icons.token_rounded,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          'Deep RAG',
                          '5 cr/q',
                          Icons.psychology_rounded,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Operations breakdown
                  if (stats != null && stats.operationsBreakdown.isNotEmpty) ...[
                    const Text(
                      'Usage by Operation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...stats.operationsBreakdown.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.accent.withOpacity(0.12),
                            child: Icon(
                              item.operation == 'DEEP_SEARCH'
                                  ? Icons.auto_awesome_rounded
                                  : Icons.search_rounded,
                              color: AppColors.accent,
                            ),
                          ),
                          title: Text(
                            item.operation == 'DEEP_SEARCH'
                                ? 'Deep RAG Search'
                                : (item.operation == 'QUICK_SEARCH'
                                    ? 'Quick Search'
                                    : 'AI Assistant Chat'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            '${item.count} queries',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Transaction History
                  const Text(
                    'Credit Ledger & Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, size: 40, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          const Text('No credit transactions yet', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ...history.map((tx) {
                      final isDeduction = tx.isDeduction;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: (isDeduction ? AppColors.error : AppColors.success).withOpacity(0.12),
                              child: Icon(
                                isDeduction ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isDeduction ? AppColors.error : AppColors.success,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.description ?? tx.operation,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateFormat.format(tx.createdAt),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isDeduction ? "" : "+"}${tx.creditsChange} cr',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: isDeduction ? AppColors.error : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
