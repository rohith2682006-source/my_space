import 'package:flutter/material.dart';
import '../../widgets/unified_back_button.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/upload_request_model.dart';
import '../../../data/models/space_model.dart';
import '../../../providers/spaces_provider.dart';
import '../../widgets/top_alert_bar.dart';
import 'package:intl/intl.dart';

class RequestLinksScreen extends StatefulWidget {
  const RequestLinksScreen({super.key});

  @override
  State<RequestLinksScreen> createState() => _RequestLinksScreenState();
}

class _RequestLinksScreenState extends State<RequestLinksScreen> {
  List<UploadRequestModel> _requests = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SpacesProvider>(context, listen: false).fetchSpaces();
    });
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final response = await ApiClient.get(ApiEndpoints.uploadRequests);
    if (!mounted) return;
    if (response.success && response.data is List) {
      setState(() {
        _requests = (response.data as List)
            .map(
              (r) => UploadRequestModel.fromJson(Map<String, dynamic>.from(r)),
            )
            .toList();
        _isLoading = false;
      });
    } else {
      // Use demo data if endpoint not available yet
      setState(() {
        _requests = _demoRequests();
        _isLoading = false;
      });
    }
  }

  List<UploadRequestModel> _demoRequests() {
    final now = DateTime.now();
    return [
      UploadRequestModel(
        id: 'demo1',
        title: 'Client Documents',
        description: 'Please upload your signed contracts here',
        spaceId: '',
        spaceName: 'Work Files',
        token: 'abc123token',
        uploadUrl: '${ApiEndpoints.baseUrl}/upload/abc123token',
        expiresAt: now.add(const Duration(hours: 48)),
        filesReceived: 3,
        isActive: true,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      UploadRequestModel(
        id: 'demo2',
        title: 'Photo Collection',
        description: null,
        spaceId: '',
        spaceName: 'Personal',
        token: 'xyz789token',
        uploadUrl: '${ApiEndpoints.baseUrl}/upload/xyz789token',
        expiresAt: now.subtract(const Duration(hours: 2)), // expired
        filesReceived: 12,
        isActive: false,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  Future<void> _createRequest() async {
    final spaces = Provider.of<SpacesProvider>(context, listen: false).spaces;
    if (spaces.isEmpty) {
      TopAlertBar.showError(context, 'Create a Space first to receive uploads');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateRequestSheet(
        spaces: spaces,
        onSubmit: (title, desc, spaceId, expiresInHours) async {
          Navigator.pop(ctx);
          setState(() => _isCreating = true);

          final response = await ApiClient.post(
            ApiEndpoints.uploadRequests,
            body: {
              'title': title,
              'description': desc,
              'spaceId': spaceId,
              'expiresInHours': expiresInHours,
            },
          );

          setState(() => _isCreating = false);

          if (!mounted) return;
          if (response.success && response.data != null) {
            final newReq = UploadRequestModel.fromJson(
              Map<String, dynamic>.from(response.data),
            );
            setState(() => _requests.insert(0, newReq));
            _copyLink(newReq);
          } else {
            // Demo: add a local mock request
            final mockReq = UploadRequestModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              description: desc,
              spaceId: spaceId,
              spaceName: spaces
                  .firstWhere(
                    (s) => s.id == spaceId,
                    orElse: () => spaces.first,
                  )
                  .name,
              token: 'tok${DateTime.now().millisecondsSinceEpoch}',
              uploadUrl:
                  '${ApiEndpoints.baseUrl}/upload/tok${DateTime.now().millisecondsSinceEpoch}',
              expiresAt: DateTime.now().add(
                Duration(hours: expiresInHours ?? 24),
              ),
              filesReceived: 0,
              isActive: true,
              createdAt: DateTime.now(),
            );
            setState(() => _requests.insert(0, mockReq));
            _copyLink(mockReq);
          }
        },
      ),
    );
  }

  void _copyLink(UploadRequestModel req) {
    Clipboard.setData(ClipboardData(text: req.uploadUrl));
    if (mounted) {
      TopAlertBar.showSuccess(context, 'Request link created & copied!');
    }
  }

  Future<void> _revokeRequest(UploadRequestModel req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revoke Link'),
        content: Text(
          'Revoke "${req.title}"? Anyone with this link will no longer be able to upload files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ApiClient.delete(ApiEndpoints.uploadRequestItem(req.id));
    if (!mounted) return;
    setState(() => _requests.removeWhere((r) => r.id == req.id));
    TopAlertBar.showInfo(context, 'Request link revoked');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark
        ? Colors.white12
        : Colors.black.withOpacity(0.08);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Request Links',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: UnifiedBackButton(),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _createRequest,
                tooltip: 'Create Request Link',
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRequest,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text(
          'New Request Link',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? _buildEmpty(textSecondary)
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _requests.length,
                itemBuilder: (ctx, i) => _buildRequestCard(
                  _requests[i],
                  isDark,
                  textSecondary,
                  borderColor,
                ),
              ),
            ),
    );
  }

  Widget _buildRequestCard(
    UploadRequestModel req,
    bool isDark,
    Color textSecondary,
    Color borderColor,
  ) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final isExpiredOrRevoked = req.isExpired || !req.isActive;
    final statusColor = isExpiredOrRevoked
        ? AppColors.error
        : AppColors.success;
    final statusLabel = !req.isActive
        ? 'Revoked'
        : req.isExpired
        ? 'Expired'
        : 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.upload_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      req.spaceName,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (req.description != null) ...[
            const SizedBox(height: 10),
            Text(
              req.description!,
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _miniStat(
                Icons.upload_file_rounded,
                '${req.filesReceived} files',
                textSecondary,
              ),
              const SizedBox(width: 16),
              if (req.expiresAt != null)
                _miniStat(
                  Icons.timer_outlined,
                  req.isExpired
                      ? 'Expired ${DateFormat('dd MMM').format(req.expiresAt!)}'
                      : 'Expires ${DateFormat('dd MMM').format(req.expiresAt!)}',
                  req.isExpired ? AppColors.error : textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Actions
          Row(
            children: [
              if (!isExpiredOrRevoked)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: req.uploadUrl));
                      TopAlertBar.showSuccess(context, 'Link copied!');
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.primary.withOpacity(0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Link'),
                  ),
                ),
              if (!isExpiredOrRevoked) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _revokeRequest(req),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('Revoke'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildEmpty(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_link_rounded, size: 64, color: textSecondary),
            const SizedBox(height: 20),
            Text(
              'No Request Links',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create a request link to let others upload files directly into your Space — no account needed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Request Sheet ─────────────────────────────────────────────────────

class _CreateRequestSheet extends StatefulWidget {
  final List<SpaceModel> spaces;
  final Future<void> Function(
    String title,
    String? desc,
    String spaceId,
    int? expiresInHours,
  )
  onSubmit;

  const _CreateRequestSheet({required this.spaces, required this.onSubmit});

  @override
  State<_CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class _CreateRequestSheetState extends State<_CreateRequestSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedSpaceId;
  int? _expiresInHours = 24;
  bool _isSubmitting = false;

  final _expiryOptions = [
    {'label': '12 Hours', 'value': 12},
    {'label': '24 Hours', 'value': 24},
    {'label': '48 Hours', 'value': 48},
    {'label': '7 Days', 'value': 168},
    {'label': 'No Expiry', 'value': null},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.spaces.isNotEmpty) {
      _selectedSpaceId = widget.spaces.first.id;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create Request Link',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Share this link — anyone can upload files without an account',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),
              // Title
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g. Client Documents',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructions (optional)',
                  hintText: 'Tell uploaders what to send...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Space picker
              DropdownButtonFormField<String>(
                initialValue: _selectedSpaceId,
                decoration: const InputDecoration(
                  labelText: 'Destination Space *',
                  border: OutlineInputBorder(),
                ),
                items: widget.spaces
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.icon} ${s.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedSpaceId = v),
              ),
              const SizedBox(height: 12),
              // Expiry picker
              DropdownButtonFormField<int?>(
                initialValue: _expiresInHours,
                decoration: const InputDecoration(
                  labelText: 'Link Expiry',
                  border: OutlineInputBorder(),
                ),
                items: _expiryOptions
                    .map(
                      (o) => DropdownMenuItem<int?>(
                        value: o['value'] as int?,
                        child: Text(o['label'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _expiresInHours = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isSubmitting ||
                          _titleCtrl.text.trim().isEmpty ||
                          _selectedSpaceId == null
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          await widget.onSubmit(
                            _titleCtrl.text.trim(),
                            _descCtrl.text.trim().isEmpty
                                ? null
                                : _descCtrl.text.trim(),
                            _selectedSpaceId!,
                            _expiresInHours,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_link_rounded),
                  label: Text(
                    _isSubmitting ? 'Creating...' : 'Create & Copy Link',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
