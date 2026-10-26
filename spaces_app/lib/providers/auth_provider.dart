import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../data/models/user_model.dart';
import '../data/services/auth_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payload = _decodeBase64(parts[1]);
      final payloadMap = json.decode(payload);
      if (payloadMap is! Map<String, dynamic>) {
        return null;
      }

      return payloadMap;
    } catch (_) {
      return null;
    }
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!');
    }
    return utf8.decode(base64Url.decode(output));
  }

  static const String webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String desktopClientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  static const String webSecret = String.fromEnvironment('GOOGLE_WEB_CLIENT_SECRET');
  static const String desktopSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

  GoogleSignIn get googleSignIn => _googleSignIn;

  static GoogleSignInParams get _googleSignInParams {
    if (kIsWeb) {
      return GoogleSignInParams(
        clientId: webClientId,
        clientSecret: webSecret.isNotEmpty ? webSecret : null,
      );
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return GoogleSignInParams(
        clientId: desktopClientId,
        // On desktop, google_sign_in_all_platforms asserts clientSecret != null
        clientSecret: desktopSecret.isNotEmpty ? desktopSecret : 'not_configured',
        redirectPort: 3000,
        timeout: const Duration(seconds: 25),
      );
    } else {
      // Mobile platforms (Android/iOS)
      // On Android, GoogleSignIn uses this as serverClientId to obtain an idToken.
      // It MUST be the Web Application Client ID, not the Android Client ID.
      return const GoogleSignInParams(
        clientId: webClientId,
      );
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(params: _googleSignInParams);
  Completer<void>? _googleSignInCancelCompleter;

  void cancelGoogleSignIn() {
    if (_googleSignInCancelCompleter != null &&
        !_googleSignInCancelCompleter!.isCompleted) {
      _googleSignInCancelCompleter!.complete();
    }
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  AuthProvider() {
    ApiClient.onUnauthorized = () {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
    };
  }

  Future<void> checkAuth() async {
    final token = await AuthStorage.getAccessToken();
    final refreshToken = await AuthStorage.getRefreshToken();

    // 1. If active tokens are not present, user is not logged in
    if ((token == null || token.isEmpty) &&
        (refreshToken == null || refreshToken.isEmpty)) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // 2. Immediately restore cached user to keep user logged in with zero delay
    final cachedUser = await AuthStorage.getUser();
    _user = cachedUser;
    _status = AuthStatus.authenticated;
    notifyListeners();

    // 3. Verify / refresh session in background without blocking initial app launch
    unawaited(_verifySessionInBackground(cachedUser));
  }

  Future<void> _verifySessionInBackground(UserModel? cachedUser) async {
    try {
      final response = await ApiClient.get(ApiEndpoints.me);
      if (response.success && response.data != null) {
        _user = UserModel.fromJson(response.data);
        await AuthStorage.saveUser(_user!);
        _status = AuthStatus.authenticated;
        notifyListeners();
      } else if (response.statusCode == 401) {
        // Attempt seamless token refresh
        final refreshed = await ApiClient.refreshToken();
        if (refreshed) {
          final retryResponse = await ApiClient.get(ApiEndpoints.me);
          if (retryResponse.success && retryResponse.data != null) {
            _user = UserModel.fromJson(retryResponse.data);
            await AuthStorage.saveUser(_user!);
            _status = AuthStatus.authenticated;
            notifyListeners();
            return;
          }
        }

        // Only invalidate if refresh token was explicitly rejected as expired/invalid
        await AuthStorage.clearAll();
        _user = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      } else {
        // Network offline / connection hiccup: keep cached user session active
        if (cachedUser != null) {
          _user = cachedUser;
          _status = AuthStatus.authenticated;
          notifyListeners();
        }
      }
    } catch (_) {
      // Network failure / offline: preserve active session
      if (cachedUser != null) {
        _user = cachedUser;
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.post(
      ApiEndpoints.login,
      body: {'email': email.trim(), 'password': password},
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      final data = response.data;
      final tokens = data['tokens'];
      final userData = data['user'];

      await AuthStorage.saveTokens(
        accessToken: tokens['accessToken'],
        refreshToken: tokens['refreshToken'],
        email: email.trim(),
      );

      _user = UserModel.fromJson(userData);
      await AuthStorage.saveUser(_user!);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } else {
      _errorMessage =
          response.message ?? 'Login failed. Please check your credentials.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithRefreshToken(
    String refreshToken, {
    String? email,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.post(
        ApiEndpoints.refresh,
        body: {'refreshToken': refreshToken},
      );

      if (response.success && response.data != null) {
        final data = response.data;
        final tokens = data['tokens'];
        final newAccessToken = tokens['accessToken'];
        final newRefreshToken = tokens['refreshToken'] ?? refreshToken;

        await AuthStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          email: email,
        );

        if (email != null && email.isNotEmpty) {
          await AuthStorage.updateSavedAccountToken(email, newRefreshToken);
        }

        // Fetch user info
        final userResponse = await ApiClient.get(ApiEndpoints.me);
        if (userResponse.success && userResponse.data != null) {
          _user = UserModel.fromJson(userResponse.data);
          await AuthStorage.saveUser(_user!);
          _status = AuthStatus.authenticated;
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          // If profile fetch fails momentarily, fallback to saved account info
          final savedAccounts = await AuthStorage.getSavedAccounts();
          final saved = savedAccounts.firstWhere(
            (acc) =>
                email != null &&
                (acc['email'] ?? '').toString().toLowerCase() ==
                    email.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (saved.isNotEmpty) {
            _user = UserModel(
              id: saved['id'] ?? '',
              email: saved['email'] ?? email ?? '',
              firstName: saved['firstName'] ?? '',
              lastName: saved['lastName'] ?? '',
              avatarUrl: saved['profilePicture'],
            );
            _status = AuthStatus.authenticated;
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      _errorMessage =
          (response.message != null &&
                  !response.message!.toLowerCase().contains('revoked'))
              ? response.message
              : 'Session expired. Please sign in again.';
    } catch (e) {
      _errorMessage = 'Authentication failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.post(
      ApiEndpoints.register,
      body: {
        'email': email.trim(),
        'password': password,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
      },
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      final data = response.data;
      final tokens = data['tokens'];
      final userData = data['user'];

      await AuthStorage.saveTokens(
        accessToken: tokens['accessToken'],
        refreshToken: tokens['refreshToken'],
        email: email.trim(),
      );

      _user = UserModel.fromJson(userData);
      await AuthStorage.saveUser(_user!);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Registration failed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> googleLoginWithCredentials(
    GoogleSignInCredentials credentials, {
    bool isSignUp = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (credentials.idToken == null) {
        _isLoading = false;
        _errorMessage = 'Google sign-in returned no ID token.';
        notifyListeners();
        return false;
      }

      final response = await ApiClient.post(
        ApiEndpoints.googleLogin,
        body: {'idToken': credentials.idToken, 'isSignUp': isSignUp},
      );

      if (response.success && response.data != null) {
        final data = response.data;
        final tokens = data['tokens'];
        final userData = data['user'];

        await AuthStorage.saveTokens(
          accessToken: tokens['accessToken'],
          refreshToken: tokens['refreshToken'],
        );

        _user = UserModel.fromJson(userData);
        await AuthStorage.saveUser(_user!);
        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = response.message ?? 'Google login failed.';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Google sign-in failed: ${e.runtimeType}: $e';
      notifyListeners();
      return false;
    }
  }

  Future<GoogleSignInCredentials?> getGoogleSignInCredentials() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux) &&
          desktopSecret.isEmpty) {
        _isLoading = false;
        _errorMessage =
            'Google Sign-In on Desktop requires GOOGLE_DESKTOP_CLIENT_SECRET to be configured.';
        notifyListeners();
        return null;
      }

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      _googleSignInCancelCompleter = Completer<void>();

      final credentials = await Future.any<dynamic>([
        _googleSignIn.signIn(),
        _googleSignInCancelCompleter!.future.then((_) => null),
      ]) as GoogleSignInCredentials?;

      if (credentials == null || credentials.idToken == null) {
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return null;
      }

      _isLoading = false;
      notifyListeners();
      return credentials;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Google sign-in failed: ${e.runtimeType}: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> googleLogin({bool isSignUp = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux) &&
          desktopSecret.isEmpty) {
        _isLoading = false;
        _errorMessage =
            'Google Sign-In on Desktop requires GOOGLE_DESKTOP_CLIENT_SECRET to be configured.';
        notifyListeners();
        return false;
      }

      // Force the account selection dialog by signing out first
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore errors if already signed out
      }

      _googleSignInCancelCompleter = Completer<void>();

      final credentials = await Future.any<dynamic>([
        _googleSignIn.signIn(),
        _googleSignInCancelCompleter!.future.then((_) => null),
      ]) as GoogleSignInCredentials?;

      if (credentials == null || credentials.idToken == null) {
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return false;
      }

      final response = await ApiClient.post(
        ApiEndpoints.googleLogin,
        body: {'idToken': credentials.idToken, 'isSignUp': isSignUp},
      );

      if (response.success && response.data != null) {
        final data = response.data;
        final tokens = data['tokens'];
        final userData = data['user'];

        await AuthStorage.saveTokens(
          accessToken: tokens['accessToken'],
          refreshToken: tokens['refreshToken'],
          email: userData != null ? userData['email'] : null,
        );

        _user = UserModel.fromJson(userData);
        await AuthStorage.saveUser(_user!);
        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = response.message ?? 'Google login failed.';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Google sign-in failed: ${e.runtimeType}: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final user = _user;
    final refreshToken = await AuthStorage.getRefreshToken();

    // Check if the current user has saved their account on this device
    bool isSaved = false;
    if (user != null) {
      isSaved = await AuthStorage.isSavedAccount(user.email);
    }

    // Only revoke on the server if this account is NOT a saved account on this device.
    // Saved accounts intentionally preserve their device credentials for 1-click / biometric login.
    if (!isSaved && refreshToken != null) {
      try {
        await ApiClient.post(
          ApiEndpoints.logout,
          body: {'refreshToken': refreshToken},
        );
      } catch (_) {
        // Silently ignore network failures on logout so user is always signed out locally
      }
    }

    await AuthStorage.clearAll();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.post(
      ApiEndpoints.forgotPassword,
      body: {'email': email.trim()},
    );

    _isLoading = false;

    if (response.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage =
          response.message ?? 'This account is not registered in this app.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.post(
      ApiEndpoints.verifyOtp,
      body: {'email': email.trim(), 'otp': otp.trim()},
    );

    _isLoading = false;

    if (response.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Invalid or expired OTP';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.post(
      ApiEndpoints.resetPassword,
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
        'newPassword': newPassword,
      },
    );

    _isLoading = false;

    if (response.success) {
      final data = response.data;
      if (data != null && data is Map<String, dynamic> && data['tokens'] != null) {
        final tokens = data['tokens'];
        final userData = data['user'];

        await AuthStorage.saveTokens(
          accessToken: tokens['accessToken'],
          refreshToken: tokens['refreshToken'],
          email: email.trim(),
        );

        if (userData != null) {
          _user = UserModel.fromJson(userData);
          await AuthStorage.saveUser(_user!);
        }
        _status = AuthStatus.authenticated;
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Failed to reset password';
      notifyListeners();
      return false;
    }
  }
}
