import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/l10n/app_language.dart';
import 'package:service_app/models/service_model.dart';
import 'package:service_app/screens/booking_screen.dart';
import 'package:service_app/screens/main_shell.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/services/role_provider.dart';
import 'package:service_app/services/location_tracking_service.dart';

void main() {
  late http.Client original;
  setUp(() {
    original = api.client;
    SharedPreferences.setMockInitialValues({'token':'test-session','role':'Provider','app_language':'en'});
    AppLanguage.instance.value = const Locale('en');
  });
  tearDown(() { api.client.close(); api.client = original; });

  testWidgets('Booking submits without a payment gateway', (tester) async {
    int bookings = 0;
    api.client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/api/Booking')); 
      final data = jsonDecode(request.body);
      expect(data['serviceId'], 1);
      bookings++;
      return http.Response('{"id":42,"paymentStatus":"External"}',200);
    });
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(
        service: ServiceModel.fromJson({'id':1,'title':'Test service'})))), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.tap(find.text('Select date')); await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Select time'));
    await tester.tap(find.text('Select time')); await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Test address');
    await tester.enterText(find.byType(TextField).at(1), '0500000000');
    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking')); await tester.pumpAndSettle();
    expect(bookings, 1);
    expect(find.text('Booking requested. Pay the technician after the work is completed.'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Provider lands on requests, accepts one and signs out', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var status = 'Requested';
    int loads = 0;
    api.client = MockClient((request) async {
      if (request.url.path.endsWith('/accept')) { status = 'Accepted'; return http.Response('{}',200); }
      if (request.url.path.endsWith('/logout')) return http.Response('{}',200);
      expect(request.url.path, endsWith('/api/Booking/provider'));
      loads++;
      return http.Response(jsonEncode([{'id':42,'serviceId':1,'serviceTitle':'Cleaning request',
        'customerName':'Test customer','appointmentDate':DateTime.now().add(const Duration(days:1)).toIso8601String(),
        'bookingStatus':status,'paymentStatus':'External','amount':75}]),200);
    });
    await tester.pumpWidget(ProviderScope(overrides:[selectedRoleProvider.overrideWith((ref) => 'Provider')], child: const MaterialApp(home: MainShell())));
    await tester.pumpAndSettle();
    expect(find.text('Cleaning request'), findsOneWidget);
    expect(find.text('New Requests'), findsOneWidget);
    await tester.pump(const Duration(seconds:5)); await tester.pumpAndSettle();
    expect(loads,greaterThanOrEqualTo(2));
    await tester.ensureVisible(find.text('Accept'));
    await tester.tap(find.text('Accept')); await tester.pumpAndSettle();
    expect(status,'Accepted');
    expect(find.text('Cleaning request'), findsNothing);
    await tester.tap(find.byTooltip('Logout')); await tester.pumpAndSettle();
    expect(find.text('Do you want to sign out of this account?'),findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton,'Logout')); await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'),isNull);
    expect(prefs.getString('role'),isNull);
    expect(prefs.getString('app_language'),'en');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Tracking reads the first position and server timestamp immediately', () async {
    api.client = MockClient((request) async => http.Response(request.url.path.endsWith('/me')
      ? '{}' : '{"latitude":24.7,"longitude":46.6,"updatedAt":"2026-10-19T06:00:00Z"}',200));
    final tracking = LocationTrackingService();
    double? latitude;
    tracking.onLocationReceived((lat,lng) => latitude = lat);
    await tracking.connect(); await tracking.joinBookingGroup(42);
    expect(latitude,24.7);
    expect(tracking.lastUpdated,DateTime.utc(2026,10,19,6));
    await tracking.disconnect();
  });
}
