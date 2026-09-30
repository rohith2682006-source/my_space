import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spaces_app/main.dart';
import 'package:spaces_app/providers/auth_provider.dart';
import 'package:spaces_app/providers/theme_provider.dart';
import 'package:spaces_app/core/services/realtime_service.dart';

void main() {
  tearDown(() {
    RealtimeService.instance.stop();
  });

  testWidgets('Spaces app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const SpacesApp(),
      ),
    );
    expect(find.byType(SpacesApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
