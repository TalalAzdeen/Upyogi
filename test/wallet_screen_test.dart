import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/screens/wallet_screen.dart';

void main() {
  late http.Client original;
  setUp(() { SharedPreferences.setMockInitialValues({'token':'test-token'}); original=api.client; });
  tearDown(() { api.client.close(); api.client=original; });

  testWidgets('Unconfigured gateway shows real balance and disables charging', (tester) async {
    api.client=MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response('{"balanceMinor":1250,"currency":"sar","topups":[],"paymentsConfigured":false}',200);
    });
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await tester.pumpAndSettle();
    expect(find.text('SAR 12.50'), findsOneWidget);
    expect(find.textContaining('Pay the technician directly'), findsOneWidget);
    expect(find.byType(TextField),findsNothing);
    expect(find.byIcon(Icons.add_card),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Failed wallet load never displays a fabricated zero balance and can retry', (tester) async {
    var calls=0;
    api.client=MockClient((_) async => ++calls==1
      ? http.Response('{"message":"Unavailable"}',503)
      : http.Response('{"balanceMinor":2500,"currency":"sar","topups":[],"paymentsConfigured":false}',200));
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await tester.pumpAndSettle();
    expect(find.text('SAR 0.00'), findsNothing);
    expect(find.textContaining('Could not refresh the balance'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('SAR 25.00'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
