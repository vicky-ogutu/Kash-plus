import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'login.dart';
import 'otp.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  _RegistrationState createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController contact_person_nameController = TextEditingController();
  final TextEditingController contact_person_phone_noController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> registerUser() async {
    const String apiUrl = "http://api.rovictech.co.ke/api/auth/register"; // Replace with your endpoint

    final Map<String, dynamic> requestData = {
      "first_name": firstNameController.text,
      "last_name": lastNameController.text,
      "email": emailController.text,
      "phone": phoneController.text,
      "id_number": idNumberController.text,
      "password": passwordController.text,
      "contact_person_name":contact_person_nameController.text,
      "contact_person_phone_no": contact_person_phone_noController.text
    };

    if (firstNameController.text.isEmpty || lastNameController.text.isEmpty||
    emailController.text.isEmpty || phoneController.text.isEmpty || idNumberController.text.isEmpty
    || passwordController.text.isEmpty || contact_person_nameController.text.isEmpty || contact_person_phone_noController.text.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all the details")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        // Successful registration
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration successful")),
        );
        Navigator.push(context, MaterialPageRoute(builder: (context)=>Login()));
      } else {
        // Failed registration
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}")),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $error")),
      );
    }
  }

  Widget _buildTextField(
      {required IconData icon, required String hint, required TextEditingController controller, bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: registerUser,
      child: const Text(
        "Register",
        style: TextStyle(fontSize: 24, color: Colors.white70, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Create Account!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(icon: Icons.person, hint: "First name", controller: firstNameController),
                  const SizedBox(height: 10),
                  _buildTextField(icon: Icons.person, hint: "Last name", controller: lastNameController),
                  const SizedBox(height: 10),
                  _buildTextField(icon: Icons.email, hint: "Email", controller: emailController),
                  const SizedBox(height: 10),
                  _buildTextField(icon: Icons.phone, hint: "Phone", controller: phoneController),
                  const SizedBox(height: 10),
                  _buildTextField(icon: Icons.numbers, hint: "ID number", controller: idNumberController),
                  const SizedBox(height: 10),
                  _buildTextField(icon: Icons.person, hint: "Contact person name", controller: contact_person_nameController),
                  const SizedBox(height: 10),
                  _buildTextField(icon: Icons.phone, hint: "Contact person number", controller: contact_person_phone_noController),
                  const SizedBox(height: 10),
                  _buildTextField(icon: Icons.lock, hint: "Password", controller: passwordController, obscureText: true),
                  const SizedBox(height: 10),
                  _buildRegisterButton(),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
