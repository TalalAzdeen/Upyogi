import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_language.dart';
import '../models/service_model.dart';
import 'service_details_screen.dart';

class NearbyServicesMap extends StatelessWidget {
  final LatLng origin;
  final List<ServiceModel> services;
  const NearbyServicesMap({super.key, required this.origin, required this.services});
  @override
  Widget build(BuildContext context) => SizedBox(height: 360, child: Stack(children: [
    FlutterMap(key: ValueKey('${origin.latitude}:${origin.longitude}'), options: MapOptions(initialCenter: origin, initialZoom: 12), children: [
      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.upyogi.service_app'),
      MarkerLayer(markers: [
        Marker(point: origin, width: 40, height: 40, child: Tooltip(message: tr(context, 'Search location'), child: const Icon(Icons.my_location, color: Colors.blue, size: 32))),
        for (final service in services.where((s) => s.hasLocation)) Marker(point: LatLng(service.latitude!, service.longitude!), width: 48, height: 48,
          child: Tooltip(message: service.title, child: IconButton(icon: Icon(Icons.location_on, size: 38, color: service.isDemo ? Colors.orange : const Color(0xFF6C5CE7)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceDetailsScreen(serviceId: service.id)))))),
      ]),
    ]),
    Positioned(bottom: 4, left: 4, child: ColoredBox(color: Colors.white, child: TextButton(
      onPressed: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
      child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10))))),
  ]));
}
