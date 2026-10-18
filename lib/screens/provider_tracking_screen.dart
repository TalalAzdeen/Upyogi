import 'dart:async';
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Please enable location services");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BackgroundLocationDisclosureDialog(),
      );

      if (agreed != true) return;
      if (!mounted) return;

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError("Location permission denied");
        return;
      }
    }

    setState(() => _isSharing = true);

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) async {
      try {
        await _locationService.sendLocation(widget.booking.id,
            position.latitude, position.longitude);
      } catch (_) {
        if (mounted) _showError('Unable to send your location. Check your connection.');
      }
    }, onError: (Object error) {
      if (mounted) {
        setState(() => _isSharing = false);
        _showError('Location sharing stopped. Check location permission and try again.');
      }
    });
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
    final success = await BookingService.completeBooking(widget.booking.id);
    if (success) {
      _positionStream?.cancel();
      await _locationService.leaveBookingGroup(widget.booking.id);
      await _locationService.disconnect();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service marked as completed!")),
        );
      }
    } else {
      _showError("Failed to complete service");
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
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
        title: const Text("Service Tracking", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryPurple,
        foregroundColor: Colors.white,
      ),
      body: _connectionError != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_connectionError!),
              TextButton(onPressed: _init, child: const Text('Retry')),
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
                        Text("Customer: ${b.customerName}", style: const TextStyle(fontSize: 13)),
                        Text("Phone: ${b.customerPhone}", style: const TextStyle(fontSize: 13)),
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
                        onPressed: () {
                          _openNavigation();
                          _startSharing();
                        },
                        icon: const Icon(Icons.navigation, color: Colors.white),
                        label: const Text("Start Service & Navigate",
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
                            child: Text("Sharing your live location with customer...",
                                style: TextStyle(color: Colors.green, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _completeService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text("Complete Service",
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
