class ApiEndpoints {
  // Override with --dart-define=API_BASE_URL=... for emulators and devices.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  // Auth
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String refresh = '$baseUrl/auth/refresh';
  static const String me = '$baseUrl/auth/me';
  static const String logout = '$baseUrl/auth/logout';
  static const String logoutAll = '$baseUrl/auth/logout-all';
  static const String changePassword = '$baseUrl/auth/change-password';

  // Spaces
  static const String spaces = '$baseUrl/spaces';
  static String space(String id) => '$baseUrl/spaces/$id';
  static String spaceMembers(String id) => '$baseUrl/spaces/$id/members';

  // Files
  static String spaceFiles(String spaceId) => '$baseUrl/files/spaces/$spaceId';
  static String uploadFile(String spaceId) =>
      '$baseUrl/files/spaces/$spaceId/upload';
  static const String createNoteOrLink = '$baseUrl/files/notes-links';
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

  // Discovery
  static const String search = '$baseUrl/search';
  static const String recent = '$baseUrl/recent';
  static const String favorites = '$baseUrl/favorites';
  static const String trash = '$baseUrl/trash';
  static const String storage = '$baseUrl/storage';

  // Sharing
  static const String shareLinks = '$baseUrl/share';
  static String resolveShareLink(String token) =>
      '$baseUrl/share/resolve/$token';
  static const String myShareLinks = '$baseUrl/share/my-links';
  static String shareLinkStats(String id) => '$baseUrl/share/$id/stats';
  static String revokeShareLink(String id) => '$baseUrl/share/$id';
  static String publicDownload(String token) =>
      '$baseUrl/share/$token/download';

  // Activities
  static const String activities = '$baseUrl/activities';
  static String spaceActivities(String spaceId) =>
      '$baseUrl/activities/space/$spaceId';

  // AI
  static const String aiChat = '$baseUrl/ai/chat';
  static const String aiDeepSearch = '$baseUrl/ai/deep-search';
  static const String aiQuickSearch = '$baseUrl/ai/quick-search';
  static const String aiCreditsBalance = '$baseUrl/ai/credits/balance';
  static const String aiCreditsHistory = '$baseUrl/ai/credits/history';
  static const String aiUsageStats = '$baseUrl/ai/usage/stats';
  static const String aiReindexExisting =
      '$baseUrl/ai/documents/reindex-existing';
  static String aiReindexDocument(String id) =>
      '$baseUrl/ai/documents/$id/reindex';
  static String aiDocumentIndexStatus(String id) =>
      '$baseUrl/ai/documents/$id/index-status';

  // Billing & Plans
  static const String billingPlans = '$baseUrl/billing/plans';
  static const String billingSubscription = '$baseUrl/billing/subscription';
  static const String billingOrders = '$baseUrl/billing/orders';
  static const String billingVerify = '$baseUrl/billing/verify';
  static const String billingCancel = '$baseUrl/billing/cancel';
  static const String billingCreditsBuy = '$baseUrl/billing/credits/buy';
  static const String billingCreditsVerify = '$baseUrl/billing/credits/verify';

  // Admin
  static const String adminOverview = '$baseUrl/admin/overview';
  static const String adminUsers = '$baseUrl/admin/users';
  static const String adminFinancials = '$baseUrl/admin/financials';
  static const String adminOperatingCosts = '$baseUrl/admin/operating-costs';
  static String adminDeleteOperatingCost(String id) => '$baseUrl/admin/operating-costs/$id';

  // Realtime SSE
  static const String realtimeEvents = '$baseUrl/realtime/events';
}

