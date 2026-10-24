import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_language.dart';
import 'screens/auth_gate.dart';
import 'services/navigation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLanguage.instance.load();
  await dotenv.load(fileName: '.env', isOptional: true);

  runApp(const ProviderScope(child: SulhApp()));
}

class SulhApp extends StatelessWidget {
  const SulhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.instance,
      builder: (context, locale, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: locale.languageCode == 'ar' ? 'صلح' : 'Sulh',
          navigatorKey: navigatorKey,
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF6C5CE7),
            scaffoldBackgroundColor: const Color(0xFFF7F4FF),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              foregroundColor: Colors.white,
              backgroundColor: Color(0xFF6C5CE7),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
