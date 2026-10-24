# صلح — Sulh 1.5.0

[دليل التشغيل بالعربية](README_AR.md)

Arabic/English home service booking application, based on sandeepswain54/Upyogi.

Customers request bookings, technicians accept/reject requests and share their location while travelling. Payment is made directly to the technician after completion. The Supabase database, authentication, notifications, and existing accounts are retained.

## Smaller Android builds

Only imported runtime packages remain. Unused Firebase, Google Maps, Stripe, carousel, shimmer and duplicate state/network/image packages are excluded. Unused upstream images are not bundled. Service photos load from the database URLs with bounded decode sizes and placeholders.

```sh
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --reporter expanded
flutter build apk --release --split-per-abi --target-platform android-arm64,android-arm --split-debug-info=build/symbols
```

Use the arm64 APK for modern Android phones; arm32 is provided for older compatible devices. CI enforces a 50 MiB maximum per APK and publishes the exact sizes and SHA-256 hashes. These are release-mode test builds signed with the runner's debug signing key; replacing a previous build can require uninstalling it. Stable production signing and real two-device GPS testing remain separate steps.

The package identifier stays `com.upyogi.service_app` to preserve update compatibility. Never include Supabase service-role keys in the client. New online charges remain disabled. Demo services/reviews are explicitly labelled; no fabricated successful payments are added.
