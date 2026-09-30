import 'package:flutter/material.dart';

class NavigationTabController extends InheritedWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;

  const NavigationTabController({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required super.child,
  });

  static NavigationTabController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavigationTabController>();
  }

  @override
  bool updateShouldNotify(NavigationTabController oldWidget) =>
      currentIndex != oldWidget.currentIndex;
}
