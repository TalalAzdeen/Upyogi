import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/role_provider.dart';
import 'customer_tracking_screen.dart';
import 'provider_tracking_screen.dart';
import 'rating_dialog.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String _filter = "All"; // All, Upcoming, Completed, Cancelled

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final role = ref.read(selectedRoleProvider);
    final isProvider = role == "Provider";

    final result = isProvider
        ? await BookingService.getProviderBookings()
        : await BookingService.getCustomerBookings();

    if (result["sessionExpired"] == true) return;

    if (result["success"] == true) {
      final List data = result["data"];
      setState(() {
        _bookings = data.map((e) => BookingModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  List<BookingModel> get _filteredBookings {
    if (_filter == "All") return _bookings;
    if (_filter == "Upcoming") {
      return _bookings.where((b) =>
          b.bookingStatus == "Requested" || b.bookingStatus == "Accepted").toList();
    }
    if (_filter == "Completed") {
      return _bookings.where((b) => b.bookingStatus == "Completed").toList();
    }
    if (_filter == "Cancelled") {
      return _bookings.where((b) =>
          b.bookingStatus == "Cancelled" || b.bookingStatus == "Rejected").toList();
    }
    return _bookings;
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(selectedRoleProvider);
    final isProvider = role == "Provider";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const LText("Appointments", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ["All", "Upcoming", "Completed", "Cancelled"].map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? kPrimaryPurple : kLightPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: LText(f,
                            style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryPurple))
                : _filteredBookings.isEmpty
                    ? const Center(
                        child: LText("No appointments found",
                            style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _loadBookings,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredBookings.length,
                          itemBuilder: (context, index) {
                            return _BookingCard(
                              booking: _filteredBookings[index],
                              isProvider: isProvider,
                              onStatusChanged: _loadBookings,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isProvider;
  final VoidCallback onStatusChanged;

  const _BookingCard({
    required this.booking,
    required this.isProvider,
    required this.onStatusChanged,
  });

  Color _statusColor(String status) {
    switch (status) {
      case "Accepted":
        return Colors.blue;
      case "Completed":
        return Colors.green;
      case "Rejected":
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.orange; // Requested
    }
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    bool success = false;
    switch (action) {
      case "accept":
        success = await BookingService.acceptBooking(booking.id);
        break;
      case "reject":
        success = await BookingService.rejectBooking(booking.id);
        break;
      case "complete":
        success = await BookingService.completeBooking(booking.id);
        break;
      case "cancel":
        success = await BookingService.cancelBooking(booking.id);
        break;
    }

    if (success) {
      onStatusChanged();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText("Action failed, try again")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(booking.serviceTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(booking.bookingStatus).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LText(
                  booking.bookingStatus,
                  style: TextStyle(
                      color: _statusColor(booking.bookingStatus),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LText(
            isProvider ? "Customer: ${booking.customerName}" : "Provider: ${booking.providerName}",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: kPrimaryPurple),
              const SizedBox(width: 6),
              LText(
                "${booking.appointmentDate.day}/${booking.appointmentDate.month}/${booking.appointmentDate.year} • ${booking.appointmentTime}",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: kPrimaryPurple),
              const SizedBox(width: 6),
              Expanded(
                child: Text(booking.serviceAddress,
                    style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (isProvider) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: kPrimaryPurple),
                const SizedBox(width: 6),
                Text(booking.customerPhone, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LText(
                "SAR ${booking.amount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryPurple, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: booking.paymentStatus == "Paid"
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LText(
                  booking.paymentStatus,
                  style: TextStyle(
                      fontSize: 10,
                      color: booking.paymentStatus == "Paid" ? Colors.green : Colors.orange),
                ),
              ),
            ],
          ),

          // Action buttons
          if (isProvider && booking.bookingStatus == "Requested") ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleAction(context, "reject"),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const LText("Reject"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAction(context, "accept"),
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryPurple),
                    child: const LText("Accept", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ] else if (isProvider && booking.bookingStatus == "Accepted") ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProviderTrackingScreen(booking: booking)),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryPurple),
                child: const LText("Start Service", style: TextStyle(color: Colors.white)),
              ),
            ),
          ] else if (!isProvider &&
              (booking.bookingStatus == "Requested" || booking.bookingStatus == "Accepted")) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _handleAction(context, "cancel"),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                child: const LText("Cancel Booking"),
              ),
            ),
            if (booking.bookingStatus == "Accepted") ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CustomerTrackingScreen(booking: booking)),
                    );
                  },
                  icon: const Icon(Icons.location_on, color: kPrimaryPurple),
                  label: const LText("Track Provider", style: TextStyle(color: kPrimaryPurple)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: kPrimaryPurple)),
                ),
              ),
            ],
          ] else if (!isProvider && booking.bookingStatus == "Completed") ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => RatingDialog(
                      bookingId: booking.id,
                      serviceName: booking.serviceTitle,
                    ),
                  );
                  onStatusChanged();
                },
                icon: const Icon(Icons.star_border, color: Colors.amber),
                label: const LText("Rate Service", style: TextStyle(color: Colors.black87)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
