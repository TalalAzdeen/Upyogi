import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/services/demo_service.dart';
import 'package:service_app/screens/demo_journey_screen.dart';

void main() {
  late http.Client original;
  setUp(() {
    original = api.client;
    SharedPreferences.setMockInitialValues({'token':'demo-test-session'});
  });
  tearDown(() { api.client.close(); api.client = original; });
  Map<String, dynamic> booking(String status, {bool skipped = false}) => {
    'id':42,'serviceId':7,'demoScenario':true,'demoPaymentSkipped':skipped,
    'bookingStatus':status,'paymentStatus':'External','amount':120,
    'serviceTitle':'Demo cleaning','providerName':'Demo technician',
    'serviceAddress':'Fictional address','appointmentDate':'2026-12-01',
  };

  testWidgets('saved journey reaches checkout and skipping never confirms a payment', (tester) async {
    var status = 'Requested';
    var skipped = false;
    var advances = 0;
    api.client = MockClient((r) async {
      expect(r.headers['authorization'],'Bearer demo-test-session');
      expect(r.url.path,contains('/api/Demo/bookings/42'));
      expect(r.url.path, isNot(contains('/api/Payment/')));
      if (r.method == 'POST') {
        advances++;
        final body = jsonDecode(r.body);
        expect(body['expectedStatus'],status);
        if (body['skipPayment'] == true) {
          expect(status,'Completed'); skipped = true;
        } else {
          status = {'Requested':'Accepted','Accepted':'OnTheWay','OnTheWay':'Completed'}[status]!;
        }
      }
      return http.Response(jsonEncode(booking(status, skipped:skipped)),200);
    });
    await tester.pumpWidget(const MaterialApp(locale: Locale('en'), home: DemoJourneyScreen(bookingId:42)));
    await tester.pumpAndSettle();
    expect(advances,0);
    for (final label in ['Simulate technician acceptance','Simulate travel','Simulate service completion']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label)); await tester.pumpAndSettle();
    }
    expect(find.text('Payment preview'),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('skip-demo-payment')));
    await tester.tap(find.byKey(const Key('skip-demo-payment')));
    await tester.pumpAndSettle();
    expect(skipped,true); expect(advances,4);
    expect(find.text('Demo completed — payment skipped'),findsOneWidget);
    expect(find.text('No money was charged. This is not a payment receipt.'),findsOneWidget);
  });

  testWidgets('reopening completed booking restores checkout without advancing', (tester) async {
    api.client = MockClient((r) async {
      expect(r.method,'GET');
      return http.Response(jsonEncode(booking('Completed')),200);
    });
    await tester.pumpWidget(const MaterialApp(locale:Locale('en'),home:DemoJourneyScreen(bookingId:42)));
    await tester.pumpAndSettle();
    expect(find.text('Payment preview'),findsOneWidget);
  });

  test('catalog generation uses authenticated POST and reports failure', () async {
    api.client = MockClient((r) async {
      expect(r.url.path,endsWith('/api/Demo/catalog'));
      expect(r.method,'POST');
      return http.Response('{}',503);
    });
    await expectLater(DemoService.generateCatalog(),throwsStateError);
  });
}
