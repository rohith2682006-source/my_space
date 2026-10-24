import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthStorage {
  static const String _keyAccessToken = 'spaces_access_token';
  static const String _keyRefreshToken = 'spaces_refresh_token';
  static const String _keyUser = 'spaces_user';
  static const String _keyDarkMode = 'spaces_dark_mode';
  static const String _keyVaultPassword = 'spaces_vault_password';
  static const String _keySavedAccounts = 'spaces_saved_accounts';

  static String? _cachedToken;
  static String? get cachedToken => _cachedToken;

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    _cachedToken = accessToken;

    try {
      final user = await getUser();
      final targetEmail = email ?? user?.email;
      if (targetEmail != null && targetEmail.isNotEmpty) {
        final savedAccounts = await getSavedAccounts();
        final index = savedAccounts.indexWhere(
          (acc) =>
              (acc['email'] ?? '').toString().toLowerCase() ==
              targetEmail.toLowerCase(),
        );
        if (index >= 0) {
          savedAccounts[index]['refreshToken'] = refreshToken;
        } else {
          savedAccounts.add({
            'email': targetEmail,
            'firstName': user?.firstName ?? '',
            'lastName': user?.lastName ?? '',
            'profilePicture': user?.avatarUrl,
            'refreshToken': refreshToken,
          });
        }
        await prefs.setString(_keySavedAccounts, jsonEncode(savedAccounts));
      }
    } catch (_) {}
  }

  static Future<void> updateSavedAccountToken(
    String email,
    String? refreshToken,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccounts = await getSavedAccounts();
    final index = savedAccounts.indexWhere(
      (acc) =>
          (acc['email'] ?? '').toString().toLowerCase() ==
          email.trim().toLowerCase(),
    );
    if (index >= 0) {
      if (refreshToken != null) {
        savedAccounts[index]['refreshToken'] = refreshToken;
      } else {
        savedAccounts[index].remove('refreshToken');
      }
      await prefs.setString(_keySavedAccounts, jsonEncode(savedAccounts));
    }
  }

  static Future<bool> isSavedAccount(String email) async {
    final savedAccounts = await getSavedAccounts();
    return savedAccounts.any(
      (acc) =>
          (acc['email'] ?? '').toString().toLowerCase() ==
          email.trim().toLowerCase(),
    );
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_keyAccessToken);
    return _cachedToken;
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));

    // Update saved accounts list
    final savedAccounts = await getSavedAccounts();
    final index = savedAccounts.indexWhere(
      (acc) =>
          (acc['email'] ?? '').toString().toLowerCase() ==
          user.email.toLowerCase(),
    );
    final currentRefreshToken = await getRefreshToken();
    final existingToken =
        (index >= 0) ? savedAccounts[index]['refreshToken'] : null;
    final tokenToSave = currentRefreshToken ?? existingToken;

    final accountData = <String, dynamic>{
      'email': user.email,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'profilePicture': user.avatarUrl,
      if (tokenToSave != null && tokenToSave.toString().isNotEmpty)
        'refreshToken': tokenToSave,
    };
    if (index >= 0) {
      savedAccounts[index] = accountData;
    } else {
      savedAccounts.add(accountData);
    }
    await prefs.setString(_keySavedAccounts, jsonEncode(savedAccounts));
  }

  static Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keySavedAccounts);
    if (str == null) return [];
    try {
      final List<dynamic> list = jsonDecode(str);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removeSavedAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccounts = await getSavedAccounts();
    savedAccounts.removeWhere((acc) => acc['email'] == email);
    await prefs.setString(_keySavedAccounts, jsonEncode(savedAccounts));
  }

  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_keyUser);
    if (userStr == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userStr));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUser);
  }

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keySavedAccounts);
  }

  static Future<void> clearSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedAccounts);
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? true; // Default dark mode
  }

  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDark);
  }

  static Future<String?> getVaultPassword(String spaceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyVaultPassword}_$spaceId');
  }

  static Future<void> setVaultPassword(String spaceId, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyVaultPassword}_$spaceId', password);
  }
}
