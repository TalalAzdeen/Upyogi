import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/main.dart';
import 'package:service_app/l10n/app_language.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLanguage.instance.value = const Locale('ar');
  });

  testWidgets('Arabic starts RTL; switching language updates labels and preserves entered email', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    expect(find.text('من أنت؟'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('من أنت؟'))), TextDirection.rtl);
    await tester.tap(find.text('عميل'));
    await tester.pumpAndSettle();
    expect(find.text('مرحبًا بعودتك'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'customer@upyogi.test');
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Welcome Back'))), TextDirection.ltr);
    expect(find.text('customer@upyogi.test'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString(AppLanguage.preferenceKey), 'en');
    expect(tester.takeException(), isNull);
  });

  test('Saved language survives reloading preferences', () async {
    await AppLanguage.instance.select('en');
    AppLanguage.instance.value = const Locale('ar');
    await AppLanguage.instance.load();
    expect(AppLanguage.instance.value.languageCode,'en');
  });

  test('Both language directions cover wallet labels and formatted UI values', () {
    expect(translateFor('محفظتي','en'),'My wallet');
    expect(translateFor('Pending','ar'),'معلق');
    expect(translateFor('SAR 75.50 / Fixed','ar'),'75.50 ر.س / ثابت');
    expect(translateFor('75.50 ر.س','en'),'SAR 75.50');
    expect(translateFor('2h ago','ar'),'منذ ساعتين');
    expect(translateFor('Customer: Ada Example','ar'),'العميل: Ada Example');
  });

  testWidgets('Arabic role selection fits a narrow screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(360,800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MediaQuery(data:MediaQueryData(textScaler:TextScaler.linear(1.3)),child:ProviderScope(child:MyApp())));
    await tester.pumpAndSettle();
    expect(find.text('مقدم خدمة'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
