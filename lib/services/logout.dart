import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_language.dart';
import '../screens/role_select_screen.dart';
import 'api_http.dart' as http;
import 'app_config.dart';

Future<void> signOutAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
    title: const LText('Logout'),
    content: const LText('Do you want to sign out of this account?'),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('Logout'))],
  ));
  if (confirmed != true) return;
  final prefs = await SharedPreferences.getInstance();
  bool serverSignedOut = false;
  try {
    final response = await http.post(Uri.parse('${AppConfig.authBaseUrl}/logout'),
      headers: {'Authorization':'Bearer ${prefs.getString('token') ?? ''}'}).timeout(const Duration(seconds: 10));
    serverSignedOut = response.statusCode == 200;
  } catch (_) { /* Local sign-out is always available, including offline. */ }
  for (final key in ['token','refreshToken','expiresAt','role','fullName','profileImageUrl']) {
    await prefs.remove(key);
  }
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RoleSelectScreen()), (_) => false);
  if (!serverSignedOut) messenger.showSnackBar(const SnackBar(content: LText('Signed out on this device. The server could not be reached.')));
}
