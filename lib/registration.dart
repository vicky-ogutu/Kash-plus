import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'login.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FlutterContactPicker _contactPicker = FlutterContactPicker();

  bool _hidePassword = true; // Show/hide password toggle

  // ======================= REGISTER USER FUNCTION =======================
  Future<void> registerUser() async {
    const String apiUrl = "https://api.surekash.co.ke/api/auth/register";

    final Map<String, dynamic> data = {
      "first_name": firstNameController.text,
      "last_name": lastNameController.text,
      "email": emailController.text,
      "phone": phoneController.text,
      "password": passwordController.text,
      "national_id": idNumberController.text,
    };

    if (data.values.any((element) => element.isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Registration successful")));

        // Navigate to Login screen after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Login()),
          );
        });
      }
      else if (response.statusCode >= 400 && response.statusCode < 500) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: ${response.body}")));
      }
      else if (response.statusCode >= 500) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server error. Please try again later.')));
      }
      else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Unexpected error: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Network Error: $e")));
    }
  }

  // ======================= INPUT FIELD WITH ICONS + PASSWORD TOGGLE =======================
  Widget _input({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    IconData _getIcon() {
      switch (label.toLowerCase()) {
        case "first name":
        case "last name":
          return Icons.person_outline;
        case "email address":
          return Icons.email_outlined;
        case "phone number":
          return Icons.phone_android_outlined;
        case "national id":
          return Icons.badge_outlined;
        case "password":
          return Icons.lock_outline;
        default:
          return Icons.text_fields;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87),
            children: const [
              TextSpan(
                text: " *",
                style: TextStyle(color: Colors.red, fontSize: 15),
              )
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword ? _hidePassword : false,
          keyboardType: label.toLowerCase() == "phone number"
              ? TextInputType.phone
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: label.toLowerCase() == "phone number"
                ? "0700000000"
                : null,
            hintStyle: TextStyle(color: Colors.grey.shade500),

            prefixIcon: Icon(_getIcon(), color: Colors.grey.shade700),

            // Password toggle
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade700,
              ),
              onPressed: () {
                setState(() {
                  _hidePassword = !_hidePassword;
                });
              },
            )
                : null,

            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              const BorderSide(color: Color(0xFF005BE0), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ======================= UI =======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              // ---------------- LOGO + HEADER ----------------
              Column(
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
                  const Text(
                    "Fast • Secure • Reliable Loans",
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ---------------- FORM CARD ----------------
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Create Your Account",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF005BE0),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // FIRST + LAST NAME
                    Row(
                      children: [
                        Expanded(
                            child: _input(
                                label: "First Name",
                                controller: firstNameController)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _input(
                                label: "Last Name",
                                controller: lastNameController)),
                      ],
                    ),

                    const SizedBox(height: 14),
                    _input(
                        label: "Email Address", controller: emailController),

                    const SizedBox(height: 14),
                    _input(
                        label: "Phone Number", controller: phoneController),

                    const SizedBox(height: 14),
                    _input(
                        label: "National ID", controller: idNumberController),

                    const SizedBox(height: 14),
                    _input(
                        label: "Password",
                        controller: passwordController,
                        isPassword: true),

                    const SizedBox(height: 22),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005BE0),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ---------------- LOGIN REDIRECT ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account?",
                    style: TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Login()),
                      );
                    },
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Color(0xFF005BE0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

