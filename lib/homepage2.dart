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
  double _loanAmount = 1000;

  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit App"),
        content: const Text("Are you sure you want to exit the app?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Exit"),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
           // onPressed: () => Navigator.of(context).pop(),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/login'); // Adjust as needed
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Loan Details",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: "Logout",
              onPressed: _logout,
            )
          ],
          backgroundColor: Colors.blueAccent,
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.blueAccent),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/images/app_logo.png'),
                    ),
                    const SizedBox(height: 10),
                    const Text("Welcome!", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),

              ListTile(
                leading: const Icon(Icons.email),
                title: const Text("SureKash@gmail.com"),
                onTap: _logout,
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text("0745096781"),
                onTap: _logout,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Loan History"),
                onTap: () {
                  Navigator.pop(context);
                  // Implement navigation
                },
              ),
              const Divider(),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildCurrentLoanCard(),
              const SizedBox(height: 10),
              _buildLoanDetailsCard(),
              const SizedBox(height: 10),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      Text(
                        "Ksh ${_loanAmount.toInt()}",
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 20),
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
      ),
    );
  }

  Widget _buildCurrentLoanCard() {
    return SizedBox(
      width: double.infinity,
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
          ],
        ),
      ),
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
}

