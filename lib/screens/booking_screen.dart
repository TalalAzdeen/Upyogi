import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/service_model.dart';
import '../services/booking_service.dart';
import 'map_picker_screen.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);

class BookingScreen extends StatefulWidget {
  final ServiceModel service;
  const BookingScreen({super.key, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  LatLng? _selectedLocation;
  int? _pendingBookingId;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimaryPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimaryPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _selectedLocation?.latitude,
          initialLng: _selectedLocation?.longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedLocation = result);
    }
  }

  Future<void> _confirmBooking() async {
    if (_isSubmitting) return;
    if (_selectedDate == null) return _showError('Please select a date');
    if (_selectedTime == null) return _showError('Please select a time');
    if (_addressController.text.trim().isEmpty) return _showError('Please enter service address');
    if (_phoneController.text.trim().isEmpty) return _showError('Please enter your phone number');
    final appointment = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
    if (!appointment.isAfter(DateTime.now())) return _showError('Choose a future appointment.');
    setState(() => _isSubmitting = true);
    try {
      if (_pendingBookingId == null) {
        final time = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
        final result = await BookingService.createBooking(
          serviceId: widget.service.id, appointmentDate: _selectedDate!,
          appointmentTime: time, serviceAddress: _addressController.text.trim(),
          notes: _notesController.text.trim(), customerPhone: _phoneController.text.trim(),
          latitude: _selectedLocation?.latitude, longitude: _selectedLocation?.longitude);
        if (!mounted || result['sessionExpired'] == true) return;
        if (result['success'] != true) {
          _showError('Booking could not be created. Please check your bookings before retrying.');
          return;
        }
        final data = result['data'];
        final booking = data is Map && data['booking'] is Map ? data['booking'] : data;
        if (booking is! Map || booking['id'] is! int) {
          _showError('Booking response was invalid. Check your bookings before retrying.');
          return;
        }
        _pendingBookingId = booking['id'] as int;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: LText('Booking requested. Pay the technician after the work is completed.')));
    } catch (_) {
      if (mounted) _showError('Unable to complete the request. Check your bookings before retrying.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      appBar: AppBar(
        title: const LText("Book Service", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kLightPurple,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.service.imageUrl.isNotEmpty
                        ? Image.network(widget.service.imageUrl,
                            height: 60, width: 60, cacheWidth: 180, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(height: 60, width: 60, child: Icon(Icons.home_repair_service_outlined)))
                        : Container(height: 60, width: 60, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.service.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        LText("by ${widget.service.providerName}",
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        LText("SAR ${widget.service.startingPrice.toStringAsFixed(2)}",
                            style: const TextStyle(
                                color: kPrimaryPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const LText("Appointment Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: kLightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: kPrimaryPurple, size: 18),
                    const SizedBox(width: 10),
                    LText(
                      _selectedDate == null
                          ? "Select date"
                          : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                      style: TextStyle(
                          color: _selectedDate == null ? Colors.grey : Colors.black87, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const LText("Appointment Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: kLightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: kPrimaryPurple, size: 18),
                    const SizedBox(width: 10),
                    LText(
                      _selectedTime == null ? "Select time" : _selectedTime!.format(context),
                      style: TextStyle(
                          color: _selectedTime == null ? Colors.grey : Colors.black87, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const LText("Service Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _field(_addressController, "Enter full address", maxLines: 2),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: kLightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: kPrimaryPurple, size: 18),
                    const SizedBox(width: 10),
                    LText(
                      _selectedLocation == null
                          ? "Pin exact location on map"
                          : "Location selected ✓ (${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)})",
                      style: TextStyle(
                        color: _selectedLocation == null ? Colors.grey : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const LText("Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _field(_phoneController, "Your contact number", keyboardType: TextInputType.phone),

            const SizedBox(height: 20),
            const LText("Additional Notes (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _field(_notesController, "Any special instructions...", maxLines: 3),

            const SizedBox(height: 20),
            const ListTile(leading: Icon(Icons.handshake_outlined),
              title: LText('Pay after completion'),
              subtitle: LText('Pay the technician directly after the work is completed. No payment is collected in the app.')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _isSubmitting ? null : _confirmBooking,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const LText("Confirm Booking", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
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
