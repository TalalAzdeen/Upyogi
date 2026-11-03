import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_model.dart';
import 'api_http.dart' as http;
import 'app_config.dart';
import 'session_manager.dart';

class DemoService {
  static Future<Map<String, dynamic>> _request(String path, {Map<String, dynamic>? body}) async {
    final prefs = await SharedPreferences.getInstance();
    final headers = {'Authorization': 'Bearer ${prefs.getString('token') ?? ''}', 'Content-Type': 'application/json'};
    final uri = Uri.parse('${AppConfig.endpoint('Demo')}/$path');
    final response = body == null ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 401) SessionManager.handleSessionExpired();
    if (response.statusCode != 200) throw StateError('Unable to update the demo. Reload and try again.');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) throw const FormatException('Invalid demo response');
    return data;
  }

  static Future<int> generateCatalog() async => (await _request('catalog', body: {}))['total'] as int;
  static Future<BookingModel> load(int id) async => BookingModel.fromJson(await _request('bookings/$id'));
  static Future<BookingModel> advance(BookingModel booking, {bool skipPayment = false}) async =>
      BookingModel.fromJson(await _request('bookings/${booking.id}/advance', body: {
        'expectedStatus': booking.bookingStatus, 'skipPayment': skipPayment,
      }));
}
