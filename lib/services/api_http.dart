import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';
export 'package:http/http.dart' show Response, MultipartFile;

const requestTimeout = Duration(seconds: 30);

class ApiClient extends http.BaseClient {
  ApiClient({http.Client? inner, this.timeout = requestTimeout})
      : _inner = inner ?? http.Client();
  final http.Client _inner;
  final Duration timeout;

  Future<void>? _refreshing;

  Future<void> _refreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refreshToken');
    final expiry = prefs.getInt('expiresAt') ?? 0;
    if (refresh == null || expiry > DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60) return;
    final response = await _inner.post(Uri.parse('${AppConfig.authBaseUrl}/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh})).timeout(timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['token'] is String && data['refreshToken'] is String && data['expiresAt'] is int) {
        await prefs.setString('token', data['token']);
        await prefs.setString('refreshToken', data['refreshToken']);
        await prefs.setInt('expiresAt', data['expiresAt']);
      }
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.headers.containsKey('Authorization') || request.headers.containsKey('authorization')) {
      if (request.url.toString().startsWith('${AppConfig.apiBaseUrl}/')) {
        _refreshing ??= _refreshSession();
        try { await _refreshing; } finally { _refreshing = null; }
        final token = (await SharedPreferences.getInstance()).getString('token');
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
      }
    }
    final response = await _inner.send(request).timeout(timeout);
    return http.StreamedResponse(
      response.stream.timeout(timeout), response.statusCode,
      headers: response.headers, request: response.request,
      contentLength: response.contentLength,
      reasonPhrase: response.reasonPhrase,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
    );
  }

  @override
  void close() => _inner.close();
}

http.Client client = ApiClient();

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    client.get(url, headers: headers).timeout(requestTimeout);
Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    client.post(url, headers: headers, body: body, encoding: encoding).timeout(requestTimeout);
Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    client.put(url, headers: headers, body: body, encoding: encoding).timeout(requestTimeout);
Future<http.Response> delete(Uri url, {Map<String, String>? headers}) =>
    client.delete(url, headers: headers).timeout(requestTimeout);

class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(super.method, super.url);
  @override
  Future<http.StreamedResponse> send() => client.send(this).timeout(requestTimeout);
}
