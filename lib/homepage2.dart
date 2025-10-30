import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'login.dart';

class LoanRequestScreen extends StatefulWidget {
  final String token;
  final String userID;
  final String loanAmount;
  final String repayableAmount;
  final String status;
  final String? loanStatus;
  final String userPhone;
  final String? loanId;
  final String? loanBalance;

  const LoanRequestScreen({
    Key? key,
    required this.token,
    required this.userID,
    required this.loanAmount,
    required this.repayableAmount,
    required this.status,
    this.loanStatus,
    required this.userPhone,
    this.loanId,
    this.loanBalance,
  }) : super(key: key);

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  double _selectedLoanAmount = 100;
  bool _isLoading = true; // Start with loading true to wait for initial data
  bool _hasPendingLoan = false;
  Map<String, dynamic>? _activeLoan;
  bool _waitingForPIN = false;
  Map<String, dynamic>? _assessmentData;
  Timer? _autoRefreshTimer;
  bool _initialDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    _checkInitialLoanStatus(); // Remove await since it's not async
    await _fetchCurrentLoanDetails();
    _startAutoRefresh();

    setState(() {
      _isLoading = false;
      _initialDataLoaded = true;
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (_waitingForPIN || _hasPendingLoan) {
        _fetchCurrentLoanDetails();
      }
    });
  }

  void _checkInitialLoanStatus() {
    // More comprehensive check for any active/pending loan status
    bool hasLoanAmount = widget.loanAmount.isNotEmpty &&
        widget.loanAmount != "0.00" &&
        widget.loanAmount != "0" &&
        widget.loanAmount != "0.0";

    bool isNotFullyRepaid = widget.status != "fully repaid" &&
        widget.status != "repaid" &&
        widget.status != "completed";

    bool hasValidLoanStatus = widget.status.isNotEmpty &&
        widget.status != "null" &&
        widget.status != "none";

    bool hasPendingLoan = hasLoanAmount && isNotFullyRepaid && hasValidLoanStatus;

    print("Initial loan check:");
    print("  Loan Amount: ${widget.loanAmount}");
    print("  Status: ${widget.status}");
    print("  Loan ID: ${widget.loanId}");
    print("  Has Loan Amount: $hasLoanAmount");
    print("  Is Not Fully Repaid: $isNotFullyRepaid");
    print("  Has Valid Status: $hasValidLoanStatus");
    print("  Has Pending Loan: $hasPendingLoan");

    setState(() {
      _hasPendingLoan = hasPendingLoan;

      if (_hasPendingLoan) {
        _activeLoan = {
          'id': widget.loanId,
          'loan_id': widget.loanId,
          'amount': widget.loanAmount,
          'repayable_amount': widget.repayableAmount,
          'status': widget.status,
          'balance': widget.loanBalance ?? widget.repayableAmount,
          'original_repayable': widget.repayableAmount,
        };
        print("Active loan set from initial data: $_activeLoan");
      }
    });
  }

  Future<void> _fetchCurrentLoanDetails() async {
    // If we don't have a loan ID but think we might have a loan, try to get user's loans
    if (widget.loanId == null || widget.loanId!.isEmpty) {
      await _fetchUserLoans();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("https://api.surekash.co.ke/api/loan/details/${widget.loanId}"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['loan'] != null) {
          setState(() {
            _activeLoan = data['loan'];
            _hasPendingLoan = _activeLoan?['status'] != 'fully repaid' &&
                _activeLoan?['status'] != 'repaid' &&
                _activeLoan?['status'] != 'completed' &&
                (_activeLoan?['balance'] != null &&
                    double.parse(_activeLoan?['balance']?.toString() ?? '0') > 0);
          });
          print("Updated loan details from API: $_activeLoan");
          print("Has pending loan: $_hasPendingLoan");
        }
      } else if (response.statusCode == 404) {
        // Loan not found, try to fetch user loans
        await _fetchUserLoans();
      }
    } catch (e) {
      print('Error fetching loan details: $e');
    }
  }

  Future<void> _fetchUserLoans() async {
    try {
      final response = await http.get(
        Uri.parse("https://api.surekash.co.ke/api/loan/user-loans"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['loans'] != null && data['loans'] is List && data['loans'].isNotEmpty) {
          // Find the most recent active/pending loan
          List<dynamic> loans = data['loans'];
          Map<String, dynamic>? activeLoan;

          for (var loan in loans) {
            String status = loan['status']?.toString().toLowerCase() ?? '';
            if (status != 'fully repaid' && status != 'repaid' && status != 'completed') {
              activeLoan = loan;
              break;
            }
          }

          if (activeLoan != null) {
            setState(() {
              _activeLoan = activeLoan;
              _hasPendingLoan = true;
            });
            print("Found active loan from user loans: $_activeLoan");
          }
        }
      }
    } catch (e) {
      print('Error fetching user loans: $e');
    }
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
    });

    await _fetchCurrentLoanDetails();

    if (!_hasPendingLoan) {
      setState(() {
        _assessmentData = null;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  double get _eligibleAmount => _assessmentData?['eligible_amount']?.toDouble() ?? 0.0;
  double get _interestRate => _assessmentData?['interest_rate']?.toDouble() ?? 0.0;

  double get _interestFee {
    return (_selectedLoanAmount * _interestRate / 100).ceilToDouble();
  }

  double get _totalRepayable {
    return (_selectedLoanAmount + _interestFee).ceilToDouble();
  }

  String get _repaymentDueDate => _assessmentData?['repayment_due_date'] ?? _calculateDueDate(90);
  int get _tenureDays => _assessmentData?['tenure_days'] ?? 90;
  int get _creditScore => _assessmentData?['credit_score'] ?? 0;
  String get _remarks => _assessmentData?['remarks'] ?? "No assessment data available";

  String _calculateDueDate(int tenureDays) {
    DateTime dueDate = DateTime.now().add(Duration(days: tenureDays));
    return "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";
  }

  double _calculateInterestAmount() {
    try {
      if (_activeLoan != null) {
        double principal = double.parse(_activeLoan!['amount']?.toString() ?? '0');
        double totalRepayable = double.parse(_activeLoan!['repayable_amount']?.toString() ?? '0');
        return totalRepayable - principal;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateInterestRate() {
    try {
      if (_activeLoan != null) {
        double principal = double.parse(_activeLoan!['amount']?.toString() ?? '0');
        double totalRepayable = double.parse(_activeLoan!['repayable_amount']?.toString() ?? '0');
        if (principal > 0) {
          double interest = totalRepayable - principal;
          double interestRate = (interest / principal) * 100;
          return interestRate;
        }
      }
      return _interestRate;
    } catch (e) {
      return _interestRate;
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }

  int _calculateDaysRemaining() {
    try {
      if (_activeLoan != null && _activeLoan!['due_date'] != null) {
        DateTime dueDate = DateTime.parse(_activeLoan!['due_date']);
        DateTime now = DateTime.now();
        return dueDate.difference(now).inDays;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  double _calculateAmountRepaid() {
    try {
      if (_activeLoan != null) {
        double totalRepayable = double.parse(_activeLoan!['repayable_amount']?.toString() ?? '0');
        double currentBalance = double.parse(_activeLoan!['balance']?.toString() ?? '0');
        return totalRepayable - currentBalance;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateRepaymentProgress() {
    try {
      if (_activeLoan != null) {
        double totalRepayable = double.parse(_activeLoan!['repayable_amount']?.toString() ?? '0');
        double amountRepaid = _calculateAmountRepaid();
        if (totalRepayable > 0) {
          return (amountRepaid / totalRepayable) * 100;
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Login()),
                    (route) => false,
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkEligibility() async {
    // FIRST check if there's an active/pending loan - if yes, show message and return immediately
    if (_hasPendingLoan) {
      _showPendingLoanMessage();
      return;
    }

    setState(() {
      _isLoading = true;
      _assessmentData = null;
    });

    try {
      final response = await http.get(
        Uri.parse("https://api.surekash.co.ke/api/loan/assessment"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['assessment'] != null) {
          setState(() {
            _assessmentData = data['assessment'];
            _selectedLoanAmount = _eligibleAmount;
          });

          _showAssessmentDialog(data);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Assessment completed but no data returned."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Assessment endpoint not found. Please try again later."),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? "Error checking eligibility: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPendingLoanMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.orange),
            SizedBox(width: 10),
            Text("Active Loan Found"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "You already have an active or pending loan.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            if (_activeLoan != null) ...[
              Text("Loan Amount: Ksh ${_activeLoan!['amount']?.toString() ?? '0'}"),
              const SizedBox(height: 5),
              Text("Status: ${_activeLoan!['status']?.toString().toUpperCase() ?? 'PENDING'}"),
              const SizedBox(height: 5),
              Text("Balance: Ksh ${_activeLoan!['balance']?.toString() ?? '0'}"),
              const SizedBox(height: 10),
            ],
            const Text(
              "Please repay your current loan before applying for a new one.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showAssessmentDialog(Map<String, dynamic> responseData) {
    if (_assessmentData == null || _eligibleAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No eligible loan amount available."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.assessment, color: Colors.green),
                SizedBox(width: 10),
                Text("Loan Assessment"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    responseData['message'] ?? "Loan eligibility assessment successful.",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  const Text("Select Loan Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Ksh ${_selectedLoanAmount.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 10),
                        Slider(
                          value: _selectedLoanAmount,
                          min: 100,
                          max: _eligibleAmount,
                          divisions: ((_eligibleAmount - 100) ~/ 100).clamp(1, 100).toInt(),
                          label: "Ksh ${_selectedLoanAmount.toStringAsFixed(0)}",
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedLoanAmount = value;
                            });
                          },
                          activeColor: Colors.blueAccent,
                          inactiveColor: Colors.grey,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Ksh 100", style: TextStyle(color: Colors.grey[600])),
                            Text("Ksh ${_eligibleAmount.toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  _buildAssessmentDetailRow("Selected Amount", "Ksh ${_selectedLoanAmount.toStringAsFixed(0)}"),
                  _buildAssessmentDetailRow("Interest Rate", "${_interestRate.toStringAsFixed(1)}%"),
                  _buildAssessmentDetailRow("Interest Fee", "Ksh ${_interestFee.toStringAsFixed(0)}"),
                  _buildAssessmentDetailRow("Total Repayable", "Ksh ${_totalRepayable.toStringAsFixed(0)}"),
                  _buildAssessmentDetailRow("Repayment Due", _formatDate(_repaymentDueDate)),
                  _buildAssessmentDetailRow("Tenure", "$_tenureDays days"),
                  _buildAssessmentDetailRow("Credit Score", _creditScore.toString()),
                  _buildAssessmentDetailRow("Remarks", _remarks),

                  const SizedBox(height: 10),
                  const Text(
                    "Do you want to proceed with this loan application?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: _selectedLoanAmount > 0 ? () {
                  Navigator.pop(context);
                  _applyForLoan();
                } : null,
                child: const Text("Apply Now"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAssessmentDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _applyForLoan() async {
    if (_assessmentData == null || _selectedLoanAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please check eligibility first and select a valid loan amount"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate repayable amount based on selected amount
      double interestFee = (_selectedLoanAmount * _interestRate / 100).ceilToDouble();
      double totalRepayable = (_selectedLoanAmount + interestFee).ceilToDouble();

      final response = await http.post(
        Uri.parse("https://api.surekash.co.ke/api/loan/apply"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "user_id": widget.userID,
          "amount": _selectedLoanAmount.toStringAsFixed(0),
          "repayable_amount": totalRepayable.toStringAsFixed(0),
          "tenure_days": _tenureDays,
          "repayment_due_date": _repaymentDueDate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Loan application submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Update state with new loan data
        setState(() {
          _hasPendingLoan = true;
          _activeLoan = data['loan_data'] ?? {
            'id': data['loan_id']?.toString(),
            'loan_id': data['loan_id']?.toString(),
            'amount': _selectedLoanAmount.toStringAsFixed(0),
            'repayable_amount': totalRepayable.toStringAsFixed(0),
            'status': 'pending',
            'balance': totalRepayable.toStringAsFixed(0),
            'due_date': _repaymentDueDate,
            'tenure_days': _tenureDays,
          };
        });

        // Clear assessment data since user now has an active loan
        _assessmentData = null;
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? "Failed to apply for loan: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initiateSTKPush() async {
    setState(() {
      _isLoading = true;
      _waitingForPIN = true;
    });

    try {
      final loanId = _activeLoan?['id']?.toString() ??
          _activeLoan?['loan_id']?.toString() ??
          widget.loanId?.toString();

      final amount = _activeLoan?['balance']?.toString() ?? '0';

      String formattedPhone = _formatPhoneForMPesa(widget.userPhone);

      if (loanId == null || loanId.isEmpty) {
        _handleSTKError('Loan ID is missing. Cannot process payment.');
        return;
      }

      if (amount == '0' || double.tryParse(amount) == null) {
        _handleSTKError('Invalid payment amount: $amount');
        return;
      }

      final parsedAmount = double.tryParse(amount)?.toInt() ?? 0;

      if (parsedAmount <= 0) {
        _handleSTKError('Payment amount must be greater than 0');
        return;
      }

      final response = await http.post(
        Uri.parse("https://api.surekash.co.ke/api/loan/repay"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "loan_id": int.tryParse(loanId) ?? 0,
          "amount": parsedAmount,
          "phone_number": formattedPhone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['message']?.toLowerCase() ?? '';
        final responseCode = data['ResponseCode']?.toString() ?? data['responseCode']?.toString();

        if (message.contains('success') ||
            message.contains('initiated') ||
            responseCode == '0' ||
            data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "STK Push sent successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          _showSTKSuccessDialog(data);

          // Start auto-refresh to check payment status
          _startPaymentStatusCheck();
        } else {
          _handleSTKError(data['message'] ?? data['error'] ?? 'Failed to initiate payment');
        }
      } else if (response.statusCode == 400) {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ??
              errorData['error'] ??
              'Bad request - check your input data';
          _handleSTKError('Payment failed: $errorMessage');
        } catch (e) {
          _handleSTKError('Payment failed: Invalid request format');
        }
      } else if (response.statusCode == 401) {
        _handleSTKError('Authentication failed. Please login again.');
      } else if (response.statusCode == 500) {
        _handleSTKError('Server error. Please try again later.');
      } else {
        _handleSTKError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _handleSTKError('Network error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startPaymentStatusCheck() {
    // Check payment status every 5 seconds for 2 minutes
    int checks = 0;
    Timer.periodic(Duration(seconds: 5), (timer) {
      checks++;
      _fetchCurrentLoanDetails();

      // Stop checking after 2 minutes (24 checks) or when payment is completed
      if (checks >= 24 || !_waitingForPIN || !_hasPendingLoan) {
        timer.cancel();
        setState(() {
          _waitingForPIN = false;
        });
      }
    });
  }

  String _formatPhoneForMPesa(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.startsWith('0')) {
      return '254${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('+254')) {
      return cleanPhone.substring(1);
    } else if (cleanPhone.startsWith('254')) {
      return cleanPhone;
    } else if (cleanPhone.length == 9) {
      return '254$cleanPhone';
    }

    return cleanPhone;
  }

  void _handleSTKError(String error) {
    setState(() {
      _waitingForPIN = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Payment Error: $error"),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSTKSuccessDialog(Map<String, dynamic> responseData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Colors.green),
            SizedBox(width: 10),
            Text("STK Push Sent"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              responseData['message'] ?? "STK Push initiated. Await customer PIN.",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            Text(
              "STK Push sent to ${widget.userPhone}. Check your phone and enter your M-Pesa PIN to complete the payment.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              "Payment status will update automatically...",
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _waitingForPIN = false;
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showRepaymentDialog() {
    double currentBalance = double.parse(_activeLoan?['balance']?.toString() ?? '0');
    double amountRepaid = _calculateAmountRepaid();
    double totalRepayable = double.parse(_activeLoan?['repayable_amount']?.toString() ?? '0');
    double progress = _calculateRepaymentProgress();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Repay Loan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (progress > 0) ...[
              Text("Repayment Progress: ${progress.toStringAsFixed(1)}%",
                  style: const TextStyle(fontSize: 14, color: Colors.green)),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey[300],
                color: Colors.green,
              ),
              const SizedBox(height: 10),
            ],

            Text("Outstanding Balance: Ksh ${currentBalance.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            if (amountRepaid > 0)
              Text("Amount Repaid: Ksh ${amountRepaid.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 14, color: Colors.green)),

            const SizedBox(height: 10),
            Text("Total Repayable: Ksh ${totalRepayable.toStringAsFixed(0)}"),
            const SizedBox(height: 10),
            Text("STK Push will be sent to: ${widget.userPhone}"),
            const SizedBox(height: 10),
            const Text("You will receive an STK push on your phone to complete the payment."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initiateSTKPush();
            },
            child: const Text("Send STK Push"),
          ),
        ],
      ),
    );
  }

  bool _shouldShowRepayButton() {
    final status = _activeLoan?['status']?.toString().toLowerCase() ?? '';
    final currentBalance = double.tryParse(_activeLoan?['balance']?.toString() ?? '0') ?? 0;

    final repayableStatuses = ['approved', 'disbursed', 'active', 'overdue', 'partially repaid'];

    return repayableStatuses.contains(status) &&
        !_waitingForPIN &&
        currentBalance > 0;
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'repaid':
      case 'fully repaid':
        return Icons.check_circle;
      case 'partially repaid':
        return Icons.payments;
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.thumb_up;
      case 'disbursed':
        return Icons.money;
      case 'active':
        return Icons.running_with_errors;
      case 'overdue':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'repaid':
      case 'fully repaid':
        return Colors.green;
      case 'partially repaid':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'disbursed':
        return Colors.lightBlue;
      case 'active':
        return Colors.blueAccent;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'repaid':
      case 'fully repaid':
        return "FULLY REPAID";
      case 'partially repaid':
        return "PARTIALLY REPAID";
      case 'pending':
        return "PENDING APPROVAL";
      case 'approved':
        return "APPROVED";
      case 'disbursed':
        return "DISBURSED";
      case 'active':
        return "ACTIVE LOAN";
      case 'overdue':
        return "OVERDUE";
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blueAccent, Colors.lightBlue],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.blueAccent, size: 30),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Welcome!",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  "Status: ${_hasPendingLoan ? 'Active Loan' : 'No Loan'}",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (_waitingForPIN) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Awaiting PIN",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
            title: const Text("Loan Balance"),
            trailing: Text(
              "Ksh ${_hasPendingLoan ? (_activeLoan?['balance']?.toString() ?? '0') : '0'}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.blueAccent),
            title: const Text("Phone Number"),
            trailing: Text(widget.userPhone, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.blueAccent),
            title: const Text("Refresh Data"),
            onTap: _refreshAllData,
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blueAccent),
            title: const Text("Loan History"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan History feature coming soon!")));
            },
          ),
          ListTile(
            leading: const Icon(Icons.help, color: Colors.blueAccent),
            title: const Text("Help & Support"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Help & Support feature coming soon!")));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildLoanRequestView() {
    // If there's a pending or active loan, show only the active loan view
    if (_hasPendingLoan) {
      return _buildActiveLoanView();
    }

    // Otherwise show normal eligibility UI
    bool hasEligibility = _assessmentData != null && _eligibleAmount > 0;

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Main eligibility card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                        hasEligibility ? Icons.verified_user : Icons.assessment,
                        size: 50,
                        color: hasEligibility ? Colors.green : Colors.blueAccent
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasEligibility ? "Loan Available" : "Check Eligibility",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: hasEligibility ? Colors.green : Colors.blueAccent
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasEligibility
                          ? "You're eligible for a loan up to Ksh ${_eligibleAmount.toInt()}"
                          : "Check your eligibility for a loan",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Check Eligibility Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text("Loan Eligibility", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasEligibility ? Colors.green.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: hasEligibility ? Colors.green : Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text("Maximum Eligible Amount", style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 5),
                          Text(
                            hasEligibility ? "Ksh ${_eligibleAmount.toInt()}" : "Check Now",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: hasEligibility ? Colors.green : Colors.blueAccent
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _checkEligibility,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Check Eligibility & Apply", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLoanView() {
    double interestAmount = _calculateInterestAmount();
    double interestRate = _calculateInterestRate();
    int daysRemaining = _calculateDaysRemaining();
    double amountRepaid = _calculateAmountRepaid();
    double progress = _calculateRepaymentProgress();

    final status = _activeLoan?['status']?.toString() ?? 'pending';
    final shouldShowRepayButton = _shouldShowRepayButton();
    final isFullyRepaid = status.toLowerCase() == 'repaid' || status.toLowerCase() == 'fully repaid';

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          size: 50,
                          color: _getStatusColor(status),
                        ),
                        if (_waitingForPIN)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _waitingForPIN ? "AWAITING M-PESA PIN" : _getStatusDisplayText(status),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _waitingForPIN ? Colors.orange : _getStatusColor(status),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    if (progress > 0 && progress < 100) ...[
                      const SizedBox(height: 15),
                      Text("Repayment Progress: ${progress.toStringAsFixed(1)}%",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey[300],
                        color: Colors.green,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text("Ksh ${amountRepaid.toStringAsFixed(0)} repaid of Ksh ${_activeLoan?['repayable_amount']?.toString() ?? '0'}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    if (_waitingForPIN) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "STK Push sent to ${widget.userPhone}. Check your phone and enter your M-Pesa PIN",
                          style: const TextStyle(color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Text(
                          "Data will update automatically when payment is confirmed...",
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    if (isFullyRepaid) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text(
                            "Loan fully repaid! You can apply for a new loan.",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],

                    if (status.toLowerCase() == 'pending') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Text(
                            "Your loan is pending approval. You can repay if needed.",
                            style: TextStyle(color: Colors.orange),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),

                    _buildLoanDetailRow("Loan Amount", "Ksh ${_activeLoan?['amount']?.toString() ?? '0'}"),

                    if (!isFullyRepaid)
                      _buildLoanDetailRow("Outstanding Balance", "Ksh ${_activeLoan?['balance']?.toString() ?? '0'}"),

                    if (amountRepaid > 0)
                      _buildLoanDetailRow("Amount Repaid", "Ksh ${amountRepaid.toStringAsFixed(0)}"),

                    _buildLoanDetailRow("Total Repayable", "Ksh ${_activeLoan?['repayable_amount']?.toString() ?? '0'}"),

                    _buildLoanDetailRow("Registered Phone", widget.userPhone),

                    if (_activeLoan?['due_date'] != null)
                      _buildLoanDetailRow("Due Date", _formatDate(_activeLoan!['due_date'])),

                    if (daysRemaining > 0 && !isFullyRepaid)
                      _buildLoanDetailRow("Days Remaining", "$daysRemaining days"),

                    if (_activeLoan?['tenure_days'] != null)
                      _buildLoanDetailRow("Loan Term", "${_activeLoan!['tenure_days']} days"),

                    if (_activeLoan?['transaction_id'] != null)
                      _buildLoanDetailRow("Transaction ID", _activeLoan!['transaction_id']),

                    if (_activeLoan?['id'] != null)
                      _buildLoanDetailRow("Loan ID", _activeLoan!['id'].toString()),

                    const SizedBox(height: 20),

                    if (shouldShowRepayButton)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading || _waitingForPIN ? null : _showRepaymentDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _waitingForPIN ? Colors.grey : Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : _waitingForPIN
                              ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Waiting for PIN...",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Repay Loan",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (isFullyRepaid)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _hasPendingLoan = false;
                              _activeLoan = null;
                              _assessmentData = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Apply for New Loan",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SureCash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
            tooltip: "Refresh Data",
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasPendingLoan ? _buildActiveLoanView() : _buildLoanRequestView(),
    );
  }
}