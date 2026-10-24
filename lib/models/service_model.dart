class ServiceModel {
  final int id;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isDemo;
  bool get hasLocation => latitude != null && longitude != null && latitude!.isFinite && longitude!.isFinite && latitude!.abs() <= 90 && longitude!.abs() <= 180;
  final String imageUrl;
  final String title;
  final String category;
  final String subcategory;
  final String shortDescription;
  final String detailedDescription;
  final double startingPrice;
  final String priceType;
  final String state;
  final String city;
  final String fullAddress;
  final String workingDays;
  final String startTime;
  final String endTime;
  final String providerName;
  final String phoneNumber;
  final String email;
  final int experienceYears;
  final String? certifications;
  final String skills;
  final String serviceDuration;
  final bool emergencyService;
  final bool homeVisitAvailable;
  final bool materialsIncluded;
  final double rating;
  final int totalReviews;
  final bool isActive;

  ServiceModel({
    required this.id,
    this.latitude, this.longitude, this.distanceKm, this.isDemo = false,
    required this.imageUrl,
    required this.title,
    required this.category,
    required this.subcategory,
    required this.shortDescription,
    required this.detailedDescription,
    required this.startingPrice,
    required this.priceType,
    required this.state,
    required this.city,
    required this.fullAddress,
    required this.workingDays,
    required this.startTime,
    required this.endTime,
    required this.providerName,
    required this.phoneNumber,
    required this.email,
    required this.experienceYears,
    this.certifications,
    required this.skills,
    required this.serviceDuration,
    required this.emergencyService,
    required this.homeVisitAvailable,
    required this.materialsIncluded,
    required this.rating,
    required this.totalReviews,
    required this.isActive,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] ?? 0,
      latitude: double.tryParse('${json['latitude']}'),
      longitude: double.tryParse('${json['longitude']}'),
      distanceKm: double.tryParse('${json['distanceKm']}'),
      isDemo: json['isDemo'] == true,
      imageUrl: json['imageUrl'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      shortDescription: json['shortDescription'] ?? '',
      detailedDescription: json['detailedDescription'] ?? '',
      startingPrice: (json['startingPrice'] ?? 0).toDouble(),
      priceType: json['priceType'] ?? 'Fixed',
      state: json['state'] ?? '',
      city: json['city'] ?? '',
      fullAddress: json['fullAddress'] ?? '',
      workingDays: json['workingDays'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      providerName: json['providerName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      email: json['email'] ?? '',
      experienceYears: json['experienceYears'] ?? 0,
      certifications: json['certifications'],
      skills: json['skills'] ?? '',
      serviceDuration: json['serviceDuration'] ?? '',
      emergencyService: json['emergencyService'] ?? false,
      homeVisitAvailable: json['homeVisitAvailable'] ?? false,
      materialsIncluded: json['materialsIncluded'] ?? false,
      rating: (json['rating'] ?? 0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }
}
