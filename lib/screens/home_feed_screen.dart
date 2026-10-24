import '../l10n/app_language.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../services/location_access.dart';
import 'map_picker_screen.dart';
import 'nearby_services_map.dart';
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
  Timer? _debounce;
  int _searchGeneration = 0;
  LatLng? _origin;
  double _radiusKm = 25;
  String _sortBy = 'newest';
  double? _minPrice;
  double? _maxPrice;
  bool _includeDemo = true;
  bool _loadingLocation = false;
  bool _showMap = false;
  String? _error;
  String? _locationError;

  @override
  void dispose() { _debounce?.cancel(); _searchController.dispose(); super.dispose(); }

  Future<void> _useMyLocation() async {
    if (_loadingLocation) return;
    setState(() { _loadingLocation = true; _locationError = null; });
    try {
      final position = await LocationAccess.current();
      if (!mounted) return;
      setState(() {
        _origin = LatLng(position.latitude, position.longitude);
        _includeDemo = false; _sortBy = 'nearest';
        if (position.accuracy > 500) _locationError = 'Your location is approximate. You can adjust it on the map.';
      });
      await _loadServices();
    } catch (e) {
      if (mounted) setState(() => _locationError = e is StateError ? e.message : 'Unable to get your location. Try again or select a point on the map.');
    } finally { if (mounted) setState(() => _loadingLocation = false); }
  }

  Future<void> _chooseSearchLocation() async {
    final point = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => MapPickerScreen(
      initialLat: _origin?.latitude, initialLng: _origin?.longitude)));
    if (point == null || !mounted) return;
    setState(() { _origin = point; _includeDemo = false; _sortBy = 'nearest'; _locationError = null; });
    await _loadServices();
  }

  Future<void> _filters() async {
    final min = TextEditingController(text: _minPrice?.toString() ?? '');
    final max = TextEditingController(text: _maxPrice?.toString() ?? '');
    var sort = _sortBy;
    String? error;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (_, update) => AlertDialog(
      title: const LText('Search filters'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: sort, decoration: InputDecoration(labelText: tr(context, 'Sort by')),
          items: [if (_origin != null) 'nearest', 'newest', 'price_asc', 'price_desc', 'rating'].map((v) => DropdownMenuItem(value: v,
            child: LText({'nearest':'Nearest first','newest':'Newest','price_asc':'Lowest price','price_desc':'Highest price','rating':'Highest rating'}[v]!))).toList(),
          onChanged: (value) => update(() => sort = value!)),
        const SizedBox(height: 12),
        TextField(controller: min, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr(context, 'Minimum price (SAR)'))),
        TextField(controller: max, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr(context, 'Maximum price (SAR)'))),
        if (error != null) LText(error!, style: const TextStyle(color: Colors.red)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const LText('Cancel')),
        FilledButton(onPressed: () {
          final low = min.text.trim().isEmpty ? null : double.tryParse(min.text.trim());
          final high = max.text.trim().isEmpty ? null : double.tryParse(max.text.trim());
          if ((min.text.trim().isNotEmpty && (low == null || !low.isFinite || low < 0)) ||
              (max.text.trim().isNotEmpty && (high == null || !high.isFinite || high < 0)) || (low != null && high != null && low > high)) {
            update(() => error = 'Enter a valid price range.'); return;
          }
          setState(() { _minPrice = low; _maxPrice = high; _sortBy = sort; });
          Navigator.pop(dialogContext); _loadServices();
        }, child: const LText('Apply'))],
    )));
    Future<void>.delayed(const Duration(milliseconds: 400), () { min.dispose(); max.dispose(); });
  }

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
    if (!mounted) return;
    final generation = ++_searchGeneration;
    setState(() { _isLoading = true; _error = null; });
    final result = await ServiceApiService.getServices(
      search: _searchController.text.trim(), category: _selectedCategory == 'All' ? null : _selectedCategory,
      sortBy: _sortBy, latitude: _origin?.latitude, longitude: _origin?.longitude,
      radiusKm: _radiusKm, minPrice: _minPrice, maxPrice: _maxPrice, includeDemo: _includeDemo,
    );
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) { _services = (result['data'] as List).map((e) => ServiceModel.fromJson(e)).toList(); }
      else { _services = []; _error = 'Unable to load services. Check your connection and retry.'; }
    });
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
                    onChanged: (_) {
                      setState(() {}); _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 350), _loadServices);
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

                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: _loadingLocation ? null : _useMyLocation,
                    icon: _loadingLocation ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                    label: const LText('Use my location'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: _chooseSearchLocation, icon: const Icon(Icons.map_outlined), label: const LText('Choose on map'))),
                ]),
                if (_locationError != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: LText(_locationError!, style: const TextStyle(color: Colors.orange))),
                if (_origin != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const LText('Search location'),
                    Text('${_origin!.latitude.toStringAsFixed(5)}, ${_origin!.longitude.toStringAsFixed(5)}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12)),
                  ])), IconButton(tooltip: tr(context, 'Clear location'), onPressed: () {setState(() { _origin = null; _sortBy = 'newest'; _showMap = false; _includeDemo = true; }); _loadServices();}, icon: const Icon(Icons.close))]),
                  const LText('Distances are straight-line distances to the advertised service location.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Row(children: [const LText('Within'), const SizedBox(width: 10),
                    DropdownButton<double>(value: _radiusKm, items: [5.0,10.0,25.0,50.0,100.0,200.0].map((v) => DropdownMenuItem(value: v, child: Text('${v.toInt()} ${tr(context, 'km')}'))).toList(),
                      onChanged: (v) {setState(() => _radiusKm = v!); _loadServices();}),
                    const Spacer(), TextButton.icon(onPressed: () => setState(() => _showMap = !_showMap),
                      icon: Icon(_showMap ? Icons.list : Icons.map), label: LText(_showMap ? 'List view' : 'Map view')),
                  ]),
                ],
                Row(children: [Expanded(child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const LText('Show demo listings'), value: _includeDemo,
                  onChanged: (v) {setState(() => _includeDemo = v); _loadServices();})), IconButton(onPressed: _filters, tooltip: tr(context, 'Search filters'), icon: const Icon(Icons.tune))]),
                if (_includeDemo) const Padding(padding: EdgeInsets.only(bottom: 12), child: LText('Demo listings and their locations are examples, not nearby verified technicians.', style: TextStyle(fontSize: 12, color: Colors.orange))),
                if (_error != null) Row(children: [Expanded(child: LText(_error!)), TextButton(onPressed: _loadServices, child: const LText('Retry'))]),
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
                else if (_showMap && _origin != null)
                  NearbyServicesMap(origin: _origin!, services: _services)
                else if (_services.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: LText("No matching technicians found. Try a wider radius or another service.",
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
                  image: ResizeImage(NetworkImage(service.imageUrl), width: 720),
                  onError: (_, _) {},
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.15), BlendMode.darken),
                )
              : null,
        ),
        child: Stack(
          children: [
            if (service.isDemo) const Positioned(top: 58, left: 16, child: Chip(label: LText('Demo listing'))),
            if (service.distanceKm != null) Positioned(top: 62, right: 16, child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Padding(padding: const EdgeInsets.all(8), child: Text('${service.distanceKm!.toStringAsFixed(1)} ${tr(context, 'km away')}')))),
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
