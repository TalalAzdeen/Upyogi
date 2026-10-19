import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);

/// Google Play "Prominent Disclosure" for background location access.
/// Must be shown and explicitly accepted before the OS background-location
/// permission prompt is triggered anywhere in the app.
class BackgroundLocationDisclosureDialog extends StatelessWidget {
  const BackgroundLocationDisclosureDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: kPrimaryPurple, size: 40),
              const SizedBox(height: 16),
              const LText(
                "Background Location Access",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const LText(
                'Your location is shared only with this booking customer while journey tracking is open, including while using navigation. Sharing stops when you leave this screen, sign out, or complete the service. Keep this screen open during the journey.',
                style: TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const LText("Not Now", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const LText("I Understand", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
