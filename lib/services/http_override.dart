import 'dart:io';

/// Uses the platform trust store; invalid TLS certificates are rejected.
class MyHttpOverrides extends HttpOverrides {}
