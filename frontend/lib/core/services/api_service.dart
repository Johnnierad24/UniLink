import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    return _client.get(uri, headers: {'Content-Type': 'application/json'});
  }

  Future<http.Response> post(String path,
      {Map<String, dynamic>? body, String? token}) async {
    return _client.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> patch(String path,
      {Map<String, dynamic>? body, String? token}) async {
    return _client.patch(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String path, {String? token}) async {
    return _client.delete(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(token),
    );
  }

  Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
}
