import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/top_alert_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _overviewData;
  Map<String, dynamic>? _financialsData;
  List<dynamic>? _operatingCosts;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.adminOverview),
        ApiClient.get(ApiEndpoints.adminFinancials),
        ApiClient.get(ApiEndpoints.adminOperatingCosts),
      ]);

      if (!mounted) return;

      final overviewResp = results[0];
      final financialsResp = results[1];
      final costsResp = results[2];

      if (overviewResp.success && overviewResp.data != null) {
        setState(() {
          _overviewData = overviewResp.data as Map<String, dynamic>;
          _financialsData = financialsResp.success && financialsResp.data != null
              ? financialsResp.data as Map<String, dynamic>
              : null;
          _operatingCosts = costsResp.success && costsResp.data != null
              ? costsResp.data as List<dynamic>
              : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = overviewResp.message ??
              'Failed to load admin overview (requires admin privileges)';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _addOperatingCostDialog() async {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'SERVER';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
          title: const Text('Add Operating Cost', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'SERVER', child: Text('Server / Cloud')),
                    DropdownMenuItem(value: 'DATABASE', child: Text('Database')),
                    DropdownMenuItem(value: 'STORAGE', child: Text('Storage')),
                    DropdownMenuItem(value: 'BANDWIDTH', child: Text('Bandwidth')),
                    DropdownMenuItem(value: 'EMAIL', child: Text('Email / Notifications')),
                    DropdownMenuItem(value: 'PAYMENT_GATEWAY', child: Text('Payment Gateway')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label / Description',
                    hintText: 'e.g. AWS EC2 Instance',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Cost (USD)',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim());
                if (label.isEmpty || amount == null || amount <= 0) {
                  TopAlertBar.showError(context, 'Please enter valid label and amount');
                  return;
                }

                final resp = await ApiClient.post(
                  ApiEndpoints.adminOperatingCosts,
                  body: {
                    'category': category,
                    'label': label,
                    'amountUsd': amount,
                    'notes': notesCtrl.text.trim(),
                  },
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx, resp.success);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      _fetchAllData();
      if (mounted) {
        TopAlertBar.showSuccess(context, 'Operating cost added');
      }
    }
  }

  Future<void> _deleteOperatingCost(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Operating Cost'),
        content: const Text('Are you sure you want to remove this cost entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final resp = await ApiClient.delete(ApiEndpoints.adminDeleteOperatingCost(id));
      if (resp.success) {
        _fetchAllData();
        if (mounted) {
          TopAlertBar.showTrash(context, 'Operating cost deleted');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchAllData,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.accent,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Financials & Units'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Operating Costs'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchAllData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _buildOverviewTab(isDark),
                      _buildFinancialsTab(isDark),
                      _buildOperatingCostsTab(isDark),
                    ],
                  ),
      ),
    );
  }

  // ─── TAB 1: OVERVIEW ────────────────────────────────────────────────────────
  Widget _buildOverviewTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Platform & AI Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Real-time metrics, AI token consumption, and subscription breakdown.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Platform Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  '${_overviewData?["totalUsers"] ?? 0}',
                  Icons.people_outline_rounded,
                  const Color(0xFF6366F1),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active Subs',
                  '${_overviewData?["activeSubscriptions"] ?? 0}',
                  Icons.stars_rounded,
                  const Color(0xFF10B981),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Spaces',
                  '${_overviewData?["totalSpaces"] ?? 0}',
                  Icons.folder_outlined,
                  const Color(0xFF06B6D4),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Files',
                  '${_overviewData?["totalFiles"] ?? 0}',
                  Icons.insert_drive_file_outlined,
                  const Color(0xFFF59E0B),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // AI Consumption Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF2E1065)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFFAF5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bolt_rounded, color: AppColors.accent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'AI Engine Consumption',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  'Total AI Queries',
                  '${_overviewData?["totalAiQueries"] ?? 0}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Credits Consumed',
                  '${_overviewData?["totalCreditsConsumed"] ?? 0} credits',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Tokens Processed',
                  '${((_overviewData?["totalTokens"] ?? 0) / 1000).toStringAsFixed(1)}k tokens',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Est. Upstream AI Cost',
                  '\$${((_overviewData?["estimatedAiCostUsd"] ?? 0) as num).toStringAsFixed(4)} USD',
                  valueColor: AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Plan Distribution
          const Text(
            'Plan Distribution',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...((_overviewData?['planDistribution'] as List<dynamic>?) ?? []).map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${p["count"]} subscribers',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── TAB 2: FINANCIALS & UNIT ECONOMICS ────────────────────────────────────
  Widget _buildFinancialsTab(bool isDark) {
    if (_financialsData == null) {
      return const Center(child: Text('Financial data not available'));
    }

    final mrr = (_financialsData!['mrrUsd'] as num?)?.toDouble() ?? 0.0;
    final arr = (_financialsData!['arrUsd'] as num?)?.toDouble() ?? 0.0;
    final arpu = (_financialsData!['arpuUsd'] as num?)?.toDouble() ?? 0.0;
    final grossRevInr = (_financialsData!['grossRevenueInr'] as num?)?.toDouble() ?? 0.0;
    final grossMargin = (_financialsData!['grossMarginPercent'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (_financialsData!['estimatedMonthlyNetProfitUsd'] as num?)?.toDouble() ?? 0.0;
    final operatingCost = (_financialsData!['totalOperatingCostMonthlyUsd'] as num?)?.toDouble() ?? 0.0;
    final aiCost = (_financialsData!['totalAiCostUsd'] as num?)?.toDouble() ?? 0.0;
    final unitEconomics = (_financialsData!['unitEconomics'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Revenue & Profitability',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Recurring revenue, upstream LLM expenses, operating margin, and unit economics.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // MRR & ARR Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Monthly MRR',
                  '\$${mrr.toStringAsFixed(2)}',
                  Icons.monetization_on_outlined,
                  const Color(0xFF10B981),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Annual ARR',
                  '\$${arr.toStringAsFixed(2)}',
                  Icons.trending_up_rounded,
                  const Color(0xFF6366F1),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'ARPU (Avg / Sub)',
                  '\$${arpu.toStringAsFixed(2)}',
                  Icons.person_pin_circle_outlined,
                  const Color(0xFF06B6D4),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Gross Margin',
                  '${grossMargin.toStringAsFixed(0)}%',
                  Icons.pie_chart_outline_rounded,
                  grossMargin >= 50 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // P&L Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly P&L Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(height: 24),
                _buildInfoRow('Monthly Subscriptions (MRR)', '\$${mrr.toStringAsFixed(2)}', valueColor: Colors.green),
                const SizedBox(height: 8),
                _buildInfoRow('Total Gross Revenue (Captured)', '₹${grossRevInr.toStringAsFixed(2)} INR'),
                const SizedBox(height: 8),
                _buildInfoRow('AI Inference / Upstream Cost', '-\$${aiCost.toStringAsFixed(4)}', valueColor: Colors.redAccent),
                const SizedBox(height: 8),
                _buildInfoRow('Fixed Operating Overhead', '-\$${operatingCost.toStringAsFixed(2)}', valueColor: Colors.orangeAccent),
                const Divider(height: 24),
                _buildInfoRow(
                  'Estimated Monthly Net Profit',
                  '\$${netProfit.toStringAsFixed(2)}',
                  valueColor: netProfit >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Unit Economics per Plan Tier
          const Text(
            'Unit Economics by Tier',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...unitEconomics.map((u) {
            final name = u['planName'] ?? 'Plan';
            final subs = u['subscribers'] ?? 0;
            final rev = (u['monthlyRevenueUsd'] as num?)?.toDouble() ?? 0.0;
            final credits = u['aiCreditsAllowance'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        '$subs subscribers • $credits AI credits/mo',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                    '\$${rev.toStringAsFixed(2)}/mo',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 15),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── TAB 3: OPERATING COSTS ────────────────────────────────────────────────
  Widget _buildOperatingCostsTab(bool isDark) {
    final costs = _operatingCosts ?? [];
    final totalMonthly = costs.fold<double>(
      0.0,
      (sum, item) => sum + ((item['amountUsd'] as num?)?.toDouble() ?? 0.0),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOperatingCostDialog,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Cost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operating Costs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fixed monthly server, cloud, and DB expenses.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total: \$${totalMonthly.toStringAsFixed(2)}/mo',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (costs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No operating costs recorded yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ...costs.map((c) {
                final id = c['id'] as String;
                final label = c['label'] as String? ?? '';
                final category = c['category'] as String? ?? 'OTHER';
                final amount = (c['amountUsd'] as num?)?.toDouble() ?? 0.0;
                final notes = c['notes'] as String?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _getCategoryColor(category).withValues(alpha: 0.15),
                        child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(
                              category + (notes != null && notes.isNotEmpty ? ' • $notes' : ''),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${amount.toStringAsFixed(2)}/mo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteOperatingCost(id),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80), // Fab spacing
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'SERVER':
        return const Color(0xFF6366F1);
      case 'DATABASE':
        return const Color(0xFF10B981);
      case 'STORAGE':
        return const Color(0xFF06B6D4);
      case 'BANDWIDTH':
        return const Color(0xFFF59E0B);
      case 'EMAIL':
        return const Color(0xFFEC4899);
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'SERVER':
        return Icons.dns_rounded;
      case 'DATABASE':
        return Icons.storage_rounded;
      case 'STORAGE':
        return Icons.cloud_outlined;
      case 'BANDWIDTH':
        return Icons.wifi_rounded;
      case 'EMAIL':
        return Icons.email_outlined;
      default:
        return Icons.attach_money_rounded;
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
