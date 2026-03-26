import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:unilink/app.dart';
import 'package:unilink/core/services/auth_provider.dart';

void main() {
  testWidgets('UniLink app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider()..init(),
        child: const UniLinkApp(),
      ),
    );

    await tester.pump();

    expect(find.text('UniLink'), findsWidgets);
  });
}
