import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/services/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:service_app/services/api_http.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Expired access token refreshes before sending a protected request', () async {
    SharedPreferences.setMockInitialValues({'token':'old-token','refreshToken':'refresh-one','expiresAt':1});
    var refreshes=0;
    final client=ApiClient(inner:MockClient((request) async {
      if(request.url.path.endsWith('/refresh')) {
        refreshes++;
        expect(jsonDecode(request.body)['refreshToken'],'refresh-one');
        return http.Response(jsonEncode({'token':'new-token','refreshToken':'refresh-two','expiresAt':DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}),200);
      }
      expect(request.headers['Authorization'],'Bearer new-token');
      return http.Response('{}',200);
    }));
    addTearDown(client.close);
    await client.get(Uri.parse('${AppConfig.authBaseUrl}/me'),headers:{'Authorization':'Bearer old-token'});
    expect(refreshes,1);
    expect((await SharedPreferences.getInstance()).getString('refreshToken'),'refresh-two');
  });

  test('Unresponsive server times out instead of hanging', () async {
    final client = ApiClient(inner: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 10));
    addTearDown(client.close);
    await expectLater(client.get(Uri.parse('https://example.com')), throwsA(isA<TimeoutException>()));
  });

  test('Successful responses preserve headers and response bodies', () async {
    final client = ApiClient(inner: MockClient((_) async =>
      http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'})));
    addTearDown(client.close);
    final response = await client.get(Uri.parse('https://example.com'));
    expect(response.statusCode, 200);
    expect(response.body, '{"ok":true}');
    expect(response.headers['content-type'], contains('application/json'));
  });
}
