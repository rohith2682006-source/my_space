import 'package:flutter/material.dart';
import '../data/services/auth_storage.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadTheme() async {
    _isDarkMode = await AuthStorage.isDarkMode();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await AuthStorage.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}
