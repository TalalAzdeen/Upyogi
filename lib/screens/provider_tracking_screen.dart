import '../l10n/app_language.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/booking_model.dart';
import '../services/location_tracking_service.dart';
import '../services/booking_service.dart';
import 'background_location_disclosure_dialog.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);

class ProviderTrackingScreen extends StatefulWidget {
  final BookingModel booking;
  const ProviderTrackingScreen({super.key, required this.booking});

  @override
  State<ProviderTrackingScreen> createState() => _ProviderTrackingScreenState();
}

class _ProviderTrackingScreenState extends State<ProviderTrackingScreen> {
  final _locationService = LocationTrackingService();
  StreamSubscription<Position>? _positionStream;
  bool _isSharing = false;
  bool _busy = false;
  bool _sending = false;
  bool _isConnecting = true;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (mounted) setState(() { _isConnecting = true; _connectionError = null; });
    try {
    await _locationService.connect();
    await _locationService.joinBookingGroup(widget.booking.id);
    if (!mounted) return;
    setState(() => _isConnecting = false);
    } catch (_) {
      await _locationService.disconnect();
      if (!mounted) return;
      setState(() { _isConnecting = false; _connectionError = 'Unable to connect to live tracking.'; });
    }
  }

  Future<void> _startSharing() async {
    if (_busy || _isSharing) return;
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showError('Please enable location services'); return;
      }
      if (!mounted) return;
      final agreed = await showDialog<bool>(context: context,
        builder: (_) => const BackgroundLocationDisclosureDialog());
      if (agreed != true || !mounted) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showError('Location permission denied'); return;
      }
      final first = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
      if (!mounted) return;
      if (!await BookingService.startTravel(widget.booking.id, first.latitude, first.longitude)) {
        _showError('Unable to start the journey. Please try again.'); return;
      }
      if (!mounted) return;
      final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 10,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: tr(context, 'Journey tracking'),
              notificationText: tr(context, 'Your location is shared with this booking customer.'),
              enableWakeLock: true))
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
      await _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((position) async {
        if (_sending || !mounted) return;
        _sending = true;
        try {
          await _locationService.sendLocation(widget.booking.id, position.latitude, position.longitude);
        } catch (_) {
          if (mounted) _showError('Unable to send your location. Check your connection.');
        } finally { _sending = false; }
      }, onError: (Object error) {
        _positionStream?.cancel();
        if (mounted) {
          setState(() => _isSharing = false);
          _showError('Location sharing stopped. Check location permission and try again.');
        }
      });
      setState(() => _isSharing = true);
      await _openNavigation();
    } catch (_) {
      _showError('Unable to start the journey. Please try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _openNavigation() async {
    if (widget.booking.serviceAddress.isEmpty) return;

    // Uses OpenStreetMap-based navigation via browser (OSRM demo routing)
    final url =
        "https://www.openstreetmap.org/directions?to=${Uri.encodeComponent(widget.booking.serviceAddress)}";

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _completeService() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const LText('Complete Service'),
      content: const LText('Confirm the work is finished. Payment is arranged directly with the customer outside the app.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('Complete Service'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final success = await BookingService.completeBooking(widget.booking.id);
    if (success) {
      await _positionStream?.cancel();
      await _locationService.disconnect();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: LText('Service marked as completed!')));
      }
    } else { _showError('Failed to complete service'); }
    if (mounted) setState(() => _busy = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: LText(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _locationService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const LText("Service Tracking", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryPurple,
        foregroundColor: Colors.white,
      ),
      body: _connectionError != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              LText(_connectionError!),
              TextButton(onPressed: _init, child: const LText('Retry')),
            ]))
          : _isConnecting
          ? const Center(child: CircularProgressIndicator(color: kPrimaryPurple))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        LText("Customer: ${b.customerName}", style: const TextStyle(fontSize: 13)),
                        LText("Phone: ${b.customerPhone}", style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(b.serviceAddress, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (!_isSharing) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _startSharing,
                        icon: const Icon(Icons.navigation, color: Colors.white),
                        label: const LText('Start Journey & Share Location',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.location_on, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(
                            child: LText("Sharing your live location with customer...",
                                style: TextStyle(color: Colors.green, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  ],
                  const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _completeService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const LText("Complete Service",
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
