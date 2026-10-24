import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/main.dart';
import 'package:service_app/l10n/app_language.dart';
import 'package:service_app/services/app_config.dart';

void main() {
  setUp(() { SharedPreferences.setMockInitialValues({}); AppLanguage.instance.value = const Locale('en'); });

  testWidgets('Cold launch resolves to role selection without a session', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SulhApp()));
    await tester.pumpAndSettle();
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Sulh'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('User'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Leaving authentication disposes the form safely', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SulhApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Service Provider'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('Endpoint settings use HTTPS and reject embedded credentials', () {
    expect(AppConfig.normalizeUrl('https://example.com/'), 'https://example.com');
    expect(() => AppConfig.normalizeUrl('http://example.com'), throwsFormatException);
    expect(() => AppConfig.normalizeUrl('https://user:secret@example.com'), throwsFormatException);
    expect(() => AppConfig.normalizeUrl('https://example.invalid'), throwsFormatException);
    expect(AppConfig.authBaseUrl, '${AppConfig.defaultApiBaseUrl}/api/Auth');
    expect(AppConfig.paymentsEnabled, isFalse);
  });
}
