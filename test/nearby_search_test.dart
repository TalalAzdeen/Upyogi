import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/services/service_service.dart';
import 'package:service_app/models/service_model.dart';
import 'package:service_app/services/confirmation_email_status.dart';
import 'package:service_app/l10n/app_language.dart';
import 'package:service_app/screens/home_feed_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client previous;
  setUp(() {previous = api.client; SharedPreferences.setMockInitialValues({});});
  tearDown(() {api.client.close(); api.client = previous;});

  test('Nearby request preserves zero coordinates, selected service and all filters', () async {
    api.client = MockClient((r) async {
      expect(r.url.queryParameters, containsPair('latitude','0.0'));
      expect(r.url.queryParameters, containsPair('longitude','0.0'));
      expect(r.url.queryParameters, containsPair('category','Cleaning'));
      expect(r.url.queryParameters, containsPair('radiusKm','10.0'));
      expect(r.url.queryParameters, containsPair('includeDemo','false'));
      expect(r.url.queryParameters, containsPair('sortBy','nearest'));
      expect(r.url.queryParameters, containsPair('minPrice','50.0'));
      return http.Response('[]',200);
    });
    final result = await ServiceApiService.getServices(latitude:0,longitude:0,category:'Cleaning',radiusKm:10,includeDemo:false,sortBy:'nearest',minPrice:50);
    expect(result['success'],true);
  });
  test('Incomplete and nonfinite points never issue a search request', () async {
    var calls=0;
    api.client=MockClient((_) async {calls++;return http.Response('[]',200);});
    for(final point in [[0.0,null],[double.nan,0.0],[91.0,0.0]]) {
      expect((await ServiceApiService.getServices(latitude:point[0],longitude:point[1]))['success'],false);
    }
    expect(calls,0);
  });
  test('Unknown service points stay unknown; valid zero is retained', () {
    expect(ServiceModel.fromJson({}).hasLocation,false);
    expect(ServiceModel.fromJson({'latitude':0,'longitude':0}).hasLocation,true);
    expect(ServiceModel.fromJson({'latitude':'NaN','longitude':0}).hasLocation,false);
    expect(ServiceModel.fromJson({'latitude':12}).hasLocation,false);
  });
  test('Submitted email never claims delivery and both languages cover new messages', () {
    expect(confirmationEmailMessage('submitted'),isNot(confirmationEmailMessage('delivered')));
    for(final value in ['Use my location','Choose on map','Nearest first',confirmationEmailMessage('not_configured'),confirmationEmailMessage('delivered')]) {
      expect(translateFor(value,'ar'),isNot(value));
      expect(translateFor(translateFor(value,'ar'),'en'),value);
    }
  });
  testWidgets('Search debounces typing and ignores an older response arriving last', (tester) async {
    final older=Completer<http.Response>(); final newer=Completer<http.Response>();
    final searches=<String>[];
    api.client=MockClient((r) async {
      if(!r.url.path.endsWith('/Service'))return http.Response('0',200);
      final query=r.url.queryParameters['search']??'';searches.add(query);
      if(query=='old')return older.future;
      if(query=='new')return newer.future;
      return http.Response('[]',200);
    });
    await tester.pumpWidget(const MaterialApp(locale:Locale('en'),home:HomeFeedScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'old');await tester.pump(const Duration(milliseconds:200));
    expect(searches,['']);await tester.pump(const Duration(milliseconds:151));
    await tester.enterText(find.byType(TextField),'new');await tester.pump(const Duration(milliseconds:351));
    newer.complete(http.Response('[{"id":2,"title":"Latest technician"}]',200));await tester.pumpAndSettle();
    older.complete(http.Response('[{"id":1,"title":"Outdated technician"}]',200));await tester.pumpAndSettle();
    expect(searches,['','old','new']);expect(find.text('Latest technician'),findsOneWidget);expect(find.text('Outdated technician'),findsNothing);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
