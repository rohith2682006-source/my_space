import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isDemoLoading = false;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': '🎓',
      'title': 'Context over Folders',
      'subtitle':
          'Don\'t search through device storage. Create a Space for College, Projects, or Travel and keep everything together.',
      'tag': 'College Space',
      'badge': '126 Files',
      'color': const Color(0xFF6366F1),
    },
    {
      'icon': '⚡',
      'title': 'Store Once. Find Instantly.',
      'subtitle':
          'Universal fast search across every Space, document, photo, video, link, and note in milliseconds.',
      'tag': 'Global Search',
      'badge': 'Lightning Fast',
      'color': const Color(0xFF06B6D4),
    },
    {
      'icon': '🔗',
      'title': 'Share in One Tap',
      'subtitle':
          'Share individual documents or collaborate on entire Spaces with password protection and custom permissions.',
      'tag': 'Spaces Collaboration',
      'badge': 'Encrypted & Safe',
      'color': const Color(0xFF10B981),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.layers_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Spaces',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('Sign In'),
                  ),
                ],
              ),
              const Spacer(),
              // PageView Illustration Cards
              SizedBox(
                height: 340,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Card Preview
                          Container(
                            width: 220,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: (item['color'] as Color).withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (item['color'] as Color).withOpacity(0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  item['icon'],
                                  style: const TextStyle(fontSize: 48),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  item['tag'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (item['color'] as Color).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    item['badge'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: item['color'],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                              .animate(target: _currentPage == index ? 1 : 0)
                              .scale(duration: 400.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 32),
                          // Title
                          Text(
                            item['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Subtitle
                          Text(
                            item['subtitle'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // CTA Buttons
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: '⚡ Instant Demo Access (demo@spaces.app)',
                  isLoading: _isDemoLoading,
                  onPressed: () async {
                    setState(() => _isDemoLoading = true);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final success = await auth.login('demo@spaces.app', 'Password123!');
                    setState(() => _isDemoLoading = false);
                    if (success && mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Create New Account',
                  isOutlined: true,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('Sign In with Existing Account'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
