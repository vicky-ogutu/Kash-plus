import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kash_plus/registration.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage  extends StatefulWidget {
  const HomePage ({super.key});

  @override
  State<HomePage> createState() => _State();

}

class _State extends State<HomePage> {
  double? currentLoan = 5000; // Example loan balance
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sure kash"),
          backgroundColor: Colors.blueAccent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentLoanCard(),
            const SizedBox(height: 20),
           // _buildLoanRequestOptions(),
          ],
        ),
      ),
    );
  }

  // 🏦 Current Loan Card
  Widget _buildCurrentLoanCard() {
    return SizedBox(
        width: double.infinity, // Makes the card take full width
      child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Your Current Loan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              currentLoan != null ? "Ksh ${currentLoan!.toStringAsFixed(2)}" : "No Active Loan",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 10),
            currentLoan != null
                ? ElevatedButton(
              onPressed: () => _showPaymentDialog(),
              child: const Text("Pay Loan"),
            )
                : const SizedBox(),
          ],
        ),
      ),
    ),
    );
  }


  // 📅 Loan Request Buttons
  Widget _buildLoanRequestOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Request a Loan",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            _loanButton("1 Week", 7),
            _loanButton("21 Days", 21),
            _loanButton("30 Days", 30),
          ],
        ),
      ],
    );
  }

  // 🟢 Loan Request Button
  Widget _loanButton(String label, int days) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _showLoanDialog(days),
      child: Text(label),
    );
  }

  // 💰 Loan Request Dialog
  void _showLoanDialog(int days) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Request Loan"),
          content: Text("Are you sure you want to request a loan for $days days?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  currentLoan = 10000; // Simulating a new loan
                });
                Navigator.pop(context);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }


  // 💳 Loan Payment Dialog
  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pay Loan"),
          content: const Text("Are you sure you want to pay off your loan?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  currentLoan = null; // Loan paid off
                });
                Navigator.pop(context);
              },
              child: const Text("Pay"),
            ),
          ],
        );
      },
    );
  }
}
