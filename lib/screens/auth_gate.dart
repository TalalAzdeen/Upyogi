import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/provider_service.dart';
import '../services/role_provider.dart';
import 'main_shell.dart';
import 'provider_profile_setup_screen.dart';
import 'role_select_screen.dart';
import 'provider_demo_screen.dart';
import '../services/provider_demo_store.dart';
import '../services/journey_store.dart';
import 'experience_screen.dart';

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
      final journey = await JourneyStore.load();
      if (!mounted) return;
      if (journey.activeRole == 'Customer') {
        ref.read(selectedRoleProvider.notifier).state = 'Customer';
        setState(() => _resolvedScreen = const CustomerExperienceScreen());
        return;
      }
      final demo = await ProviderDemoStore.load();
      if (!mounted) return;
      final providerActive = journey.activeRole == 'Provider' || demo.active;
      if (providerActive) ref.read(selectedRoleProvider.notifier).state = 'Provider';
      setState(() => _resolvedScreen = providerActive ? const ProviderDemoScreen() : const RoleSelectScreen());
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
              const LText('Unable to load your profile. Check your connection.'),
              TextButton(onPressed: () {
                setState(() => _resolvedScreen = null);
                _resolve();
              }, child: const LText('Retry')),
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
