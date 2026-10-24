import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_http.dart' as http;
import 'app_config.dart';

class AuthService {
  static String get baseUrl => AppConfig.authBaseUrl;

  static String _message(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) return data['message'];
    } catch (_) {
      // Do not show raw HTML, stack traces, or server response bodies.
    }
    if (response.statusCode == 401) return 'Email or password is incorrect.';
    if (response.statusCode == 409) return 'An account with this email already exists.';
    if (response.statusCode >= 500) return 'The service is temporarily unavailable. Please try again.';
    return 'The request could not be completed (${response.statusCode}).';
  }

  static Future<Map<String, dynamic>> register(
      String fullName, String email, String password, String role) async {
    if (fullName.trim().isEmpty || !email.contains('@') || password.isEmpty) {
      return {'success': false, 'message': 'Enter your name, valid email, and password.'};
    }
    try {
      final response = await http.post(Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fullName': fullName.trim(), 'email': email.trim(),
          'password': password, 'role': role}));
      return response.statusCode >= 200 && response.statusCode < 300
          ? {'success': true}
          : {'success': false, 'message': _message(response)};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timed out. Please try again.'};
    } catch (_) {
      return {'success': false, 'message': 'Unable to connect. Check your connection and try again.'};
    }
  }

  static Future<Map<String, dynamic>> resendConfirmation(String email) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/resend-confirmation'),
        headers: {'Content-Type':'application/json'}, body: jsonEncode({'email':email.trim()}));
      return {'success':response.statusCode == 200, 'message':_message(response)};
    } catch (_) { return {'success':false,'message':'Unable to connect. Please try again.'}; }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    if (!email.contains('@') || password.isEmpty) {
      return {'success': false, 'message': 'Enter a valid email and password.'};
    }
    try {
      final response = await http.post(Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {'success': false, 'message': _message(response)};
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['token'] is! String ||
          (data['token'] as String).isEmpty || data['user'] is! Map ||
          !['Customer', 'Provider'].contains(data['user']['role'])) {
        return {'success': false, 'message': 'The server returned an invalid sign-in response.'};
      }
      final user = data['user'] as Map;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      if (data['refreshToken'] is String) {
        await prefs.setString('refreshToken', data['refreshToken']);
        await prefs.setInt('expiresAt', data['expiresAt'] is int ? data['expiresAt'] : 0);
      } else {
        await prefs.remove('refreshToken');
        await prefs.remove('expiresAt');
      }
      await prefs.setString('role', user['role']);
      await prefs.setString('fullName', user['fullName']?.toString() ?? '');
      await prefs.remove('profileImageUrl');
      if (user['profileImageUrl'] is String) {
        await prefs.setString('profileImageUrl', user['profileImageUrl']);
      }
      return {'success': true, 'data': data};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timed out. Please try again.'};
    } on FormatException {
      return {'success': false, 'message': 'The server returned an invalid sign-in response.'};
    } catch (_) {
      return {'success': false, 'message': 'Unable to connect. Check your connection and try again.'};
    }
  }
}
