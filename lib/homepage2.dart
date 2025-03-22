import 'package:flutter/material.dart';

void main() {
  runApp(const LoanApp());
}

class LoanApp extends StatelessWidget {
  const LoanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoanRequestScreen(),
    );
  }
}

class LoanRequestScreen extends StatefulWidget {
  @override
  _LoanRequestScreenState createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  double _loanAmount = 1000; // Default loan amount
  double? currentLoan = 5000; // Example loan balance

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SureKash"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
         // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCurrentLoanCard(),
            const SizedBox(height: 10),
            Card(
              elevation: 4, // Adds shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Rounded corners
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Ensures the Card takes only necessary space
                  children: [
                    const Text(
                      "Ksh 30000",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 20),





                    const Text(
                      "Select Loan Amount",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Loan amount display
                    Text(
                      "Ksh ${_loanAmount.toInt()}",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 20),

                    // Horizontal Scrollable Loan Slider
                    Slider(
                      value: _loanAmount,
                      min: 1000,
                      max: 30000,
                      divisions: 29, // Each step is 1000
                      label: "Ksh ${_loanAmount.toInt()}",
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey[300],
                      onChanged: (value) {
                        setState(() {
                          _loanAmount = value;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // Request Loan Button
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
            )
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
            mainAxisSize: MainAxisSize.min, // Shrinks column to fit its children
            crossAxisAlignment: CrossAxisAlignment.center, // Centers horizontally
            children: [
              const Text(
                "Your Current Loan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center, // Centers text
              ),
              const SizedBox(height: 8),
              Text(
                currentLoan != null ? "Ksh ${currentLoan!.toStringAsFixed(2)}" : "No Active Loan",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                textAlign: TextAlign.center, // Centers text
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


  // 💳 Loan Payment Dialog
  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pay Loan"),
          content: const Text("You will be prompted to put your PIN!"),
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
