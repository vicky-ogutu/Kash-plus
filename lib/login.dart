import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kash_plus/homepage2.dart';
import 'package:kash_plus/otp.dart';
import 'package:kash_plus/registration.dart';

import 'homepage.dart';
import 'package:http/http.dart' as http;


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool isObscured = true; // Store visibility state here

  Future<void> _login() async {
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter phone number and password")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("http://api.rovictech.co.ke/api/auth/login"), // Replace with your API URL
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Successful! Welcome, ${data['name']}")),
        );
        // Extracting values
        String token = data['token'];
        String loanAmount = data['loan_amount'];
        String repayableAmount = data['repayable_amount'];
        String status = data['status'];
        String? loanStatus = data['loan_status']; // Can be null
        // Navigate to next screen after successful login
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoanRequestScreen(
              token: token,
              loanAmount: loanAmount,
              repayableAmount: repayableAmount,
              status: status,
              loanStatus: loanStatus,
            ),
          ),
        );
        _phoneController.text ="";
        _passwordController.text="";
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
    SafeArea(
    child: SingleChildScrollView(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  //  RichText(
                  //   text: TextSpan(
                  //     children: [
                  //       TextSpan(
                  //         text: "S",
                  //         style: TextStyle(
                  //           fontSize: 30,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.blue[300], // S in blue
                  //         ),
                  //       ),
                  //       TextSpan(
                  //         text: "ure",
                  //         style: TextStyle(
                  //           fontSize: 24,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.white, // Rest in white
                  //         ),
                  //       ),
                  //       TextSpan(
                  //         text: "C",
                  //         style: TextStyle(
                  //           fontSize: 30,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.blue[300], // K in blue
                  //         ),
                  //       ),
                  //       TextSpan(
                  //         text: "ash",
                  //         style: TextStyle(
                  //           fontSize: 24,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.white, // Rest in white
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  Image.asset('assets/images/app_logo.png'),
                  const SizedBox(height: 15),
                  _buildTextField(Icons.phone, "phone number", _phoneController),
                  const SizedBox(height: 10),
                  _passwordTextField(Icons.lock, "password", _passwordController, obscureText: true),
                  const SizedBox(height: 20),
                  _buildLoginButton(),
                  const SizedBox(height: 10),
                  const Text("Forgot Password?", style: TextStyle(color: Colors.black)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Registration()));
                    },
                    child: const Text("Register", style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),
          ),
    ),),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      color: Colors.white,
      // decoration: const BoxDecoration(
      //   gradient: LinearGradient(
      //    // colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      //     colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //   ),
      // ),
    );
  }

  Widget _buildTextField(IconData icon, String hint, TextEditingController controller, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
         // borderSide: BorderSide.none,
          borderSide: const BorderSide(color: Colors.grey, width: 1.0), // visible border
        ),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity, // makes the button stretch to full width of parent
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[400],
          padding: const EdgeInsets.symmetric(vertical: 10), // removed horizontal padding
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _isLoading ? null : _login,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : const Text(
          "Login",
          style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }


  Widget _passwordTextField(
      IconData icon, String hint, TextEditingController controller,
      {bool obscureText = false}) {
    return StatefulBuilder(
      builder: (context, setState) {
       // bool isObscured = obscureText;

        return TextField(
          controller: controller,
          obscureText: isObscured,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black),
            prefixIcon: Icon(icon, color: Colors.black),
            suffixIcon: obscureText
                ? IconButton(
              icon: Icon(
                isObscured ? Icons.visibility_off : Icons.visibility,
                color: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  isObscured = !isObscured;

                });
              },
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              //borderSide: BorderSide.none,
              borderSide: const BorderSide(color: Colors.grey, width: 1.0), // visible border
            ),
          ),
          style: const TextStyle(color: Colors.black),
        );
      },
    );
  }

}