import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:service_app/services/api_http.dart';

void main() {
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
