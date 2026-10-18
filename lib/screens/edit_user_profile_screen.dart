import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);

class EditUserProfileScreen extends StatefulWidget {
  const EditUserProfileScreen({super.key});

  @override
  State<EditUserProfileScreen> createState() => _EditUserProfileScreenState();
}

class _EditUserProfileScreenState extends State<EditUserProfileScreen> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  XFile? _newImage;
  String? _currentImageUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString("fullName") ?? "";
      _currentImageUrl = prefs.getString("profileImageUrl");
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) setState(() => _newImage = picked);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      var request = http.MultipartRequest(
        "PUT",
        Uri.parse("${AuthService.baseUrl}/edit-profile"),
      );
      request.headers["Authorization"] = "Bearer $token";
      request.fields["fullName"] = _nameController.text.trim();

      if (_newImage != null) {
        request.files.add(await http.MultipartFile.fromPath("profileImage", _newImage!.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);



      if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
        return;
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString("fullName", data["fullName"]);
        if (data["profileImageUrl"] != null) {
          await prefs.setString("profileImageUrl", data["profileImageUrl"]);
        }
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully")),
          );
        }
      } else {
        _showError("(${response.statusCode}) ${response.body}");
      }
    } catch (e) {
      debugPrint("editProfile -> exception: $e");
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError("Something went wrong: $e");
    }
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
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: kLightPurple,
                      backgroundImage: _newImage != null
                          ? FileImage(File(_newImage!.path))
                          : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                              ? NetworkImage(_currentImageUrl!)
                              : null) as ImageProvider?,
                      child: (_newImage == null &&
                              (_currentImageUrl == null || _currentImageUrl!.isEmpty))
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
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: kLightPurple,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Save Changes", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
