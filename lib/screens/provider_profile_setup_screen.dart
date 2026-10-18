import '../l10n/app_language.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/provider_service.dart';
import 'main_shell.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);

class ProviderProfileSetupScreen extends StatefulWidget {
  const ProviderProfileSetupScreen({super.key});

  @override
  State<ProviderProfileSetupScreen> createState() => _ProviderProfileSetupScreenState();
}

class _ProviderProfileSetupScreenState extends State<ProviderProfileSetupScreen> {
  final _picker = ImagePicker();

  XFile? _profileImage;
  XFile? _kycDocument;

  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _priceFromController = TextEditingController();
  final _priceToController = TextEditingController();
  final _radiusController = TextEditingController();
  final _addressController = TextEditingController();
  final _startTimeController = TextEditingController(text: tr(context, "09:00"));
  final _endTimeController = TextEditingController(text: tr(context, "18:00"));

  String? _selectedCategory;
  final List<String> _categories = [
    "Plumber", "Electrician", "AC Repair", "Carpenter",
    "Painter", "Cleaner", "Appliance Repair", "Pest Control"
  ];

  final Set<String> _selectedDays = {};
  final List<String> _weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;

  Future<void> _pickImage(bool isProfile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: kPrimaryPurple),
              title: const LText("Take Photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: kPrimaryPurple),
              title: const LText("Choose from Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isProfile) {
          _profileImage = picked;
        } else {
          _kycDocument = picked;
        }
      });
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permission denied");
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _addressController.text =
            "${p.street ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
      }

      setState(() {});
    } catch (e) {
      debugPrint("Location fetch error: $e");
      if (mounted) {
        _showError("Could not fetch location: $e");
      }
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submitProfile() async {
    if (_selectedCategory == null) {
      _showError("Please select a service category");
      return;
    }
    if (_bioController.text.trim().isEmpty) {
      _showError("Please enter a bio");
      return;
    }
    if (_selectedDays.isEmpty) {
      _showError("Please select working days");
      return;
    }
    if (_profileImage == null) {
      _showError("Please add a profile photo");
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ProviderService.saveProfile(
      bio: _bioController.text.trim(),
      experienceYears: int.tryParse(_experienceController.text) ?? 0,
      serviceCategory: _selectedCategory!,
      priceFrom: double.tryParse(_priceFromController.text) ?? 0,
      priceTo: double.tryParse(_priceToController.text) ?? 0,
      serviceRadiusKm: int.tryParse(_radiusController.text) ?? 5,
      workingDays: _selectedDays.join(","),
      workingHoursStart: _startTimeController.text,
      workingHoursEnd: _endTimeController.text,
      latitude: _latitude,
      longitude: _longitude,
      address: _addressController.text.trim(),
      profileImage: _profileImage,
      kycDocument: _kycDocument,
    );

    setState(() => _isSubmitting = false);

    if (result["success"] == true) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else if (result["sessionExpired"] != true) {
      debugPrint("Profile submit error: ${result["message"]}");
      _showError(result["message"]?.toString() ?? "Something went wrong");
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const LText("Error"),
        content: SingleChildScrollView(child: SelectableText(tr(context, msg))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LText("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: const BoxDecoration(
                color: kPrimaryPurple,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LText(
                    "Complete Your Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const LText(
                    "Help customers know more about your services",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo
                    Center(
                      child: GestureDetector(
                        onTap: () => _pickImage(true),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: kLightPurple,
                              backgroundImage: _profileImage != null
                                  ? FileImage(File(_profileImage!.path))
                                  : null,
                              child: _profileImage == null
                                  ? const Icon(Icons.person, size: 50, color: kPrimaryPurple)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: kPrimaryPurple,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                      BorderSide(color: Colors.white, width: 2)),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: LText("Add Profile Photo",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),

                    const SizedBox(height: 28),

                    // Service Category
                    _sectionTitle("Service Category"),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((cat) {
                        final selected = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? kPrimaryPurple : kLightPurple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: LText(
                              cat,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Bio
                    _sectionTitle("About You"),
                    _textField(_bioController, "Tell customers about your expertise...",
                        maxLines: 4),

                    const SizedBox(height: 24),

                    // Experience
                    _sectionTitle("Years of Experience"),
                    _textField(_experienceController, "e.g. 5",
                        keyboardType: TextInputType.number),

                    const SizedBox(height: 24),

                    // Price Range
                    _sectionTitle("Price Range (SAR )"),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(_priceFromController, "Min",
                              keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _textField(_priceToController, "Max",
                              keyboardType: TextInputType.number),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Service Radius
                    _sectionTitle("Service Radius (km)"),
                    _textField(_radiusController, "e.g. 10",
                        keyboardType: TextInputType.number),

                    const SizedBox(height: 24),

                    // Working Days
                    _sectionTitle("Working Days"),
                    Wrap(
                      spacing: 8,
                      children: _weekDays.map((day) {
                        final selected = _selectedDays.contains(day);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedDays.remove(day);
                              } else {
                                _selectedDays.add(day);
                              }
                            });
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: selected ? kPrimaryPurple : kLightPurple,
                            child: LText(
                              day,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Working Hours
                    _sectionTitle("Working Hours"),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(_startTimeController, "Start (HH:MM)"),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _textField(_endTimeController, "End (HH:MM)"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Location
                    _sectionTitle("Service Location"),
                    _textField(_addressController, "Your address", maxLines: 2),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isFetchingLocation ? null : _fetchLocation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryPurple,
                        side: const BorderSide(color: kPrimaryPurple),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isFetchingLocation
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: LText(_isFetchingLocation
                          ? "Fetching location..."
                          : "Use Current Location"),
                    ),

                    const SizedBox(height: 24),

                    // KYC Document
                    _sectionTitle("ID Verification (Optional)"),
                    GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kLightPurple,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: kPrimaryPurple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file, color: kPrimaryPurple),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LText(
                                _kycDocument != null
                                    ? "Document selected ✓"
                                    : "Upload ID Proof (Aadhar/PAN)",
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submitProfile,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const LText(
                                "Complete Profile",
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LText(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: tr(context, hint),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: kLightPurple,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
