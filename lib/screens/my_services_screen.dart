import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../models/service_model.dart';
import '../services/service_service.dart';
import 'edit_service_screen.dart';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  List<ServiceModel> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    final result = await ServiceApiService.getMyServices();

    if (!mounted || result["sessionExpired"] == true) return;

    if (result["success"] == true) {
      final List data = result["data"];
      setState(() {
        _services = data.map((e) => ServiceModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setLocation(ServiceModel service) async {
    final point = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => MapPickerScreen(
      initialLat: service.latitude, initialLng: service.longitude)));
    if (point == null || !mounted) return;
    try {
      final saved = await ServiceApiService.updateServiceLocation(service.id, point.latitude, point.longitude);
      if (!mounted) return;
      if (saved) { _loadServices(); }
      else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: LText('Unable to save the service location. Try again.'))); }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: LText('Unable to save the service location. Try again.')));
    }
  }

  Future<void> _toggleStatus(int id) async {
    final success = await ServiceApiService.toggleServiceStatus(id);
    if (success) {
      _loadServices();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText("Failed to update status")),
        );
      }
    }
  }

  Future<void> _deleteService(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText("Delete Service"),
        content: const LText("Are you sure you want to delete this service? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const LText("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LText("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ServiceApiService.deleteService(id);

      if (result["sessionExpired"] == true) return;

      if (result["success"] == true) {
        _loadServices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: LText("Service deleted")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const LText("My Services", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryPurple))
          : _services.isEmpty
              ? const Center(
                  child: LText("You haven't uploaded any services yet",
                      style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadServices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      final s = _services[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: s.imageUrl.isNotEmpty
                                      ? Image.network(s.imageUrl,
                                          height: 60, width: 60, cacheWidth: 180, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(height: 60, width: 60, child: Icon(Icons.home_repair_service_outlined)))
                                      : Container(
                                          height: 60, width: 60, color: kLightPurple,
                                          child: const Icon(Icons.image, color: kPrimaryPurple)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      LText("SAR ${s.startingPrice.toStringAsFixed(2)}",
                                          style: const TextStyle(color: kPrimaryPurple, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: s.isActive,
                                  activeThumbColor: kPrimaryPurple,
                                  onChanged: (_) => _toggleStatus(s.id),
                                ),
                              ],
                            ),
                            TextButton.icon(onPressed: () => _setLocation(s), icon: const Icon(Icons.location_on_outlined),
                              label: LText(s.hasLocation ? 'Update service location' : 'Set service location')),
                            const LText('This is your advertised service location. Customers can see it when searching nearby.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditServiceScreen(service: s),
                                        ),
                                      );
                                      _loadServices();
                                    },
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const LText("Edit"),
                                    style: OutlinedButton.styleFrom(foregroundColor: kPrimaryPurple),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _deleteService(s.id),
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    label: const LText("Delete", style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
