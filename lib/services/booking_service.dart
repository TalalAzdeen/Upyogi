import 'dart:convert';
import 'api_http.dart' as http;
import 'app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_manager.dart';

class BookingService {
  static String get baseUrl => AppConfig.endpoint('Booking');

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>> createBooking({
    required int serviceId,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String serviceAddress,
    String? notes,
    required String customerPhone,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: await _headers(),
        body: jsonEncode({
          "serviceId": serviceId,
          "appointmentDate": appointmentDate.toIso8601String(),
          "appointmentTime": appointmentTime,
          "serviceAddress": serviceAddress,
          "notes": notes,
          "customerPhone": customerPhone,
          "latitude": latitude,
          "longitude": longitude,
        }),
      );


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

  static Future<Map<String, dynamic>> getCustomerBookings() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/customer"), headers: await _headers());


      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
        return {"success": false, "sessionExpired": true, "message": "Session expired"};
      }
      return {"success": false, "message": response.body};
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> getProviderBookings() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/provider"), headers: await _headers());


      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
        return {"success": false, "sessionExpired": true, "message": "Session expired"};
      }
      return {"success": false, "message": response.body};
    } catch (e) {

      return {"success": false, "message": "Error: $e"};
    }
  }

  static Future<bool> _updateStatus(int id, String action) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/$id/$action"),
        headers: await _headers(),
      );


      if (response.statusCode == 401) {
        SessionManager.handleSessionExpired();
      }
      return response.statusCode == 200;
    } catch (e) {

      return false;
    }
  }

  static Future<bool> startTravel(int id, double latitude, double longitude) async {
    final response = await http.put(Uri.parse('$baseUrl/$id/start-travel'),
      headers: await _headers(), body: jsonEncode({'latitude':latitude,'longitude':longitude}));
    return response.statusCode == 200;
  }

  static Future<bool> acceptBooking(int id) => _updateStatus(id, "accept");
  static Future<bool> rejectBooking(int id) => _updateStatus(id, "reject");
  static Future<bool> completeBooking(int id) => _updateStatus(id, "complete");
  static Future<bool> cancelBooking(int id) => _updateStatus(id, "cancel");
}
