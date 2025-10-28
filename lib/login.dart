import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'homepage2.dart';
import 'registration.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Constants
  static const String _apiUrl = "https://api.surekash.co.ke/api/auth/login";
  static const String _appName = "SureCash";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildLoginForm(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(color: Colors.white);
  }

  Widget _buildLoginForm() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: _buildFormDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAppLogo(),
                const SizedBox(height: 15),
                _buildPhoneField(),
                const SizedBox(height: 10),
                _buildPasswordField(),
                const SizedBox(height: 20),
                _buildLoginButton(),
                const SizedBox(height: 10),
                _buildFooterActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildFormDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withOpacity(0.2),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    );
  }

  Widget _buildAppLogo() {
    return Image.asset('assets/images/app_logo.png');
  }

  Widget _buildPhoneField() {
    return _buildTextField(
      icon: Icons.phone,
      hint: "Phone number",
      controller: _phoneController,
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: "Password",
        hintStyle: const TextStyle(color: Colors.black),
        prefixIcon: const Icon(Icons.lock, color: Colors.black),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.black,
          ),
          onPressed: _togglePasswordVisibility,
        ),
        border: _buildInputBorder(),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: Colors.black),
        border: _buildInputBorder(),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }

  InputBorder _buildInputBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[400],
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : const Text(
          "Login",
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    return Column(
      children: [
        const Text(
          "Forgot Password?",
          style: TextStyle(color: Colors.black),
        ),
        TextButton(
          onPressed: _navigateToRegistration,
          child: const Text(
            "Register",
            style: TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _navigateToRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Registration()),
    );
  }

  Future<void> _handleLogin() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      await _performLogin();
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateInputs() {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showErrorSnackbar("Please enter phone number and password");
      return false;
    }

    return true;
  }

  Future<void> _performLogin() async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "phone": _phoneController.text.trim(),
        "password": _passwordController.text.trim(),
      }),
    );

    if (response.statusCode == 200) {
      await _handleLoginSuccess(response.body);
    } else {
      _handleLoginFailure(response.body);
    }
  }

  Future<void> _handleLoginSuccess(String responseBody) async {
    final data = jsonDecode(responseBody);

    _showSuccessSnackbar("Login Successful! Welcome, ${data['name'] ?? 'User'}");

    final userData = _extractUserData(data);

    await _navigateToHomePage(userData);

    _clearForm();
  }

  Map<String, dynamic> _extractUserData(Map<String, dynamic> data) {
    return {
      'token': data['token'],
      'userID': data['user_id']?.toString() ?? '',
      'loanAmount': data['loan_amount']?.toString() ?? "0.00",
      'repayableAmount': data['repayable_amount']?.toString() ?? "0.00",
      'status': data['status'] ?? "none",
      'loanStatus': data['loan_status'],
      'userPhone': data['phone'] ?? _phoneController.text.trim(),
      'loanId': data['loan_id']?.toString(),
      'loanBalance': data['loan_balance']?.toString(),
    };
  }

  Future<void> _navigateToHomePage(Map<String, dynamic> userData) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanRequestScreen(
          token: userData['token']!,
          userID: userData['userID']!,
          loanAmount: userData['loanAmount']!,
          repayableAmount: userData['repayableAmount']!,
          status: userData['status']!,
          loanStatus: userData['loanStatus'],
          userPhone: userData['userPhone']!,
        ),
      ),
    );
  }

  void _handleLoginFailure(String responseBody) {
    final errorMessage = _extractErrorMessage(responseBody);
    _showErrorSnackbar("Login Failed: $errorMessage");
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      return data['message'] ?? responseBody;
    } catch (e) {
      return responseBody;
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _phoneController.clear();
    _passwordController.clear();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}