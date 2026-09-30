import 'package:flutter/material.dart';
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

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    ApiClient.onUnauthorized = () {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
    };
  }

  Future<void> checkAuth() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null) {
      await AuthStorage.clearAll();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final cachedUser = await AuthStorage.getUser();
    if (cachedUser != null) {
      _user = cachedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
    }

    // Refresh profile in background to verify token validity
    final response = await ApiClient.get(ApiEndpoints.me);
    if (response.success && response.data != null) {
      _user = UserModel.fromJson(response.data);
      await AuthStorage.saveUser(_user!);
      _status = AuthStatus.authenticated;
    } else {
      // If token expired or rejected by server, invalidate session
      await AuthStorage.clearAll();
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiClient.post(
      ApiEndpoints.login,
      body: {
        'email': email.trim(),
        'password': password,
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
      );

      _user = UserModel.fromJson(userData);
      await AuthStorage.saveUser(_user!);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message ?? 'Login failed. Please check your credentials.';
      notifyListeners();
      return false;
    }
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

  Future<void> logout() async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken != null) {
      await ApiClient.post(
        ApiEndpoints.logout,
        body: {'refreshToken': refreshToken},
      );
    }
    await AuthStorage.clearAll();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
