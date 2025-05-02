import 'package:flutter/material.dart';

class LoanRequestScreen extends StatefulWidget {
  final String token;
  final String loanAmount;
  final String repayableAmount;
  final String status;
  final String? loanStatus;

  const LoanRequestScreen({
    super.key,
    required this.token,
    required this.loanAmount,
    required this.repayableAmount,
    required this.status,
    this.loanStatus,
  });

  @override
  _LoanRequestScreenState createState() => _LoanRequestScreenState();
}
class _LoanRequestScreenState extends State<LoanRequestScreen> {
  double _loanAmount = 1000; // Default loan amount

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Loan Details",
          style: TextStyle(color: Colors.white), // White text color
        ),
        backgroundColor: Colors.blueAccent,
       // iconTheme: const IconThemeData(color: Colors.white), // White back button/icon color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCurrentLoanCard(),
            const SizedBox(height: 10),


            _buildLoanDetailsCard(),
            const SizedBox(height: 10),
           // _buildLoanRequestCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLoanCard() {
    return SizedBox(
        width: double.infinity, // Ensures the card takes full screen width
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Your Current Loan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
             // "Ksh ${widget.loanAmount}",
              "Ksh ${widget.repayableAmount}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: widget.status == "pending" ? _showPaymentDialog : null,
              child: const Text("Pay Loan"),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLoanDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Loan Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildDetailRow("Amount Disbursed:", "Ksh ${widget.loanAmount}"),
           // _buildDetailRow("Loan Status:", widget.loanStatus ?? "Not Available"),
           // _buildDetailRow("Approval Status:", widget.status),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanRequestCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Select Loan Amount",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Ksh ${_loanAmount.toInt()}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 10),
            Slider(
              value: _loanAmount,
              min: 1000,
              max: 30000,
              divisions: 29,
              label: "Ksh ${_loanAmount.toInt()}",
              activeColor: Colors.blue,
              inactiveColor: Colors.grey[300],
              onChanged: (value) {
                setState(() {
                  _loanAmount = value;
                });
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Loan Request for Ksh ${_loanAmount.toInt()} submitted!")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text("Request Loan", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pay Loan"),
          content: const Text("You will be prompted to enter your Mpesa PIN!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Loan Paid Successfully!")),
                );
              },
              child: const Text("Pay"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.blueAccent))),
        ],
      ),
    );
  }
}
