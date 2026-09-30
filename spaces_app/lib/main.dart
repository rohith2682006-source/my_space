import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/spaces_provider.dart';
import 'providers/files_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/sharing_provider.dart';
import 'providers/activity_provider.dart';
import 'providers/plans_provider.dart';
import 'providers/ai_credits_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SpacesProvider()),
        ChangeNotifierProvider(create: (_) => FilesProvider()),
        ChangeNotifierProvider(create: (_) => SharingProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => PlansProvider()),
        ChangeNotifierProvider(create: (_) => AiCreditsProvider()),
      ],
      child: const SpacesApp(),
    ),
  );
}

class SpacesApp extends StatelessWidget {
  const SpacesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Spaces — Store Once. Find Instantly.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
