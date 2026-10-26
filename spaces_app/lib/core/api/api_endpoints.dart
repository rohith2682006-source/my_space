import 'package:flutter/foundation.dart';

class ApiEndpoints {
  static const String _envUrl = String.fromEnvironment('API_BASE_URL');

  // Smart base URL:
  // - If passed explicitly via --dart-define=API_BASE_URL=..., use that.
  // - On Desktop (Windows/macOS/Linux), use your fast local backend (http://localhost:3000/api/v1).
  // - On Mobile (Android/iOS), connect to live Render cloud backend.
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      return 'http://localhost:3000/api/v1';
    }
    return 'https://my-space-backend-wbdw.onrender.com/api/v1';
  }

  // Auth
  static String get register => '$baseUrl/auth/register';
  static String get login => '$baseUrl/auth/login';
  static String get googleLogin => '$baseUrl/auth/google';
  static String get refresh => '$baseUrl/auth/refresh';
  static String get me => '$baseUrl/auth/me';
  static String get logout => '$baseUrl/auth/logout';
  static String get logoutAll => '$baseUrl/auth/logout-all';
  static String get changePassword => '$baseUrl/auth/change-password';
  static String get verifyAccount => '$baseUrl/auth/verify-account';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get verifyOtp => '$baseUrl/auth/verify-otp';
  static String get resetPassword => '$baseUrl/auth/reset-password';

  // Spaces
  static String get spaces => '$baseUrl/spaces';
  static String space(String id) => '$baseUrl/spaces/$id';
  static String spaceMembers(String id) => '$baseUrl/spaces/$id/members';

  // Files
  static String spaceFiles(String spaceId) =>
      '$baseUrl/files/spaces/$spaceId';
  static String uploadFile(String spaceId) =>
      '$baseUrl/files/spaces/$spaceId/upload';
  static String get createNoteOrLink => '$baseUrl/files/notes-links';
  static String file(String id) => '$baseUrl/files/$id';
  static String fileDownload(String id) => '$baseUrl/files/$id/download';
  static String filePreview(String id) => '$baseUrl/files/$id/preview';
  static String fileRename(String id) => '$baseUrl/files/$id/rename';
  static String fileMove(String id) => '$baseUrl/files/$id/move';
  static String fileFavorite(String id) => '$baseUrl/files/$id/favorite';
  static String fileAiAccess(String id) => '$baseUrl/files/$id/ai-access';
  static String fileTrash(String id) => '$baseUrl/files/$id/trash';
  static String fileRestore(String id) => '$baseUrl/files/$id/restore';
  static String filePermanent(String id) => '$baseUrl/files/$id/permanent';

  // File Version History
  static String fileVersions(String id) => '$baseUrl/files/$id/versions';
  static String restoreVersion(String fileId, String versionId) =>
      '$baseUrl/files/$fileId/versions/$versionId/restore';

  // Discovery
  static String get search => '$baseUrl/search';
  static String get recent => '$baseUrl/recent';
  static String get favorites => '$baseUrl/favorites';
  static String get trash => '$baseUrl/trash';
  static String get storage => '$baseUrl/storage';

  // Upload Requests (Request Links)
  static String get uploadRequests => '$baseUrl/upload-requests';
  static String uploadRequestItem(String id) => '$baseUrl/upload-requests/$id';

  // Vault Auth
  static String vaultVerify(String spaceId) => '$baseUrl/spaces/$spaceId/vault/verify';

  // Sharing
  static String get shareLinks => '$baseUrl/share';
  static String resolveShareLink(String token) =>
      '$baseUrl/share/resolve/$token';
  static String get myShareLinks => '$baseUrl/share/my-links';
  static String shareLinkStats(String id) => '$baseUrl/share/$id/stats';
  static String revokeShareLink(String id) => '$baseUrl/share/$id';
  static String publicDownload(String token) =>
      '$baseUrl/share/$token/download';

  // Activities
  static String get activities => '$baseUrl/activities';
  static String spaceActivities(String spaceId) =>
      '$baseUrl/activities/space/$spaceId';

  // AI
  static String get aiChat => '$baseUrl/ai/chat';
  static String get aiChatStream => '$baseUrl/ai/chat/stream';
  static String get aiVision => '$baseUrl/ai/vision';
  static String get aiDeepSearch => '$baseUrl/ai/deep-search';
  static String get aiDeepSearchStream => '$baseUrl/ai/deep-search/stream';
  static String get aiFeedback => '$baseUrl/ai/feedback';
  static String get aiCreditsBalance => '$baseUrl/ai/credits/balance';
  static String get aiCreditsHistory => '$baseUrl/ai/credits/history';
  static String get aiUsageStats => '$baseUrl/ai/usage/stats';
  static String get aiReindexExisting =>
      '$baseUrl/ai/documents/reindex-existing';
  static String aiReindexDocument(String id) =>
      '$baseUrl/ai/documents/$id/reindex';
  static String aiSpaceReindexAll(String spaceId) =>
      '$baseUrl/ai/spaces/$spaceId/reindex-all';
  static String aiDocumentIndexStatus(String id) =>
      '$baseUrl/ai/documents/$id/index-status';

  // Billing & Plans
  static String get billingPlans => '$baseUrl/billing/plans';
  static String get billingSubscription => '$baseUrl/billing/subscription';
  static String get billingOrders => '$baseUrl/billing/orders';
  static String get billingVerify => '$baseUrl/billing/verify';
  static String get billingCancel => '$baseUrl/billing/cancel';
  static String get billingCreditsBuy => '$baseUrl/billing/credits/buy';
  static String get billingCreditsVerify =>
      '$baseUrl/billing/credits/verify';

  // Admin
  static String get adminOverview => '$baseUrl/admin/overview';
  static String get adminUsers => '$baseUrl/admin/users';
  static String get adminFinancials => '$baseUrl/admin/financials';
  static String get adminOperatingCosts => '$baseUrl/admin/operating-costs';
  static String adminDeleteOperatingCost(String id) =>
      '$baseUrl/admin/operating-costs/$id';

  // Realtime SSE
  static String get realtimeEvents => '$baseUrl/realtime/events';

  // System & Auto-Update
  static String get appVersion => '$baseUrl/system/version';
}
