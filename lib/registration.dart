import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

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
  final FlutterContactPicker _contactPicker = FlutterContactPicker();

  Future<void> pickContact() async {
    try {
      final Contact? contact = await _contactPicker.selectContact();

      if (contact != null && contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        setState(() {
          contact_person_phone_noController.text = contact.phoneNumbers!.first;
        });
      }
    } catch (e) {
      print("Error picking contact: $e");
    }
  }


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
      { required String hint, required TextEditingController controller, bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black),
       // prefixIcon: Icon(icon, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          //borderSide: BorderSide.none,
          borderSide: const BorderSide(color: Colors.grey, width: 1.0), // visible border
        ),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
        width: double.infinity, // makes the button stretch to full width of parent
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: registerUser,
      child: const Text(
        "Register",
        style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
      ),),
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
                  //  RichText(
                  //   text: TextSpan(
                  //     children: [
                  //       TextSpan(
                  //         text: "C",
                  //         style: TextStyle(
                  //           fontSize: 30,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.blue[300], // S in blue
                  //         ),
                  //       ),
                  //       TextSpan(
                  //         text: "reate",
                  //         style: TextStyle(
                  //           fontSize: 24,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.black, // Rest in white
                  //         ),
                  //       ),
                  //       TextSpan(
                  //         text: "A",
                  //         style: TextStyle(
                  //           fontSize: 30,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.blue[300], // K in blue
                  //         ),
                  //       ),
                  //       TextSpan(
                  //         text: "ccount",
                  //         style: TextStyle(
                  //           fontSize: 24,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.black, // Rest in white
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  const Text(
                    "Create Account!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // First & Last Name in a Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          hint: "First name",
                          controller: firstNameController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          hint: "Last name",
                          controller: lastNameController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _buildTextField(hint: "Email", controller: emailController),
                  const SizedBox(height: 10),
                  _buildTextField(hint: "Phone", controller: phoneController),
                  const SizedBox(height: 10),
                  _buildTextField(hint: "ID number", controller: idNumberController),
                  const SizedBox(height: 10),
                  _buildTextField(hint: "Contact person name", controller: contact_person_nameController),
                  const SizedBox(height: 10),
                  _buildPhoneTextField(), // Contact number with picker
                  const SizedBox(height: 10),
                  _buildTextField( hint: "Password", controller: passwordController, obscureText: true),
                  const SizedBox(height: 20),
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


  Widget _buildPhoneTextField() {
    return GestureDetector(
      onTap: pickContact,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        height: 60,
        child: Text(
          contact_person_phone_noController.text.isEmpty
              ? "Contact number"
              : contact_person_phone_noController.text,
          style: TextStyle(
            color: contact_person_phone_noController.text.isEmpty
                ? Colors.black
                : Colors.black,
            fontSize: 16,
          ),
        ),
      ),
    );
  }


}
