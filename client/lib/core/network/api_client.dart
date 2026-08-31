import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Central HTTP API client connecting Flutter frontend to FastAPI backend.
/// Automatically handles JWT Bearer token injection and multi-tenant business context headers.
class ApiClient {
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1'; // 10.0.2.2 for Android emulator, localhost for web/desktop
  }

  static String _activeBusinessId = 'BIZ-DEFAULT-01';

  static void setActiveBusinessId(String businessId) {
    _activeBusinessId = businessId;
  }

  static Future<Map<String, String>> _getHeaders({Map<String, String>? extraHeaders}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Business-Id': _activeBusinessId,
    };

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('Notice: Bearer token injection fallback: $e');
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  static Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = await _getHeaders();
    return await http.get(uri, headers: headers);
  }

  static Future<http.Response> post(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final encodedBody = body != null ? jsonEncode(body) : null;
    return await http.post(uri, headers: headers, body: encodedBody);
  }

  static Future<http.Response> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final encodedBody = body != null ? jsonEncode(body) : null;
    return await http.put(uri, headers: headers, body: encodedBody);
  }

  static Future<http.Response> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    return await http.delete(uri, headers: headers);
  }
}
