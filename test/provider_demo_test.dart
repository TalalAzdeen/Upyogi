import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/l10n/app_language.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/services/provider_demo_store.dart';
import 'package:service_app/screens/provider_demo_screen.dart';
import 'package:service_app/screens/auth_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client previous;
  setUp(() {
    previous = api.client;
    SharedPreferences.setMockInitialValues({});
    AppLanguage.instance.value = const Locale('en');
    api.client = MockClient((_) async => throw StateError('Demo must not call the server'));
  });
  tearDown(() { api.client.close(); api.client = previous; });

  test('all three plans are available; registration never selects one or creates auth tokens', () async {
    final store = await ProviderDemoStore.load();
    expect(ProviderDemoStore.plans.map((p) => p.price), [100, 200, 300]);
    expect(store.planId, isNull);
    await store.register(name:'Demo technician', specialty:'Plumber', acknowledged:true);
    expect(store.stage, 'plans');
    expect(store.planId, isNull);
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['token','refreshToken','role']) expect(prefs.containsKey(key), isFalse);
    final reloaded = await ProviderDemoStore.load();
    expect(reloaded.name, 'Demo technician');
    expect(reloaded.planId, isNull);
  });

  test('every package can be explicitly chosen, renewed and restored', () async {
    final store = await ProviderDemoStore.load();
    await store.register(name:'Demo', specialty:'Electrician', acknowledged:true);
    for (final id in ['start','growth','pro']) {
      await store.activatePlan(id);
      expect(store.planId, id);
      final end = store.subscriptionUntil!;
      await store.renew();
      expect(store.subscriptionUntil!.isAfter(end), isTrue);
      final restored = await ProviderDemoStore.load();
      expect(restored.planId, id);
      expect(restored.stage, 'dashboard');
    }
    await expectLater(store.activatePlan('unknown'), throwsArgumentError);
  });

  test('declaration, booking stages and renewal preconditions are enforced', () async {
    final store = await ProviderDemoStore.load();
    await expectLater(store.register(name:'Demo',specialty:'Plumber',acknowledged:false), throwsStateError);
    await expectLater(store.renew(), throwsStateError);
    await expectLater(store.activatePlan('start'), throwsStateError);
    await store.register(name:'Demo',specialty:'Plumber',acknowledged:true);
    await store.activatePlan('growth');
    final id = store.bookings.first.id;
    await store.advanceBooking(id, 'Accepted');
    await expectLater(store.advanceBooking(id, 'Accepted'), throwsStateError);
    await store.advanceBooking(id, 'OnTheWay');
    await store.advanceBooking(id, 'InProgress');
    await store.advanceBooking(id, 'Completed');
    expect(store.bookings.first.status,'Completed');
    await expectLater(store.advanceBooking(id,'Accepted'), throwsStateError);
    expect((await ProviderDemoStore.load()).bookings.first.status, 'Completed');
  });

  test('leaving demo keeps real authentication and allows explicit resumption', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token','real-session');
    final store = await ProviderDemoStore.load();
    await store.register(name:'Demo',specialty:'Plumber',acknowledged:true);
    await store.exit();
    expect((await ProviderDemoStore.load()).active,false);
    expect(prefs.getString('token'),'real-session');
    await store.resume();
    expect((await ProviderDemoStore.load()).active,true);
  });

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 180, scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }
  Future<void> openPlans(WidgetTester tester) async {
    final store = await ProviderDemoStore.load();
    await store.register(name:'Demo technician',specialty:'Plumber',acknowledged:true);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(locale:Locale('en'),home:ProviderDemoScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets('plans show 100, 200 and 300 with no default selection', (tester) async {
    await openPlans(tester);
    for (final price in [100, 200, 300]) expect(find.text('SAR $price'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(find.byKey(const Key('provider-plan-start')),findsOneWidget);
    expect(find.byKey(const Key('provider-plan-growth')),findsOneWidget);
    expect(find.byKey(const Key('provider-plan-pro')),findsOneWidget);
    await reveal(tester, find.byKey(const Key('activate-provider-plan')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('activate-provider-plan'))).onPressed,isNull);
    await reveal(tester, find.byKey(const Key('provider-plan-growth')));
    await tester.tap(find.byKey(const Key('provider-plan-growth')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('activate-provider-plan')));
    await tester.tap(find.byKey(const Key('activate-provider-plan')));
    await tester.pumpAndSettle();
    expect(find.text('Technician dashboard'),findsOneWidget);
    expect((await ProviderDemoStore.load()).planId,'growth');
  });

  testWidgets('registration skips email verification and requires the visible declaration', (tester) async {
    await tester.pumpWidget(const ProviderScope(child:MaterialApp(locale:Locale('en'),home:ProviderDemoScreen())));
    await tester.pumpAndSettle();
    await reveal(tester,find.byKey(const Key('start-provider-demo')));
    await tester.tap(find.byKey(const Key('start-provider-demo')));await tester.pumpAndSettle();
    await reveal(tester,find.byKey(const Key('fill-provider-demo')));
    await tester.tap(find.byKey(const Key('fill-provider-demo')));await tester.pumpAndSettle();
    await reveal(tester,find.byKey(const Key('submit-provider-demo')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('submit-provider-demo'))).onPressed,isNull);
    await reveal(tester,find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));await tester.pumpAndSettle();
    await reveal(tester,find.byKey(const Key('submit-provider-demo')));
    await tester.tap(find.byKey(const Key('submit-provider-demo')));await tester.pumpAndSettle();
    expect(find.text('Choose your demo package'),findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('token'),isNull);
  });

  testWidgets('reentry restores demo activity and keeps real sign-in reachable', (tester) async {
    final store = await ProviderDemoStore.load();
    await store.register(name:'Returning technician',specialty:'Plumber',acknowledged:true);
    await store.activatePlan('start');
    await store.exit();
    await tester.pumpWidget(const ProviderScope(child:MaterialApp(locale:Locale('en'),home:ProviderDemoScreen())));
    await tester.pumpAndSettle();
    expect((await ProviderDemoStore.load()).active,true);
    expect((await ProviderDemoStore.load()).planId,'start');
    expect(find.text('Technician dashboard'),findsOneWidget);
    await reveal(tester,find.text('Use a real account'));
    await tester.tap(find.text('Use a real account'));await tester.pumpAndSettle();
    expect(find.text('Welcome Back'),findsOneWidget);
    expect((await ProviderDemoStore.load()).active,false);
  });

  testWidgets('cold launch restores the demo without a real login', (tester) async {
    final store = await ProviderDemoStore.load();
    await store.register(name:'Demo',specialty:'Plumber',acknowledged:true);
    await store.activatePlan('pro');
    await tester.pumpWidget(const ProviderScope(child:MaterialApp(locale:Locale('en'),home:AuthGate())));
    await tester.pumpAndSettle();
    expect(find.text('Technician dashboard'),findsOneWidget);
  });
}
