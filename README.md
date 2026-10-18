> [دليل الإصدار 1.3.0 والإعداد والتشغيل بالعربية](README_AR.md)

<p align="center">
  <img src="assets/Screenshot%202026-08-17%20020605.png" alt="Upyogi on Google Play" width="800"/>
</p>

<h1 align="center">Upyogi Service Booking App</h1>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.upyogi.service_app">
    <img src="https://img.shields.io/badge/Google_Play-Download-blue?logo=googleplay&logoColor=white" alt="Get it on Google Play"/>
  </a>
</p>

A cross-platform Flutter application that connects **customers** with **local service providers** (electricians, plumbers, cleaners, etc.). Customers can discover services, book appointments, track their provider live on a map, and pay securely, while providers can list services, manage bookings, and track earnings — all from one app.

## ✨ Features

### For Customers
- Browse and search services by category, city, and price
- View detailed service listings with ratings & reviews
- Book appointments with date, time, address, and notes
- Real-time provider location tracking on a map during service
- In-app payments via Stripe / Google Pay & Apple Pay
- Rate and review providers after service completion
- Push/in-app notifications for booking updates

### For Service Providers
- Provider profile setup (skills, certifications, experience, working hours)
- Create, edit, and manage service listings with images
- Accept/manage incoming bookings and appointments
- Share live location with the customer during an active job
- View ratings, reviews, and booking history

### Shared
- Role-based onboarding (Customer / Provider) with secure JWT authentication
- Google Maps & OpenStreetMap based address picking, geocoding, and route polylines
- Offline/connectivity awareness
- Light, modern UI with shimmer loading states

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev) (Dart SDK ^3.7.2) |
| State Management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod), [provider](https://pub.dev/packages/provider), [get](https://pub.dev/packages/get) |
| Authentication | JWT-based custom Auth API + [firebase_auth](https://pub.dev/packages/firebase_auth) |
| Backend / API | Custom REST API ([ASP.NET](https://servicebookingapi.onrender.com)) |
| Real-time Communication | [SignalR](https://pub.dev/packages/signalr_netcore) (live location tracking hub) |
| Database & Storage | [Cloud Firestore](https://pub.dev/packages/cloud_firestore), [Firebase Storage](https://pub.dev/packages/firebase_storage), [Firebase Realtime Database](https://pub.dev/packages/firebase_database) |
| Payments | [flutter_stripe](https://pub.dev/packages/flutter_stripe), [pay](https://pub.dev/packages/pay) (Google Pay / Apple Pay) |
| Maps & Location | [google_maps_flutter](https://pub.dev/packages/google_maps_flutter), [flutter_map](https://pub.dev/packages/flutter_map), [geolocator](https://pub.dev/packages/geolocator), [geocoding](https://pub.dev/packages/geocoding), [location](https://pub.dev/packages/location), [flutter_polyline_points](https://pub.dev/packages/flutter_polyline_points) |
| Media | [image_picker](https://pub.dev/packages/image_picker), [cached_network_image](https://pub.dev/packages/cached_network_image) |
| Local Storage | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| UI/UX | [carousel_slider](https://pub.dev/packages/carousel_slider), [shimmer](https://pub.dev/packages/shimmer), [custom_rating_bar](https://pub.dev/packages/custom_rating_bar), [timeago](https://pub.dev/packages/timeago) |
| Utilities | [http](https://pub.dev/packages/http), [flutter_dotenv](https://pub.dev/packages/flutter_dotenv), [connectivity_plus](https://pub.dev/packages/connectivity_plus), [permission_handler](https://pub.dev/packages/permission_handler), [url_launcher](https://pub.dev/packages/url_launcher) |
| Platforms | Android, iOS, Web, Windows, macOS, Linux |

## 🏗️ Architecture

```
lib/
├── main.dart              # App entry point, env & Stripe/Firebase bootstrap
├── models/                 # Data models (Booking, Service, Review, Notification)
├── screens/                 # UI screens (auth, home, booking, tracking, profile...)
└── services/                 # API clients, auth, payments, location tracking, etc.
```

The app follows a **service-layer architecture**:
- **`models/`** — Plain Dart data classes with `fromJson` factories for API responses.
- **`screens/`** — Feature-based UI screens built with Flutter widgets and Riverpod for state.
- **`services/`** — Encapsulate all business logic and I/O: REST calls to the booking/payment/auth API, SignalR live-location hub, Firebase Auth/Firestore/Storage, and session management.

Live tracking works over a **SignalR hub** (`/hubs/location`) — providers push their coordinates, and customers subscribed to the same booking group receive updates in real time, rendered on `flutter_map`/`google_maps_flutter`.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (compatible with Dart `^3.7.2`)
- Android Studio / Xcode (for mobile builds) or a configured desktop/web toolchain
- A Firebase project (for Auth/Firestore/Storage)
- A Stripe account (for payments)

### 1. Clone & install dependencies
```bash
git clone <your-repo-url>
cd service_app
flutter pub get
```

### 2. Configure environment variables
Create a `.env` file in the project root (`service_app/.env`):
```env
AUTH_BASE_URL=<your auth api base url>
STRIPE_PUBLISHABLE_KEY=<your stripe publishable key>
TOGETHER_API_KEY=<your api key, if used>
```

### 3. Configure Firebase
- Add your `google-services.json` under `android/app/`
- Add your `GoogleService-Info.plist` under `ios/Runner/` (for iOS)
- Run `flutterfire configure` if you want to regenerate `firebase_options.dart`

### 4. Run the app
```bash
flutter run
```

### 5. Build for release
```bash
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
```

## 📱 App Icon & Assets
App icons are generated via `flutter_launcher_icons` from `assets/chatgpt.png`. Run the following after changing the source image:
```bash
flutter pub run flutter_launcher_icons
```

## 🔐 Permissions
The app requests the following device permissions (via `permission_handler` / `geolocator`):
- Location (foreground & background, for live tracking)
- Camera / Photos (for uploading service & profile images)

## 📄 License
This project currently has no explicit license. Add a `LICENSE` file if you intend to open-source it.
