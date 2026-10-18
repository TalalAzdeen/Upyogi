import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/service_service.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);

class UploadServiceScreen extends StatefulWidget {
  const UploadServiceScreen({super.key});

  @override
  State<UploadServiceScreen> createState() => _UploadServiceScreenState();
}

class _UploadServiceScreenState extends State<UploadServiceScreen> {
  final _picker = ImagePicker();
  XFile? _serviceImage;

  final _titleController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _detailedDescController = TextEditingController();
  final _priceController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _startTimeController = TextEditingController(text: "09:00");
  final _endTimeController = TextEditingController(text: "18:00");
  final _providerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _experienceController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _skillsController = TextEditingController();
  final _durationController = TextEditingController();

  String? _selectedCategory;
  final List<String> _categories = [
    "Plumber", "Electrician", "AC Repair", "Carpenter",
    "Painter", "Cleaner", "Appliance Repair", "Pest Control"
  ];

  String _priceType = "Fixed";
  final Set<String> _selectedDays = {};
  final List<String> _weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  bool _emergencyService = false;
  bool _homeVisitAvailable = false;
  bool _materialsIncluded = false;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
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
              title: const Text("Take Photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: kPrimaryPurple),
              title: const Text("Choose from Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => _serviceImage = picked);
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return _showError("Enter a service title");
    if (_selectedCategory == null) return _showError("Select a category");
    if (_shortDescController.text.trim().isEmpty) return _showError("Enter a short description");
    if (_priceController.text.trim().isEmpty) return _showError("Enter starting price");
    if (_serviceImage == null) return _showError("Add a service image");
    if (_selectedDays.isEmpty) return _showError("Select working days");

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString("fullName") ?? "";

    final result = await ServiceApiService.createService(
      title: _titleController.text.trim(),
      category: _selectedCategory!,
      subcategory: _subcategoryController.text.trim(),
      shortDescription: _shortDescController.text.trim(),
      detailedDescription: _detailedDescController.text.trim(),
      startingPrice: double.tryParse(_priceController.text) ?? 0,
      priceType: _priceType,
      state: _stateController.text.trim(),
      city: _cityController.text.trim(),
      fullAddress: _addressController.text.trim(),
      pincode: _pincodeController.text.trim(),
      workingDays: _selectedDays.join(","),
      startTime: _startTimeController.text,
      endTime: _endTimeController.text,
      providerName: _providerNameController.text.trim().isEmpty
          ? fullName
          : _providerNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      experienceYears: int.tryParse(_experienceController.text) ?? 0,
      certifications: _certificationsController.text.trim(),
      skills: _skillsController.text.trim(),
      serviceDuration: _durationController.text.trim(),
      emergencyService: _emergencyService,
      homeVisitAvailable: _homeVisitAvailable,
      materialsIncluded: _materialsIncluded,
      serviceImage: _serviceImage,
    );

    setState(() => _isSubmitting = false);

    if (result["success"] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service uploaded successfully!")),
        );
        _clearForm();
      }
    } else if (result["sessionExpired"] != true) {
      debugPrint("Service upload error: ${result["message"]}");
      _showError(result["message"]?.toString() ?? "Something went wrong");
    }
  }

  void _clearForm() {
    _titleController.clear();
    _subcategoryController.clear();
    _shortDescController.clear();
    _detailedDescController.clear();
    _priceController.clear();
    _stateController.clear();
    _cityController.clear();
    _addressController.clear();
    _pincodeController.clear();
    _providerNameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _experienceController.clear();
    _certificationsController.clear();
    _skillsController.clear();
    _durationController.clear();
    setState(() {
      _serviceImage = null;
      _selectedCategory = null;
      _selectedDays.clear();
      _emergencyService = false;
      _homeVisitAvailable = false;
      _materialsIncluded = false;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: SingleChildScrollView(child: SelectableText(msg)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text("Upload Service", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Basic Information"),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kLightPurple,
                  borderRadius: BorderRadius.circular(14),
                  image: _serviceImage != null
                      ? DecorationImage(
                          image: FileImage(File(_serviceImage!.path)), fit: BoxFit.cover)
                      : null,
                ),
                child: _serviceImage == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo, color: kPrimaryPurple, size: 32),
                            SizedBox(height: 8),
                            Text("Add Service Image", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _field(_titleController, "Service Title"),
            const SizedBox(height: 12),
            _label("Category"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? kPrimaryPurple : kLightPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            color: selected ? Colors.white : Colors.black87, fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _field(_subcategoryController, "Subcategory"),
            const SizedBox(height: 12),
            _field(_shortDescController, "Short Description", maxLines: 2),
            const SizedBox(height: 12),
            _field(_detailedDescController, "Detailed Description", maxLines: 4),

            const SizedBox(height: 24),
            _sectionHeader("Pricing"),
            _field(_priceController, "Starting Price (SAR )", keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _label("Price Type"),
            Row(
              children: ["Fixed", "Hourly", "Daily"].map((type) {
                final selected = _priceType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: selected,
                    selectedColor: kPrimaryPurple,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                    onSelected: (_) => setState(() => _priceType = type),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            _sectionHeader("Location"),
            _field(_stateController, "State"),
            const SizedBox(height: 12),
            _field(_cityController, "City"),
            const SizedBox(height: 12),
            _field(_addressController, "Full Address", maxLines: 2),
            const SizedBox(height: 12),
            _field(_pincodeController, "Pincode", keyboardType: TextInputType.number),

            const SizedBox(height: 24),
            _sectionHeader("Availability"),
            Wrap(
              spacing: 8,
              children: _weekDays.map((day) {
                final selected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => setState(() {
                    selected ? _selectedDays.remove(day) : _selectedDays.add(day);
                  }),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: selected ? kPrimaryPurple : kLightPurple,
                    child: Text(day.substring(0, 2),
                        style: TextStyle(
                            fontSize: 11, color: selected ? Colors.white : Colors.black87)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_startTimeController, "Start Time")),
                const SizedBox(width: 12),
                Expanded(child: _field(_endTimeController, "End Time")),
              ],
            ),

            const SizedBox(height: 24),
            _sectionHeader("Contact Details"),
            _field(_providerNameController, "Provider Name"),
            const SizedBox(height: 12),
            _field(_phoneController, "Phone Number", keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_emailController, "Email", keyboardType: TextInputType.emailAddress),

            const SizedBox(height: 24),
            _sectionHeader("Experience"),
            _field(_experienceController, "Years of Experience",
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _field(_certificationsController, "Certifications (Optional)"),
            const SizedBox(height: 12),
            _field(_skillsController, "Skills (comma separated)"),

            const SizedBox(height: 24),
            _sectionHeader("Other Details"),
            _field(_durationController, "Service Duration (e.g. 2 hours)"),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Emergency Service", style: TextStyle(fontSize: 14)),
              value: _emergencyService,
              activeThumbColor: kPrimaryPurple,
              onChanged: (v) => setState(() => _emergencyService = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Home Visit Available", style: TextStyle(fontSize: 14)),
              value: _homeVisitAvailable,
              activeThumbColor: kPrimaryPurple,
              onChanged: (v) => setState(() => _homeVisitAvailable = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Materials Included", style: TextStyle(fontSize: 14)),
              value: _materialsIncluded,
              activeThumbColor: kPrimaryPurple,
              onChanged: (v) => setState(() => _materialsIncluded = v),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Upload Service",
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _field(TextEditingController controller, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
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
