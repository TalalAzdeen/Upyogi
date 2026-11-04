import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/main.dart';
import 'package:service_app/l10n/app_language.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/services/journey_store.dart';
import 'package:service_app/screens/experience_screen.dart';
import 'package:service_app/screens/journey_booking_screen.dart';

void main(){
  late http.Client old;
  setUp((){SharedPreferences.setMockInitialValues({});AppLanguage.instance.value=const Locale('en');old=api.client;
    api.client=MockClient((_)async=>throw StateError('Simulation must be offline'));});
  tearDown((){api.client.close();api.client=old;});
  Future<void> reveal(WidgetTester t,Finder f)async{await t.scrollUntilVisible(f,160,scrollable:find.byType(Scrollable).first);await t.pumpAndSettle();}
  testWidgets('customer enters without password and resumes catalog after cold launch',(t)async{
    await t.pumpWidget(const ProviderScope(child:SulhApp()));await t.pumpAndSettle();
    await t.tap(find.text('User'));await t.pumpAndSettle();
    expect(find.text('Sulh for customers'),findsOneWidget);
    await reveal(t,find.byKey(const Key('fill-customer-demo')));
    await t.tap(find.byKey(const Key('fill-customer-demo')));await t.pumpAndSettle();
    await reveal(t,find.byKey(const Key('start-customer-demo')));
    await t.tap(find.byKey(const Key('start-customer-demo')));await t.pumpAndSettle();
    expect(find.byKey(const Key('journey-search')),findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('token'),isNull);
    await t.pumpWidget(const SizedBox());await t.pump();
    await t.pumpWidget(const ProviderScope(child:SulhApp()));await t.pumpAndSettle();
    expect(find.byKey(const Key('journey-search')),findsOneWidget);
  });
  testWidgets('booking validates details then creates one persisted request',(t)async{
    final s=await JourneyStore.load();await s.registerCustomer('Demo');
    await t.pumpWidget(const ProviderScope(child:MaterialApp(home:JourneyBookingScreen(serviceId:1))));await t.pumpAndSettle();
    await reveal(t,find.byKey(const Key('fill-journey-booking')));
    await t.tap(find.byKey(const Key('fill-journey-booking')));await t.pumpAndSettle();
    await reveal(t,find.byKey(const Key('confirm-journey-booking')));
    await t.tap(find.byKey(const Key('confirm-journey-booking')));await t.pumpAndSettle();
    expect((await JourneyStore.load()).bookings.length,1);
    expect(find.text('Booking timeline'),findsOneWidget);
    expect(find.byKey(const Key('settle-skipped')),findsNothing);
    expect(t.takeException(),isNull);
  });
  testWidgets('technician progresses request and customer settles and reviews it',(t)async{
    final s=await JourneyStore.load();await s.registerCustomer('Demo');
    final b=await s.book(serviceId:1,appointment:DateTime.now().add(const Duration(days:1)),address:'Demo street',phone:'0500000000',notes:'');
    await t.pumpWidget(ProviderScope(child:MaterialApp(home:JourneyBookingScreen(bookingId:b.id,technician:true))));await t.pumpAndSettle();
    for(final next in ['Accepted','OnTheWay','InProgress','Completed']){
      await reveal(t,find.byKey(Key('transition-$next')));await t.tap(find.byKey(Key('transition-$next')));await t.pumpAndSettle();
    }
    expect((await JourneyStore.load()).booking(b.id).status,'Completed');
    await t.pumpWidget(const SizedBox());await t.pump();
    await t.pumpWidget(ProviderScope(child:MaterialApp(home:JourneyBookingScreen(bookingId:b.id))));await t.pumpAndSettle();
    await reveal(t,find.byKey(const Key('settle-skipped')));await t.tap(find.byKey(const Key('settle-skipped')));await t.pumpAndSettle();
    await reveal(t,find.byKey(const Key('review-star-5')));await t.tap(find.byKey(const Key('review-star-5')));await t.pumpAndSettle();
    await reveal(t,find.byKey(const Key('submit-journey-review')));await t.tap(find.byKey(const Key('submit-journey-review')));await t.pumpAndSettle();
    final done=(await JourneyStore.load()).booking(b.id);expect(done.payment,'Skipped');expect(done.rating,5);
    expect(t.takeException(),isNull);
  });
  testWidgets('Arabic customer welcome fits a narrow screen and real sign-in remains reachable',(t)async{
    t.view.physicalSize=const Size(360,800);t.view.devicePixelRatio=1;
    addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
    AppLanguage.instance.value=const Locale('ar');
    await t.pumpWidget(const ProviderScope(child:SulhApp()));await t.pumpAndSettle();await t.tap(find.text('عميل'));await t.pumpAndSettle();
    expect(find.text('صلح للعميل'),findsOneWidget);expect(t.takeException(),isNull);
    await reveal(t,find.text('استخدام حساب حقيقي'));await t.tap(find.text('استخدام حساب حقيقي'));await t.pumpAndSettle();
    expect(find.text('مرحبًا بعودتك'),findsOneWidget);expect(t.takeException(),isNull);
  });
}
