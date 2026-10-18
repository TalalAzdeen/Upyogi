import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_http.dart' as http;
import 'app_config.dart';

class WalletService {
  static String requestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0,8)}-${s.substring(8,12)}-${s.substring(12,16)}-${s.substring(16,20)}-${s.substring(20)}';
  }

  static Future<Map<String, dynamic>> _call(String path, {Map<String, dynamic>? body}) async {
    final prefs = await SharedPreferences.getInstance();
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('token') ?? ''}'};
    final uri = Uri.parse('${AppConfig.endpoint('Wallet')}$path');
    final response = body == null ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'تعذر الاتصال بالمحفظة.');
    }
    return data;
  }

  static Future<Map<String, dynamic>> load() => _call('');
  static Future<Map<String, dynamic>> topup(int amountMinor, String requestId) =>
      _call('/topup', body: {'amountMinor': amountMinor, 'requestId': requestId});
}
