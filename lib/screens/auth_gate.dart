import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/provider_service.dart';
import '../services/role_provider.dart';
import 'main_shell.dart';
import 'provider_profile_setup_screen.dart';
import 'role_select_screen.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);

/// Decides the starting screen on app launch: signed-out users go to role
/// selection, signed-in users go straight to the home shell (or, for a
/// Provider who hasn't finished onboarding yet, the profile setup screen).
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  Widget? _resolvedScreen;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = prefs.getString("token");
    final role = prefs.getString("role");

    if (token == null || token.isEmpty) {
      setState(() => _resolvedScreen = const RoleSelectScreen());
      return;
    }

    ref.read(selectedRoleProvider.notifier).state = role ?? "Customer";

    if (role == "Provider") {
      final result = await ProviderService.getMyProfile();
      if (result["sessionExpired"] == true) {
        if (mounted) setState(() => _resolvedScreen = const RoleSelectScreen());
        return;
      }
      if (!mounted) return;
      setState(() {
        if (result['success'] == true) {
          _resolvedScreen = const MainShell();
        } else if (result['notFound'] == true) {
          _resolvedScreen = const ProviderProfileSetupScreen();
        } else {
          _resolvedScreen = Scaffold(body: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load your profile. Check your connection.'),
              TextButton(onPressed: () {
                setState(() => _resolvedScreen = null);
                _resolve();
              }, child: const Text('Retry')),
            ],
          )));
        }
      });
    } else {
      setState(() => _resolvedScreen = const MainShell());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _resolvedScreen ??
        const Scaffold(
          backgroundColor: kPrimaryPurple,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
  }
}
