import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../errors/failures.dart';

/// Central HTTP API client connecting Flutter frontend to FastAPI backend on Render.
/// Automatically handles JWT Bearer token injection, multi-tenant headers, and response un-enveloping.
class ApiClient {
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'https://ledgify-bizy.onrender.com/api/v1';
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

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return decoded['data'];
        }
        return decoded;
      } catch (e) {
        return response.body;
      }
    } else {
      String errorMessage = 'Server error (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('error') && decoded['error'] is Map) {
            errorMessage = decoded['error']['message'] ?? errorMessage;
          } else if (decoded.containsKey('detail')) {
            errorMessage = decoded['detail'].toString();
          }
        }
      } catch (_) {}
      throw ServerFailure(message: errorMessage, statusCode: response.statusCode);
    }
  }

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  static Future<dynamic> post(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http.post(uri, headers: headers, body: encodedBody);
    return _handleResponse(response);
  }

  static Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http.put(uri, headers: headers, body: encodedBody);
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.delete(uri, headers: headers);
    return _handleResponse(response);
  }

  static Future<dynamic> postMultipart(
    String endpoint, {
    required Uint8List fileBytes,
    required String filename,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);

    request.headers['X-Business-Id'] = _activeBusinessId;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {}

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }
}
