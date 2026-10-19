import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';
import 'api_http.dart' as http;

/// Authenticated polling avoids depending on the original author's SignalR server.
class LocationTrackingService {
  Timer? _timer;
  int? _bookingId;
  bool _polling = false;
  bool _closed = false;
  void Function(double, double)? _callback;
  void Function(bool)? onAvailabilityChanged;
  DateTime? lastUpdated;

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    return {'Content-Type':'application/json','Authorization':'Bearer ${prefs.getString('token') ?? ''}'};
  }

  Future<void> connect() async {
    _closed = false;
    final response = await http.get(Uri.parse('${AppConfig.authBaseUrl}/me'), headers: await _headers());
    if (response.statusCode != 200) throw Exception('Unable to connect to location service.');
  }

  Future<void> joinBookingGroup(int bookingId) async {
    _bookingId = bookingId;
    await _poll();
    if (_closed || _bookingId != bookingId) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) { unawaited(_pollSafely()); });
  }

  Future<void> _pollSafely() async { try { await _poll(); } catch (_) { if (!_closed) onAvailabilityChanged?.call(false); } }
  Future<void> _poll() async {
    if (_polling || _closed || _bookingId == null) return;
    final id = _bookingId;
    _polling = true;
    try {
      final response = await http.get(Uri.parse('${AppConfig.endpoint('Location')}/$id'), headers: await _headers());
      if (_closed || _bookingId != id) return;
      if (response.statusCode == 409 || response.statusCode == 401 || response.statusCode == 404) {
        _timer?.cancel(); lastUpdated = null; onAvailabilityChanged?.call(false);
        throw Exception('Location is unavailable for this booking.');
      }
      if (response.statusCode != 200) throw Exception('Location is unavailable for this booking.');
      onAvailabilityChanged?.call(true);
      final data = jsonDecode(response.body);
      if (data is Map && data['latitude'] is num && data['longitude'] is num) {
        lastUpdated = DateTime.tryParse(data['updatedAt'] ?? '');
        _callback?.call((data['latitude'] as num).toDouble(), (data['longitude'] as num).toDouble());
      }
    } finally { _polling = false; }
  }

  Future<void> leaveBookingGroup(int bookingId) async {
    if (_bookingId == bookingId) { _timer?.cancel(); _bookingId = null; }
  }

  Future<void> sendLocation(int bookingId, double lat, double lng) async {
    if (_closed) return;
    final response = await http.put(Uri.parse('${AppConfig.endpoint('Location')}/$bookingId'), headers: await _headers(), body: jsonEncode({'latitude':lat,'longitude':lng}));
    if (response.statusCode != 200) throw Exception('Unable to send location.');
  }

  void onLocationReceived(Function(double lat, double lng) callback) { _callback = callback; }
  Future<void> disconnect() async { _closed = true; _timer?.cancel(); _bookingId = null; _callback = null; onAvailabilityChanged = null; }
}
