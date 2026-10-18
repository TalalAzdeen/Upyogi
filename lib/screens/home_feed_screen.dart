import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_model.dart';
import '../services/notification_service.dart';
import '../services/service_service.dart';
import 'notifications_screen.dart';
import 'service_details_screen.dart';

const kPrimaryPurple = Color(0xFF6C5CE7);
const kLightPurple = Color(0xFFF3F1FE);
const kDark = Color(0xFF1A1A2E);

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final _searchController = TextEditingController();
  List<ServiceModel> _services = [];
  bool _isLoading = true;
  String _selectedCategory = "All";
  String _fullName = "there";
  String? _profileImageUrl;
  int _unreadCount = 0;

  final List<String> _categories = [
    "All", "Cleaning", "Plumber", "Electrician", "AC Repair",
    "Carpenter", "Painter", "Appliance Repair", "Pest Control"
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadServices();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fullName = prefs.getString("fullName") ?? "there";
      _profileImageUrl = prefs.getString("profileImageUrl");
    });
    final count = await NotificationService.getUnreadCount();
    if (!mounted) return;
    setState(() => _unreadCount = count);
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    final result = await ServiceApiService.getServices(
      search: _searchController.text.trim(),
      category: _selectedCategory == "All" ? null : _selectedCategory,
      sortBy: "newest",
    );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadServices,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kLightPurple,
                          backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                              ? const Icon(Icons.person, color: kPrimaryPurple)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LText("Welcome,",
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(_fullName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        );
                        _loadUser(); // refresh badge count after viewing
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _iconCircle(Icons.notifications_outlined),
                          if (_unreadCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: LText(
                                  _unreadCount > 9 ? "9+" : "$_unreadCount",
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Title
                const LText(
                  "Smart Home,\nSmooth Services",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: kDark,
                  ),
                ),

                const SizedBox(height: 20),

                // Search
                Container(
                  decoration: BoxDecoration(
                    color: kLightPurple,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadServices(),
                    onChanged: (value) {
                      if (value.trim().isEmpty) {
                        _loadServices();
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      hintText: tr(context, "Search..."),
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.grey),
                        onPressed: _loadServices,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _loadServices();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Category pills
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final selected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            _loadServices();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? kDark : kLightPurple,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.center,
                            child: LText(
                              cat,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Services
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator(color: kPrimaryPurple)),
                  )
                else if (_services.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: LText("No services found yet",
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Column(
                    children: _services
                        .map((s) => _FeaturedServiceCard(service: s))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconCircle(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kLightPurple,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: kDark),
    );
  }
}

class _FeaturedServiceCard extends StatelessWidget {
  final ServiceModel service;
  const _FeaturedServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServiceDetailsScreen(serviceId: service.id)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: kLightPurple,
          image: service.imageUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(service.imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.15), BlendMode.darken),
                )
              : null,
        ),
        child: Stack(
          children: [
            // Rating badge
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    LText(
                      service.rating > 0 ? service.rating.toStringAsFixed(1) : "New",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            // Provider avatar
            Positioned(
              top: 16,
              left: 16,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: LText(
                  service.providerName.isNotEmpty
                      ? service.providerName[0].toUpperCase()
                      : "?",
                  style: const TextStyle(color: kPrimaryPurple, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Bottom content
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: LText(
                        service.category,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      service.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 16, color: kDark),
                              const SizedBox(width: 6),
                              const LText("Book Now",
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kDark)),
                            ],
                          ),
                        ),
                        LText(
                          "SAR ${service.startingPrice.toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
