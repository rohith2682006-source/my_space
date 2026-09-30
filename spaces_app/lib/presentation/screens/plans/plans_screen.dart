import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/plans_provider.dart';
import '../../../providers/ai_credits_provider.dart';
import '../../../data/models/plan_model.dart';
import '../../widgets/top_alert_bar.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String _billingCycle = 'monthly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlansProvider>().fetchPlans();
      context.read<PlansProvider>().fetchCurrentSubscription();
      context.read<AiCreditsProvider>().fetchBalance();
    });
  }

  void _showUpgradeDialog(PlanModel plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Upgrade to ${plan.displayName}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are upgrading to ${plan.displayName} for ${plan.priceMonthly == 0 ? "Free" : "\$${plan.priceMonthly}/mo"}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${plan.storageFormatted} Cloud Storage', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('• ${plan.aiCreditsMonthly} AI Credits / month', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('• ${plan.deepSearchLimit == -1 ? "Unlimited" : plan.deepSearchLimit} Deep RAG Searches', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('• ${plan.aiEnabledFileLimit == -1 ? "Unlimited" : plan.aiEnabledFileLimit} AI-Indexed Files', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
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
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<PlansProvider>().upgradePlan(plan.id, billingCycle: _billingCycle);
              if (mounted) {
                if (success) {
                  context.read<AiCreditsProvider>().fetchBalance();
                  TopAlertBar.showSuccess(
                    context,
                    '🎉 Upgraded to ${plan.displayName} successfully!',
                  );
                } else {
                  final error = context.read<PlansProvider>().errorMessage;
                  TopAlertBar.showError(
                    context,
                    error ?? 'Failed to upgrade plan',
                  );
                }
              }
            },
            child: const Text('Confirm & Pay'),
          ),
        ],
      ),
    );
  }

  void _showCreditPackSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buy AI Credits Pack',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add instant one-time credits to your account. Credits never expire.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildCreditPackTile(100, 99),
            const SizedBox(height: 12),
            _buildCreditPackTile(500, 399, isPopular: true),
            const SizedBox(height: 12),
            _buildCreditPackTile(1200, 799),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditPackTile(int credits, int priceInr, {bool isPopular = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPopular ? AppColors.accent : Colors.grey.withOpacity(0.25),
          width: isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withOpacity(0.12),
          child: const Icon(Icons.bolt_rounded, color: AppColors.accent),
        ),
        title: Text(
          '$credits AI Credits',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '~${(credits / 5).floor()} Deep Searches or $credits Quick Searches',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isPopular ? AppColors.accent : null,
            foregroundColor: isPopular ? Colors.white : null,
          ),
          onPressed: () async {
            Navigator.pop(context);
            final success = await context.read<AiCreditsProvider>().buyCredits(credits, priceInr);
            if (mounted) {
              if (success) {
                TopAlertBar.showSuccess(
                  context,
                  '⚡ Added $credits AI credits to your account!',
                );
              } else {
                TopAlertBar.showError(
                  context,
                  'Payment failed. Please try again.',
                );
              }
            }
          },
          child: Text('₹$priceInr'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plansProvider = context.watch<PlansProvider>();
    final creditsProvider = context.watch<AiCreditsProvider>();
    final currentSub = plansProvider.currentSubscription;
    final activePlanId = currentSub?.planId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Plans & Storage', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ActionChip(
              avatar: const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 18),
              label: Text(
                '${creditsProvider.currentCredits} cr',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
              ),
              backgroundColor: AppColors.accent.withOpacity(0.12),
              onPressed: _showCreditPackSheet,
            ),
          ),
        ],
      ),
      body: plansProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await plansProvider.fetchPlans();
                await plansProvider.fetchCurrentSubscription();
                await creditsProvider.fetchBalance();
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                            : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.accent,
                          child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Plan: ${currentSub?.plan?.displayName ?? "Free"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${creditsProvider.currentCredits} AI credits remaining this period',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _showCreditPackSheet,
                          child: const Text('Top Up'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Available Subscription Tiers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Plans cards
                  ...plansProvider.plans.map((plan) {
                    final isCurrent = plan.id == activePlanId;
                    return _buildPlanCard(plan, isCurrent, isDark);
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(PlanModel plan, bool isCurrent, bool isDark) {
    final isPro = plan.name == 'pro';
    final isPlus = plan.name == 'plus';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? AppColors.accent
              : (isDark ? Colors.white12 : Colors.black12),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CURRENT',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  plan.priceMonthly == 0 ? 'Free' : '\$${plan.priceMonthly}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (plan.priceMonthly > 0)
                  const Text(' / month', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 28),
            _buildFeatureRow(Icons.cloud_outlined, '${plan.storageFormatted} Secure Cloud Storage'),
            const SizedBox(height: 8),
            _buildFeatureRow(Icons.bolt_rounded, '${plan.aiCreditsMonthly} Monthly AI Credits', isBold: true),
            const SizedBox(height: 8),
            _buildFeatureRow(
              Icons.search_rounded,
              '${plan.quickSearchLimit == -1 ? "Unlimited" : plan.quickSearchLimit} Quick Searches / month',
            ),
            const SizedBox(height: 8),
            _buildFeatureRow(
              Icons.auto_awesome_rounded,
              '${plan.deepSearchLimit == -1 ? "Unlimited" : plan.deepSearchLimit} Deep RAG Searches / month',
            ),
            const SizedBox(height: 8),
            _buildFeatureRow(
              Icons.document_scanner_rounded,
              '${plan.aiEnabledFileLimit == -1 ? "Unlimited" : plan.aiEnabledFileLimit} AI-Searchable Documents',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent
                      ? (isDark ? Colors.white12 : Colors.grey.shade200)
                      : AppColors.accent,
                  foregroundColor: isCurrent
                      ? (isDark ? Colors.white70 : Colors.black87)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isCurrent ? 0 : 2,
                ),
                onPressed: isCurrent ? null : () => _showUpgradeDialog(plan),
                child: Text(
                  isCurrent ? 'Current Plan' : (isPro || isPlus ? 'Upgrade to ${plan.displayName}' : 'Downgrade to Free'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
