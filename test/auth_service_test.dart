import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/services/auth_service.dart';

void main() {
  late http.Client originalClient;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalClient = api.client;
  });
  tearDown(() { api.client.close(); api.client = originalClient; });

  test('Malformed login success never persists a token', () async {
    api.client = MockClient((_) async => http.Response('{"token":"abc"}', 200));
    final result = await AuthService.login('person@example.com', 'password');
    expect(result['success'], isFalse);
    expect((await SharedPreferences.getInstance()).getString('token'), isNull);
  });

  test('Login uses the verified endpoint, preserves password spaces and role', () async {
    api.client = MockClient((request) async {
      expect(request.url.toString(), 'https://prsyiadiplvumfjesfdf.supabase.co/functions/v1/upyogi-api/api/Auth/login');
      expect(jsonDecode(request.body)['password'], ' password ');
      return http.Response(jsonEncode({'token': 'test-session', 'user': {
        'role': 'Provider', 'fullName': 'Test Provider'}}), 200);
    });
    expect((await AuthService.login('person@example.com', ' password '))['success'], isTrue);
    expect((await SharedPreferences.getInstance()).getString('role'), 'Provider');
  });

  test('HTML error response produces a readable message', () async {
    api.client = MockClient((_) async => http.Response('<html>server error</html>', 503));
    final result = await AuthService.login('person@example.com', 'password');
    expect(result['success'], isFalse);
    expect(result['message'], isNot(contains('<html>')));
  });

  test('Empty credentials do not send a request', () async {
    api.client = MockClient((_) async { fail('Unexpected network request'); });
    expect((await AuthService.login('', ''))['success'], isFalse);
  });
}
