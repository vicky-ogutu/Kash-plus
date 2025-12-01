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

      print('📊 API Response Status: ${response.statusCode}');
      print('📊 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } on FormatException {
          throw Exception('Invalid JSON response from server');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Request failed with status ${response.statusCode}');
        } catch (e) {
          throw Exception('Request failed with status ${response.statusCode}');
        }
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please check your connection.');
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Assessment API - GET request with userId as query parameter
  Future<Map<String, dynamic>> checkEligibility() async {
    final url = Uri.parse('$baseUrl/loan/assessment').replace(
      queryParameters: {'userId': userId},
    );

    print('🔍 Checking eligibility at URL: $url');
    print('🔍 Token: ${token.substring(0, 20)}...');
    print('🔍 User ID: $userId');

    return await _handleRequest(
      http.get(url, headers: _headers),
    );
  }

  // Apply for loan - POST request
  Future<Map<String, dynamic>> applyForLoan(Map<String, dynamic> data) async {
    // Ensure userId is included in the request
    final requestData = Map<String, dynamic>.from(data);
    requestData['userId'] = int.tryParse(userId) ?? 0;

    print('📤 Applying for loan with data: $requestData');

    return await _handleRequest(
      http.post(
        Uri.parse('$baseUrl/loan/apply'),
        headers: _headers,
        body: jsonEncode(requestData),
      ),
    );
  }

  // Repay loan - POST request
  Future<Map<String, dynamic>> repayLoan(Map<String, dynamic> data) async {
    // Ensure userId is included in the request
    final requestData = Map<String, dynamic>.from(data);
    requestData['userId'] = int.tryParse(userId) ?? 0;

    print('💰 Processing repayment with data: $requestData');

    return await _handleRequest(
      http.post(
        Uri.parse('$baseUrl/loan/repay'),
        headers: _headers,
        body: jsonEncode(requestData),
      ),
    );
  }
}