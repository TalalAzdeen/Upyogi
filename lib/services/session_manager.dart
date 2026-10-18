import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/role_select_screen.dart';
import 'navigation_service.dart';

/// Handles a backend-rejected (expired/invalid) session: clears local auth
/// state and drops the user back to role selection so they can log back in,
/// instead of leaving them stuck on a raw 401 error.
class SessionManager {
  static bool _handling = false;

  static Future<void> handleSessionExpired() async {
    if (_handling) return;
    _handling = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['token', 'role', 'fullName', 'profileImageUrl']) {
        await prefs.remove(key);
      }

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (route) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text("Session expired. Please log in again.")),
          );
        }
      });
    } finally {
      _handling = false;
    }
  }
}
