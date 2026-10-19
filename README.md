# Upyogi 1.4.0

[دليل التشغيل بالعربية](README_AR.md)

Flutter Android service booking app, based on sandeepswain54/Upyogi.

- Arabic/English interfaces, saved language choice, RTL/LTR layout.
- Customers request appointments without entering payment details. Payment is arranged directly with the technician after the work is complete.
- Providers land on incoming service requests, accept/reject, start their journey with location sharing, and complete the service. The page refreshes every five seconds while open and includes a direct sign-out action.
- Customers view the technician on an OpenStreetMap map. Only booking participants can access tracking; location access stops after completion. Stale/offline positions are identified.
- Android journey tracking uses a foreground location notification while the tracking screen remains open, including during navigation. Tracking is not guaranteed after force-closing the app. Device testing is required.
- Supabase Auth, Postgres, private storage and authenticated Edge Function API. New online charges/top-ups are disabled server-side; historical financial records are preserved.

## Development

Flutter 3.47.7, Java 17. The API defaults to the connected project in `lib/services/app_config.dart`; optional overrides use `.env` (`API_BASE_URL`, `AUTH_BASE_URL`). Never put a service-role key in the client.

```sh
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --reporter expanded
flutter build apk --debug
```

Apply `backend/supabase/offline_workflow.sql` after the foundation, core and location schemas, then deploy `backend/supabase/functions/upyogi-api/index.ts`. Public email registration requires working SMTP/confirmation. Existing manually confirmed demo accounts are separate from public sign-up.

GitHub Actions builds an installable debug APK. Debug signing keys may differ across runners, so replacing a prior test APK can require uninstalling it first. Incoming requests refresh while the app is open; background push notifications are not configured.
