import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_access.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerScreen({super.key, this.initialLat, this.initialLng});
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();
  LatLng? _selectedLocation;
  bool _loading = false;
  bool _mapReady = false;
  int _selectionGeneration = 0;
  String? _error;
  bool get _hasInitial => widget.initialLat != null && widget.initialLng != null &&
    widget.initialLat!.isFinite && widget.initialLng!.isFinite && widget.initialLat!.abs() <= 90 && widget.initialLng!.abs() <= 180;
  @override
  void initState() {
    super.initState();
    if (_hasInitial) { _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!); }
    else { _getCurrentLocation(); }
  }
  Future<void> _getCurrentLocation() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final generation = ++_selectionGeneration;
      final position = await LocationAccess.current();
      if (!mounted || generation != _selectionGeneration) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = point);
      if (_mapReady) _mapController.move(point, 15);
    } catch (e) {
      if (mounted) setState(() => _error = e is StateError ? e.message : 'Unable to get your location. Try again or select a point on the map.');
    } finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  void dispose() { _mapController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('Select Service Location')),
    body: Column(children: [
      if (_error != null) MaterialBanner(content: LText(_error!), actions: [
        TextButton(onPressed: () => Geolocator.openAppSettings(), child: const LText('App settings')),
      ]),
      const Padding(padding: EdgeInsets.all(12), child: LText('Tap the map to choose a point, or use your current location. No default point is selected.')),
      Expanded(child: Stack(children: [
        FlutterMap(mapController: _mapController, options: MapOptions(
          initialCenter: _selectedLocation ?? const LatLng(24.7136, 46.6753),
          initialZoom: _selectedLocation == null ? 4 : 15,
          onMapReady: () { _mapReady = true; if (_selectedLocation != null) _mapController.move(_selectedLocation!, 15); },
          onTap: (_, point) => setState(() { _selectionGeneration++; _selectedLocation = point; _error = null; }),
        ), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.upyogi.service_app'),
          if (_selectedLocation != null) MarkerLayer(markers: [Marker(point: _selectedLocation!, width: 48, height: 48,
            child: const Icon(Icons.location_on, size: 44, color: kPrimaryPurple))]),
        ]),
        Positioned(bottom: 8, left: 8, child: ColoredBox(color: Colors.white,
          child: TextButton(onPressed: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
            child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10))))),
        Positioned(bottom: 12, right: 12, child: FloatingActionButton(
          onPressed: _loading ? null : _getCurrentLocation,
          child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator()) : const Icon(Icons.my_location))),
      ])),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity,
        child: FilledButton(onPressed: _selectedLocation == null ? null : () => Navigator.pop(context, _selectedLocation),
          child: const LText('Confirm Location'))))),
    ]),
  );
}
