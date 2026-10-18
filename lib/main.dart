import 'dart:async';
import 'dart:convert';
import 'services/api_http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'services/app_config.dart';
import 'l10n/app_language.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/navigation_service.dart';
import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();
  await dotenv.load(fileName: ".env", isOptional: true);
  final stripeKey = AppConfig.stripePublishableKey;
  if (AppConfig.paymentsEnabled) {
    Stripe.publishableKey = stripeKey;
  }
  runApp(const ProviderScope(child: MyApp()));
  unawaited(_loadPaymentSettings());
}

Future<void> _loadPaymentSettings() async {
  try {
    final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/health')).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return;
    final data = jsonDecode(response.body);
    final key = data['publishableKey'];
    if (data['paymentsConfigured'] == true && key is String && (key.startsWith('pk_test_') || key.startsWith('pk_live_'))) {
      AppConfig.serverStripePublishableKey = key;
      Stripe.publishableKey = key;
      await Stripe.instance.applySettings();
    }
  } catch (_) { /* Payment stays disabled until configuration is available. */ }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.instance,
      builder: (context, locale, _) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      navigatorKey: navigatorKey,
      title: 'Upyogi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const AuthGate(),
      ),
    );
  }
}
