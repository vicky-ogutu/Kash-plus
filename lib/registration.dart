import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'login.dart';
import 'otp.dart';

class registration extends StatelessWidget {
  const registration({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          Center(
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
                  Row(
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
                      const SizedBox(width: 8), // Space between text and icon
                      const Icon(
                        Icons.thumb_up,
                        color: Colors.white,
                        size: 36,
                      ),
                    ],
                  ).animate().fade(duration: 500.ms),
                  const SizedBox(height: 20),
                  _buildTextField(Icons.person, "First name"),
                  const SizedBox(height: 10),
                  _buildTextField(Icons.person, "Last name"),
                  const SizedBox(height: 10),
                  _buildTextField(Icons.email, "Email"),
                  const SizedBox(height: 10),
                  _buildTextField(Icons.phone, "Phone"),
                  const SizedBox(height: 10),
                  _buildTextField(Icons.numbers, "ID number"),
                  const SizedBox(height: 10),
                  _buildTextField(Icons.lock, "Password", obscureText: true),
                  const SizedBox(height: 10),
                  _buildLoginButton(context),
                  const SizedBox(height: 10),
                  TextButton(onPressed: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=>Login()));
                  }, child: const Text("Login", style: TextStyle(color: Colors.white70),),)
                ],
              ),
            ).animate().fadeIn(duration: 800.ms),
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



  Widget _buildTextField(IconData icon, String hint,
      {bool obscureText = false}) {
    return TextField(
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

  Widget _buildLoginButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context)=>const Otp()));
      },
      child: const Text(
        "Register",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ).animate().scale(delay: 300.ms);
  }
}
