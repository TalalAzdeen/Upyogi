import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
export 'package:http/http.dart' show Response, MultipartFile;

const requestTimeout = Duration(seconds: 30);

class ApiClient extends http.BaseClient {
  ApiClient({http.Client? inner, this.timeout = requestTimeout})
      : _inner = inner ?? http.Client();
  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
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
