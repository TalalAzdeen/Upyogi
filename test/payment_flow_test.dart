import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/services/api_http.dart' as api;
import 'package:service_app/services/payment_service.dart';

void main() {
  late http.Client original;
  setUp(() {
    original = api.client;
    SharedPreferences.setMockInitialValues({'token': 'test-session'});
  });
  tearDown(() { api.client.close(); api.client = original; });

  test('Rejected server confirmation is not reported as payment success', () async {
    api.client = MockClient((request) async {
      expect(request.url.path, '/api/Payment/confirm/42');
      return http.Response('Payment not confirmed', 503);
    });
    expect(await PaymentService.confirmPayment(42), isFalse);
  });

  test('Successful server confirmation returns success', () async {
    api.client = MockClient((_) async => http.Response('{}', 200));
    expect(await PaymentService.confirmPayment(42), isTrue);
  });

}
