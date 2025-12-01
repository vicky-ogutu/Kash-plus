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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const String _apiUrl = "https://api.surekash.co.ke/api/auth/login";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              _buildCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(26),
      width: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.07),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLogo(),
          const SizedBox(height: 18),
          _buildTitle(),
          const SizedBox(height: 30),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildPhoneField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _buildLoginButton(),
          const SizedBox(height: 20),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade100,
          ),
          child: ClipOval(
            child: Image.asset(
              "assets/images/app_logo.png",
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),

      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      children: const [
        Text(
          "Welcome!",
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Register/Login to continue",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: _inputDecoration(
        label: "0700000000",
        icon: Icons.phone,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Enter phone number";
        if (value.length < 10) return "Invalid phone number";
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: _inputDecoration(
        label: "Password",
        icon: Icons.lock,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: () => setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          }),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Enter password";
        if (value.length < 6) return "Password must be 6+ characters";
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      prefixIcon: Icon(icon, color: Color(0xFF005BE0)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF005BE0), width: 2),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF005BE0),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Text(
          "Login",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600, color: Colors.white
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        TextButton(
          onPressed: _showForgotPassword,
          child: const Text(
            "Forgot Password?",
            style: TextStyle(color: Color(0xFF005BE0)),
          ),
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Registration()),
            );
          },
          child: const Text.rich(
            TextSpan(
              text: "Don't have an account? ",
              style: TextStyle(color: Colors.black87),
              children: [
                TextSpan(
                  text: "Create Account",
                  style: TextStyle(
                      color: Color(0xFF005BE0),
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPassword() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Password"),
        content: const Text(
            "Please contact customer support to reset your password."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // LOGIN LOGIC =================================================================

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "phone": _phoneController.text.trim(),
            "password": _passwordController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          _onSuccess(response.body);
        } else {
          _onError(response.body);
        }
      } catch (e) {
        _onError(e.toString());
      }

      setState(() => _isLoading = false);
    }
  }

  void _onSuccess(String response) {
    final data = jsonDecode(response);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Login Successful"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoanRequestScreen(
          token: data['token'],
          userID: data['user_id'].toString(),
          loanAmount: data['loan_amount'].toString(),
          repayableAmount: data['repayable_amount'].toString(),
          status: data['status'],
          loanStatus: data['loan_status'],
          userPhone: data['phone'],
          loanId: data['loan_id'].toString(),
          loanBalance: data['loan_balance'].toString(),
        ),
      ),
    );
  }

  void _onError(String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Login failed: $body"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
