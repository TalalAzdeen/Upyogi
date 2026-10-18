import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/booking_model.dart';
import '../services/location_tracking_service.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);

class CustomerTrackingScreen extends StatefulWidget {
  final BookingModel booking;
  const CustomerTrackingScreen({super.key, required this.booking});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final _locationService = LocationTrackingService();
  final MapController _mapController = MapController();
  LatLng? _providerLocation;
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

    _locationService.onLocationReceived((lat, lng) {
      if (!mounted) return;
      setState(() => _providerLocation = LatLng(lat, lng));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(LatLng(lat, lng), 15);
      });
    });

    if (!mounted) return;
    setState(() => _isConnecting = false);
    } catch (_) {
      await _locationService.disconnect();
      if (!mounted) return;
      setState(() { _isConnecting = false; _connectionError = 'Unable to connect to live tracking.'; });
    }
  }

  @override
  void dispose() {
    _locationService.leaveBookingGroup(widget.booking.id);
    _locationService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LText("Track Provider"),
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
          : _providerLocation == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: LText(
                      "Waiting for provider to start the service...",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _providerLocation!,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.upyogi.service_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _providerLocation!,
                          width: 50,
                          height: 50,
                          child: const Icon(Icons.directions_car,
                              color: kPrimaryPurple, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
