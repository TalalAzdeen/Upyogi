import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../models/service_model.dart';
import '../services/review_service.dart';
import '../services/service_service.dart';
import 'booking_screen.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);

class ServiceDetailsScreen extends StatefulWidget {
  final int serviceId;
  const ServiceDetailsScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  ServiceModel? _service;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    final result = await ServiceApiService.getServiceById(widget.serviceId);
    if (result["success"] == true) {
      final reviewsData = await ReviewService.getServiceReviews(widget.serviceId);
      _reviews = reviewsData.map((e) => ReviewModel.fromJson(e)).toList();

      setState(() {
        _service = ServiceModel.fromJson(result["data"]);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryPurple)),
      );
    }

    if (_service == null) {
      return const Scaffold(
        body: Center(child: LText("Service not found")),
      );
    }

    final s = _service!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large image
                Stack(
                  children: [
                    s.imageUrl.isNotEmpty
                        ? Image.network(
                            s.imageUrl,
                            cacheWidth: 960,
                            errorBuilder: (_, _, _) => const SizedBox(height: 280, child: Center(child: Icon(Icons.home_repair_service_outlined, size: 60))),
                            height: 280,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            cacheWidth: 960,
                            errorBuilder: (_, _, _) => const SizedBox(height: 280, child: Center(child: Icon(Icons.home_repair_service_outlined, size: 60))),
                            height: 280,
                            color: kLightPurple,
                            child: const Icon(Icons.image, size: 60, color: kPrimaryPurple),
                          ),
                    Positioned(
                      top: 50,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: kLightPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: LText(s.category,
                            style: const TextStyle(color: kPrimaryPurple, fontSize: 12)),
                      ),
                      const SizedBox(height: 12),

                      // Title + rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.title,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              LText(
                                s.rating > 0 ? s.rating.toStringAsFixed(1) : "New",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (s.totalReviews > 0)
                                LText(" (${s.totalReviews})",
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: kLightPurple,
                            child: LText(
                              s.providerName.isNotEmpty ? s.providerName[0].toUpperCase() : "?",
                              style: const TextStyle(fontSize: 11, color: kPrimaryPurple),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LText("by ${s.providerName}",
                              style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Info grid
                      Row(
                        children: [
                          Expanded(
                              child: _infoTile(Icons.work_history_outlined,
                                  "${s.experienceYears} yrs", "Experience")),
                          Expanded(
                              child: _infoTile(Icons.location_on_outlined, s.city, "Location")),
                          Expanded(
                              child: _infoTile(
                                  Icons.access_time, s.serviceDuration, "Duration")),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const LText("About This Service",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        s.detailedDescription.isNotEmpty
                            ? s.detailedDescription
                            : s.shortDescription,
                        style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                      ),

                      const SizedBox(height: 24),
                      const LText("Working Hours",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: kPrimaryPurple),
                          const SizedBox(width: 8),
                          LText(s.workingDays.replaceAll(",", ", "),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: kPrimaryPurple),
                          const SizedBox(width: 8),
                          LText("${s.startTime} - ${s.endTime}",
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),

                      if (s.skills.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const LText("Skills",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: s.skills.split(",").map((skill) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: kLightPurple,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(skill.trim(), style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                        ),
                      ],

                      if (s.certifications != null && s.certifications!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const LText("Certifications",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(s.certifications!, style: const TextStyle(fontSize: 13)),
                      ],

                      if (_reviews.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const LText("Reviews", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        ..._reviews.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kLightPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const Spacer(),
                                  Row(
                                    children: List.generate(5, (i) => Icon(
                                      i < r.rating ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 14,
                                    )),
                                  ),
                                ],
                              ),
                              if (r.comment != null && r.comment!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(r.comment!, style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                        )),
                      ],

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (s.emergencyService) _badge("Emergency Service", Icons.bolt),
                          if (s.homeVisitAvailable) _badge("Home Visit", Icons.home_outlined),
                          if (s.materialsIncluded) _badge("Materials Included", Icons.inventory_2_outlined),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const LText("Contact",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 16, color: kPrimaryPurple),
                          const SizedBox(width: 8),
                          Text(s.phoneNumber, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 16, color: kPrimaryPurple),
                          const SizedBox(width: 8),
                          Text(s.email, style: const TextStyle(fontSize: 13)),
                        ],
                      ),

                      const SizedBox(height: 100), // space for bottom button
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Book button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LText("Starting from", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      LText("SAR ${s.startingPrice.toStringAsFixed(2)} / ${s.priceType}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BookingScreen(service: s)),
                      );
                    },
                    child: const LText("Book Service",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryPurple, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        LText(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _badge(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kLightPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: kPrimaryPurple),
            const SizedBox(width: 4),
            LText(text, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
