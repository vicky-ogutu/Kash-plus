import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://api.surekash.co.ke/api';

  final String token;
  final String userId;

  ApiService(this.token, this.userId);

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _handleRequest(Future<http.Response> request) async {
    try {
      final response = await request.timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Request failed with status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please check your connection.');
    } on FormatException {
      throw Exception('Invalid response from server.');
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Assessment API - Now uses dynamic userId
  Future<Map<String, dynamic>> checkEligibility() async {
    return await _handleRequest(
      http.post(
        Uri.parse('$baseUrl/loan/assessment'),
        headers: _headers,
        body: jsonEncode({'userId': int.tryParse(userId) ?? 0}),
      ),
    );
  }

  // Apply for loan - Now uses dynamic userId
  Future<Map<String, dynamic>> applyForLoan(Map<String, dynamic> data) async {
    // Ensure userId is included in the request
    final requestData = Map<String, dynamic>.from(data);
    requestData['userId'] = int.tryParse(userId) ?? 0;

    return await _handleRequest(
      http.post(
        Uri.parse('$baseUrl/loan/apply'),
        headers: _headers,
        body: jsonEncode(requestData),
      ),
    );
  }

  // Repay loan - Now uses dynamic userId
  Future<Map<String, dynamic>> repayLoan(Map<String, dynamic> data) async {
    // Ensure userId is included in the request
    final requestData = Map<String, dynamic>.from(data);
    requestData['userId'] = int.tryParse(userId) ?? 0;

    return await _handleRequest(
      http.post(
        Uri.parse('$baseUrl/loan/repay'),
        headers: _headers,
        body: jsonEncode(requestData),
      ),
    );
  }
}