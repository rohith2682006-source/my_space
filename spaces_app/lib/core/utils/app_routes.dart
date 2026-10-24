import 'package:flutter/material.dart';

/// A smooth slide-up + fade transition used across the entire app.
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (context, _, __) => builder(context),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final fadeAnim = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: animation.drive(tween),
              child: child,
            ),
          );
        },
      );
}

/// A PageTransitionsBuilder that applies the AppRoute transition globally.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 0.05);
    const end = Offset.zero;
    const curve = Curves.easeOutCubic;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    final fadeAnim = CurvedAnimation(parent: animation, curve: Curves.easeOut);

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(position: animation.drive(tween), child: child),
    );
  }
}
