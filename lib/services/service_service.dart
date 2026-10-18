import 'dart:convert';
import 'api_http.dart' as http;
import 'app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_manager.dart';

class ServiceApiService {
  static String get baseUrl => AppConfig.endpoint('Service');

  static Future<Map<String, dynamic>> createService({
    required String title,
    required String category,
    required String subcategory,
    required String shortDescription,
    required String detailedDescription,
    required double startingPrice,
    required String priceType,
    required String state,
    required String city,
    required String fullAddress,
    required String pincode,
    double? latitude,
    double? longitude,
    required String workingDays,
    required String startTime,
    required String endTime,
    required String providerName,
    required String phoneNumber,
    required String email,
    required int experienceYears,
    String? certifications,
    required String skills,
    required String serviceDuration,
    required bool emergencyService,
    required bool homeVisitAvailable,
    required bool materialsIncluded,
    dynamic serviceImage, // XFile
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      var request = http.MultipartRequest("POST", Uri.parse(baseUrl));
      request.headers["Authorization"] = "Bearer $token";

      request.fields["Title"] = title;
      request.fields["Category"] = category;
      request.fields["Subcategory"] = subcategory;
      request.fields["ShortDescription"] = shortDescription;
      request.fields["DetailedDescription"] = detailedDescription;
      request.fields["StartingPrice"] = startingPrice.toString();
      request.fields["PriceType"] = priceType;
      request.fields["State"] = state;
      request.fields["City"] = city;
      request.fields["FullAddress"] = fullAddress;
      request.fields["Pincode"] = pincode;
      if (latitude != null) request.fields["Latitude"] = latitude.toString();
      if (longitude != null) request.fields["Longitude"] = longitude.toString();
      request.fields["WorkingDays"] = workingDays;
      request.fields["StartTime"] = startTime;
      request.fields["EndTime"] = endTime;
      request.fields["ProviderName"] = providerName;
      request.fields["PhoneNumber"] = phoneNumber;
      request.fields["Email"] = email;
      request.fields["ExperienceYears"] = experienceYears.toString();
      if (certifications != null) request.fields["Certifications"] = certifications;
      request.fields["Skills"] = skills;
      request.fields["ServiceDuration"] = serviceDuration;
      request.fields["EmergencyService"] = emergencyService.toString();
      request.fields["HomeVisitAvailable"] = homeVisitAvailable.toString();
      request.fields["MaterialsIncluded"] = materialsIncluded.toString();

      if (serviceImage != null) {
        request.files.add(await http.MultipartFile.fromPath("serviceImage", serviceImage.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);


      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
        return {"success": false, "sessionExpired": true, "message": "Session expired"};
      } else {
        return {"success": false, "message": "(${response.statusCode}) ${response.body}"};
      }
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> getServices({
    String? search,
    String? category,
    String? city,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params["search"] = search;
      if (category != null && category.isNotEmpty) params["category"] = category;
      if (city != null && city.isNotEmpty) params["city"] = city;
      if (minPrice != null) params["minPrice"] = minPrice.toString();
      if (maxPrice != null) params["maxPrice"] = maxPrice.toString();
      if (sortBy != null) params["sortBy"] = sortBy;

      final uri = Uri.parse(baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);


      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else {
        return {"success": false, "message": response.body};
      }
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> getMyServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final response = await http.get(
        Uri.parse("$baseUrl/my-services"),
        headers: {"Authorization": "Bearer $token"},
      );


      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
        return {"success": false, "sessionExpired": true, "message": "Session expired"};
      } else {
        return {"success": false, "message": response.body};
      }
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> getServiceById(int id) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/$id"));


      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else {
        return {"success": false, "message": response.body};
      }
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> deleteService(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final response = await http.delete(
        Uri.parse("$baseUrl/$id"),
        headers: {"Authorization": "Bearer $token"},
      );


      if (response.statusCode == 200) {
        return {"success": true};
      } else if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
        return {"success": false, "sessionExpired": true, "message": "Session expired"};
      } else {
        return {"success": false, "message": response.body};
      }
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }

  static Future<bool> toggleServiceStatus(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final response = await http.put(
        Uri.parse("$baseUrl/$id/toggle-status"),
        headers: {"Authorization": "Bearer $token"},
      );


      if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
      }
      return response.statusCode == 200;
    } catch (e) {

      return false;
    }
  }

  static Future<Map<String, dynamic>> updateService({
    required int id,
    required String title,
    required double startingPrice,
    required String shortDescription,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      var request = http.MultipartRequest("PUT", Uri.parse("$baseUrl/$id"));
      request.headers["Authorization"] = "Bearer $token";
      request.fields["Title"] = title;
      request.fields["StartingPrice"] = startingPrice.toString();
      request.fields["ShortDescription"] = shortDescription;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);


      if (response.statusCode == 200) {
        return {"success": true};
      } else if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
        return {"success": false, "sessionExpired": true, "message": "Session expired"};
      }
      return {"success": false, "message": response.body};
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }
}
