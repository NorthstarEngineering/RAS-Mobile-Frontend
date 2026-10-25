import 'package:flutter_test/flutter_test.dart';
import 'package:rms_app/core/di/service_locator.dart';
import 'package:rms_app/main.dart';

void main() {
  setUp(() async {
    await sl.reset();
    await initServiceLocator();
  });

  testWidgets('RmsApp smoke test - renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RmsApp());
    await tester.pumpAndSettle();

    // Verify Terminal title renders in Arabic on boot
    expect(find.text('RMS TERMINAL'), findsOneWidget);
    expect(find.text('نظام إدارة المطاعم'), findsOneWidget);
  });
}
