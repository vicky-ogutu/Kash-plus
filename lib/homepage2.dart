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

class _LoanRequestScreenState extends State<LoanRequestScreen> with WidgetsBindingObserver {
  double _selectedLoanAmount = 100;
  bool _isLoading = true;
  bool _hasPendingLoan = false;
  Map<String, dynamic>? _activeLoan;
  bool _waitingForPIN = false;
  Map<String, dynamic>? _assessmentData;
  Timer? _autoRefreshTimer;
  String? _previousLoanStatus;
  int _refreshCounter = 0;
  bool _forceRefresh = false;
  bool _initialDataFetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print("🚀 INIT: Initial loan status from widget: '${widget.status}'");
    _previousLoanStatus = widget.status.toLowerCase();
    _loadInitialData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialDataFetched) {
      print("🔄 App resumed - refreshing data");
      _refreshAllData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _loadInitialData() async {
    print("📥 Loading initial data...");

    try {
      // First, check if we have active loan data from the widget (login response)
      await _checkInitialLoanStatusFromWidget();

      // Then fetch current details from API to ensure we have the latest data
      await _fetchCurrentLoanDetails();

      _startAutoRefresh();
    } catch (e) {
      print('❌ Error in initial data loading: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initialDataFetched = true;
        });
      }
    }

    print("✅ Initial data loaded. Has pending loan: $_hasPendingLoan");
  }

  Future<void> _checkInitialLoanStatusFromWidget() async {
    try {
      print("🔍 Checking initial loan status from widget data...");

      // Check if we have valid loan data from the login response
      bool hasValidLoanData = widget.loanId != null &&
          widget.loanId!.isNotEmpty &&
          widget.loanId != "null";

      bool hasLoanAmount = widget.loanAmount.isNotEmpty &&
          widget.loanAmount != "0.00" &&
          widget.loanAmount != "0" &&
          widget.loanAmount != "0.0" &&
          widget.loanAmount != "null";

      bool isNotFullyRepaid = widget.status != "fully repaid" &&
          widget.status != "repaid" &&
          widget.status != "completed" &&
          widget.status != "null";

      bool hasValidLoanStatus = widget.status.isNotEmpty &&
          widget.status != "null" &&
          widget.status != "none";

      bool hasPendingLoan = hasValidLoanData &&
          hasLoanAmount &&
          isNotFullyRepaid &&
          hasValidLoanStatus;

      print("📊 WIDGET DATA ANALYSIS:");
      print("  Has Valid Loan ID: $hasValidLoanData (${widget.loanId})");
      print("  Has Loan Amount: $hasLoanAmount (${widget.loanAmount})");
      print("  Is Not Fully Repaid: $isNotFullyRepaid (${widget.status})");
      print("  Has Valid Status: $hasValidLoanStatus");
      print("  Final Has Pending Loan: $hasPendingLoan");

      if (hasPendingLoan) {
        print("✅ Found active loan from widget data");
        if (mounted) {
          setState(() {
            _hasPendingLoan = true;
            _activeLoan = {
              'id': widget.loanId,
              'loan_id': widget.loanId,
              'amount': widget.loanAmount,
              'repayable_amount': widget.repayableAmount,
              'status': widget.status,
              'balance': widget.loanBalance ?? widget.repayableAmount,
            };
          });
        }
        print("📋 Active loan initialized from widget: $_activeLoan");
      } else {
        print("📭 No active loan found in widget data");
        if (mounted) {
          setState(() {
            _hasPendingLoan = false;
            _activeLoan = null;
          });
        }

        // Even if widget data doesn't show a loan, check with API to be sure
        print("🔍 Double-checking with API...");
        await _fetchUserLoans();
      }
    } catch (e) {
      print('❌ Error checking initial loan status: $e');
      // On error, still check with API
      await _fetchUserLoans();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _refreshCounter++;
      print("🔄 Auto-refresh #$_refreshCounter - Pending: $_hasPendingLoan, Waiting PIN: $_waitingForPIN");

      if (_hasPendingLoan || _waitingForPIN || _forceRefresh) {
        _fetchCurrentLoanDetails();
      }
    });
  }

  Future<void> _fetchCurrentLoanDetails() async {
    if (!mounted) return;

    final currentLoanId = _activeLoan?['id'] ?? _activeLoan?['loan_id'] ?? widget.loanId;

    if (currentLoanId == null || currentLoanId.toString().isEmpty || currentLoanId == "null") {
      print("📭 No valid loan ID available, fetching user loans");
      await _fetchUserLoans();
      return;
    }

    try {
      print("📡 Fetching loan details for ID: $currentLoanId");

      // Validate URL and parameters
      final url = "https://api.surekash.co.ke/api/loan/details/${currentLoanId.toString()}";
      print("🌐 URL: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      ).timeout(Duration(seconds: 30));

      print("📊 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ API Response received");

        if (data['loan'] != null) {
          final newLoanData = data['loan'];
          final newStatus = newLoanData['status']?.toString().toLowerCase() ?? 'unknown';
          final currentBalance = double.tryParse(newLoanData['balance']?.toString() ?? '0') ?? 0;
          final loanAmount = double.tryParse(newLoanData['amount']?.toString() ?? '0') ?? 0;

          print("\n🎯 STATUS UPDATE:");
          print("  Previous: $_previousLoanStatus");
          print("  New: $newStatus");
          print("  Balance: $currentBalance");
          print("  Amount: $loanAmount");

          bool statusChanged = _previousLoanStatus != newStatus;
          _previousLoanStatus = newStatus;

          // Check if loan is fully repaid
          bool isFullyRepaid = newStatus.contains('repaid') ||
              newStatus.contains('completed') ||
              currentBalance <= 0;

          // Check if loan is disbursed/active
          bool isDisbursed = newStatus.contains('disbursed') ||
              newStatus.contains('active') ||
              newStatus.contains('approved');

          print("  Fully Repaid: $isFullyRepaid");
          print("  Disbursed: $isDisbursed");
          print("  Status Changed: $statusChanged");

          if (mounted) {
            setState(() {
              _activeLoan = newLoanData;
              _hasPendingLoan = !isFullyRepaid;
              _forceRefresh = false;

              if (isFullyRepaid) {
                _assessmentData = null;
                _waitingForPIN = false;
                if (statusChanged) {
                  _showLoanRepaidSuccess();
                }
              } else if (statusChanged && isDisbursed) {
                _showLoanDisbursedNotification();
              }
            });
          }

          print("  Updated _hasPendingLoan: $_hasPendingLoan");
        } else {
          print("❌ No loan data in response");
          await _fetchUserLoans();
        }
      } else {
        print("❌ API Error: ${response.statusCode}");
        print("❌ Response body: ${response.body}");
        await _fetchUserLoans();
      }
    } catch (e) {
      print('❌ Error fetching loan details: $e');
      if (e is TimeoutException) {
        print('⏰ Request timed out');
      }
    }
  }

  void _showLoanRepaidSuccess() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "🎉 Loan fully repaid! You can now apply for a new loan.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _showLoanDisbursedNotification() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "✅ Loan disbursed! You can now repay your loan.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _fetchUserLoans() async {
    try {
      print("👥 Fetching all user loans from API...");

      final url = "https://api.surekash.co.ke/api/loan/user-loans";
      print("🌐 URL: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      ).timeout(Duration(seconds: 30));

      print("📊 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("📊 User loans API response received");

        if (data['loans'] != null && data['loans'] is List) {
          List<dynamic> loans = data['loans'];
          print("📋 Found ${loans.length} loans for user");

          Map<String, dynamic>? activeLoan;

          for (var loan in loans) {
            String status = loan['status']?.toString().toLowerCase() ?? '';
            double balance = double.tryParse(loan['balance']?.toString() ?? '0') ?? 0;
            double amount = double.tryParse(loan['amount']?.toString() ?? '0') ?? 0;

            print("  📄 Loan: Status='$status', Balance=$balance, Amount=$amount");

            bool isActiveLoan = (status != 'fully repaid' &&
                status != 'repaid' &&
                status != 'completed' &&
                balance > 0) ||
                (amount > 0 && status != 'fully repaid' && status != 'repaid' && status != 'completed');

            if (isActiveLoan) {
              activeLoan = loan;
              print("  ✅ Found active loan: ${loan['status']}");
              break;
            }
          }

          if (activeLoan != null) {
            final status = activeLoan['status']?.toString().toLowerCase() ?? '';
            print("🎯 Setting active loan from user loans API");
            if (mounted) {
              setState(() {
                _activeLoan = activeLoan;
                _hasPendingLoan = true;
                _previousLoanStatus = status;
              });
            }
          } else {
            print("  📭 No active loans found in user loans API");
            if (mounted) {
              setState(() {
                _hasPendingLoan = false;
                _activeLoan = null;
                _waitingForPIN = false;
              });
            }
          }
        } else {
          print("  📭 No loans array found in API response");
          if (mounted) {
            setState(() {
              _hasPendingLoan = false;
              _activeLoan = null;
              _waitingForPIN = false;
            });
          }
        }
      } else {
        print("❌ User loans API error: ${response.statusCode}");
        print("❌ Response body: ${response.body}");
        if (mounted) {
          setState(() {
            _hasPendingLoan = false;
            _activeLoan = null;
            _waitingForPIN = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching user loans: $e');
      if (e is TimeoutException) {
        print('⏰ Request timed out');
      }
      if (mounted) {
        setState(() {
          _hasPendingLoan = false;
          _activeLoan = null;
          _waitingForPIN = false;
        });
      }
    }
  }

  Future<void> _refreshAllData() async {
    print("🔃 Manual refresh triggered");
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _forceRefresh = true;
    });

    await _fetchCurrentLoanDetails();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Enhanced eligibility check blocking
  bool _shouldBlockEligibilityCheck() {
    if (!_hasPendingLoan) return false;

    final status = _activeLoan?['status']?.toString().toLowerCase() ?? '';
    final currentBalance = double.tryParse(_activeLoan?['balance']?.toString() ?? '0') ?? 0;
    final loanAmount = double.tryParse(_activeLoan?['amount']?.toString() ?? '0') ?? 0;

    print("🔒 ELIGIBILITY CHECK BLOCK ANALYSIS:");
    print("  Has Pending Loan: $_hasPendingLoan");
    print("  Loan Status: $status");
    print("  Current Balance: $currentBalance");
    print("  Loan Amount: $loanAmount");

    // Block eligibility check if:
    // 1. User has existing loan to be repaid (balance > 0)
    // 2. User has applied and waiting for disbursement (status is pending/approved)
    bool shouldBlock = currentBalance > 0 ||
        status.contains('pending') ||
        status.contains('approved') ||
        status.contains('processing') ||
        (loanAmount > 0 && !status.contains('repaid') && !status.contains('completed'));

    print("  Should Block Eligibility Check: $shouldBlock");

    return shouldBlock;
  }

  // Safe getters with null checks and validation
  double get _eligibleAmount {
    try {
      double amount = _assessmentData?['eligible_amount']?.toDouble() ?? 0.0;
      return amount >= 0 ? amount : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double get _interestRate {
    try {
      double rate = _assessmentData?['interest_rate']?.toDouble() ?? 0.0;
      return rate >= 0 ? rate : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double get _interestFee {
    try {
      if (_selectedLoanAmount <= 0 || _interestRate <= 0) return 0.0;
      return (_selectedLoanAmount * _interestRate / 100).ceilToDouble();
    } catch (e) {
      return 0.0;
    }
  }

  double get _totalRepayable {
    try {
      if (_selectedLoanAmount <= 0) return 0.0;
      return (_selectedLoanAmount + _interestFee).ceilToDouble();
    } catch (e) {
      return 0.0;
    }
  }

  String get _repaymentDueDate {
    try {
      return _assessmentData?['repayment_due_date'] ?? _calculateDueDate(90);
    } catch (e) {
      return _calculateDueDate(90);
    }
  }

  int get _tenureDays {
    try {
      return _assessmentData?['tenure_days'] ?? 90;
    } catch (e) {
      return 90;
    }
  }

  int get _creditScore {
    try {
      return _assessmentData?['credit_score'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  String get _remarks {
    try {
      return _assessmentData?['remarks'] ?? "No assessment data available";
    } catch (e) {
      return "No assessment data available";
    }
  }

  String _calculateDueDate(int tenureDays) {
    try {
      DateTime dueDate = DateTime.now().add(Duration(days: tenureDays));
      return "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";
    } catch (e) {
      // Fallback to 90 days from now
      DateTime dueDate = DateTime.now().add(Duration(days: 90));
      return "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";
    }
  }

  double _calculateInterestAmount() {
    try {
      if (_activeLoan != null) {
        double principal = double.tryParse(_activeLoan!['amount']?.toString() ?? '0') ?? 0;
        double totalRepayable = double.tryParse(_activeLoan!['repayable_amount']?.toString() ?? '0') ?? 0;
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
        double principal = double.tryParse(_activeLoan!['amount']?.toString() ?? '0') ?? 0;
        double totalRepayable = double.tryParse(_activeLoan!['repayable_amount']?.toString() ?? '0') ?? 0;
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
      if (dateString.isEmpty) return "N/A";
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
        double totalRepayable = double.tryParse(_activeLoan!['repayable_amount']?.toString() ?? '0') ?? 0;
        double currentBalance = double.tryParse(_activeLoan!['balance']?.toString() ?? '0') ?? 0;
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
        double totalRepayable = double.tryParse(_activeLoan!['repayable_amount']?.toString() ?? '0') ?? 0;
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
    // Enhanced check for existing loans and pending applications
    if (_shouldBlockEligibilityCheck()) {
      _showPendingLoanMessage();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _assessmentData = null;
      });
    }

    try {
      final url = "https://api.surekash.co.ke/api/loan/assessment";
      print("🌐 Checking eligibility: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
      ).timeout(Duration(seconds: 30));

      print("📊 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['assessment'] != null && mounted) {
          // Validate assessment data before using it
          final assessment = data['assessment'];
          final eligibleAmount = assessment['eligible_amount']?.toDouble() ?? 0.0;

          if (eligibleAmount > 0) {
            setState(() {
              _assessmentData = assessment;
              _selectedLoanAmount = eligibleAmount.clamp(100.0, eligibleAmount);
            });
            _showAssessmentDialog(data);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("You are not eligible for a loan at this time."),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? "Assessment completed but no data returned."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Assessment endpoint not found. Please try again later."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? "Error checking eligibility: ${response.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Network error in eligibility check: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPendingLoanMessage() {
    final status = _activeLoan?['status']?.toString().toUpperCase() ?? 'PENDING';
    final currentBalance = double.tryParse(_activeLoan?['balance']?.toString() ?? '0') ?? 0;
    final loanAmount = double.tryParse(_activeLoan?['amount']?.toString() ?? '0') ?? 0;

    String message = "";
    String title = "Active Loan Found";

    if (currentBalance > 0) {
      message = "You have an existing loan with an outstanding balance of Ksh $currentBalance.";
      title = "Existing Loan Balance";
    } else if (status.contains('PENDING') || status.contains('APPROVED')) {
      message = "You have a loan application that is waiting for disbursement.";
      title = "Loan Application in Progress";
    } else {
      message = "You already have an active or pending loan.";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.orange),
            SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(fontSize: 16)),
            SizedBox(height: 15),
            if (_activeLoan != null) ...[
              Text("Loan Amount: Ksh ${_activeLoan!['amount']?.toString() ?? '0'}"),
              SizedBox(height: 5),
              Text("Status: ${_activeLoan!['status']?.toString().toUpperCase() ?? 'PENDING'}"),
              SizedBox(height: 5),
              if (currentBalance > 0)
                Text("Outstanding Balance: Ksh ${_activeLoan!['balance']?.toString() ?? '0'}"),
              SizedBox(height: 10),
            ],
            Text(
              "Please complete your current loan process before applying for a new one.",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("UNDERSTOOD"),
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

    // Ensure _selectedLoanAmount is within valid range
    if (_selectedLoanAmount > _eligibleAmount) {
      _selectedLoanAmount = _eligibleAmount;
    }
    if (_selectedLoanAmount < 100) {
      _selectedLoanAmount = 100;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Add safety check for slider values
          final double minAmount = 100.0;
          final double maxAmount = _eligibleAmount;
          final bool canShowSlider = maxAmount >= minAmount;

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

                        if (canShowSlider)
                          Slider(
                            value: _selectedLoanAmount,
                            min: minAmount,
                            max: maxAmount,
                            divisions: ((maxAmount - minAmount) ~/ 100).clamp(1, 100).toInt(),
                            label: "Ksh ${_selectedLoanAmount.toStringAsFixed(0)}",
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedLoanAmount = value;
                              });
                            },
                            activeColor: Colors.blueAccent,
                            inactiveColor: Colors.grey,
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Eligible amount is too low for selection",
                              style: TextStyle(color: Colors.orange),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Ksh ${minAmount.toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[600])),
                            Text("Ksh ${maxAmount.toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[600])),
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
                onPressed: _selectedLoanAmount >= 100 ? () {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please check eligibility first and select a valid loan amount"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      double interestFee = (_selectedLoanAmount * _interestRate / 100).ceilToDouble();
      double totalRepayable = (_selectedLoanAmount + interestFee).ceilToDouble();

      final requestBody = {
        "user_id": widget.userID,
        "amount": _selectedLoanAmount.toStringAsFixed(0),
        "repayable_amount": totalRepayable.toStringAsFixed(0),
        "tenure_days": _tenureDays,
        "repayment_due_date": _repaymentDueDate,
      };

      print("📤 Applying for loan with data: $requestBody");

      final response = await http.post(
        Uri.parse("https://api.surekash.co.ke/api/loan/apply"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));

      print("📊 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Loan application submitted successfully!"),
              backgroundColor: Colors.green,
            ),
          );

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
            _previousLoanStatus = 'pending';
            _forceRefresh = true;
          });

          _assessmentData = null;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Loan application submitted! Waiting for approval...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        print("❌ Loan application error: ${errorData['message']}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['message'] ?? "Failed to apply for loan: ${response.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error applying for loan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initiateSTKPush() async {
    if (!mounted) return;

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

      final requestBody = {
        "loan_id": int.tryParse(loanId) ?? 0,
        "amount": parsedAmount,
        "phone_number": formattedPhone,
      };

      print("📤 STK Push request: $requestBody");

      final response = await http.post(
        Uri.parse("https://api.surekash.co.ke/api/loan/repay"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));

      print("📊 STK Push response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['message']?.toLowerCase() ?? '';
        final responseCode = data['ResponseCode']?.toString() ?? data['responseCode']?.toString();

        if (message.contains('success') ||
            message.contains('initiated') ||
            responseCode == '0' ||
            data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? "STK Push sent successfully!"),
                backgroundColor: Colors.green,
              ),
            );
            _showSTKSuccessDialog(data);

            _startPaymentStatusCheck();
          }
        } else {
          _handleSTKError(data['message'] ?? data['error'] ?? 'Failed to initiate payment');
        }
      } else {
        print("❌ STK Push error response: ${response.body}");
        _handleSTKError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ STK Push network error: $e');
      _handleSTKError('Network error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSTKError(String error) {
    if (!mounted) return;

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

  void _startPaymentStatusCheck() {
    int checks = 0;
    Timer.periodic(Duration(seconds: 5), (timer) {
      checks++;
      _fetchCurrentLoanDetails();

      if (checks >= 24 || !mounted) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _waitingForPIN = false;
          });
        }
      }
    });
  }

  String _formatPhoneForMPesa(String phone) {
    try {
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
    } catch (e) {
      return phone;
    }
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _waitingForPIN = false;
                });
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ... (Keep all the UI building methods exactly the same as in the previous complete code)
  // The UI methods remain unchanged from the previous complete code

  Widget _buildLoanRequestView() {
    bool hasEligibility = _assessmentData != null && _eligibleAmount > 0;
    bool isBlocked = _shouldBlockEligibilityCheck();

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
                    Icon(
                        isBlocked ? Icons.block :
                        hasEligibility ? Icons.verified_user : Icons.assessment,
                        size: 50,
                        color: isBlocked ? Colors.orange :
                        hasEligibility ? Colors.green : Colors.blueAccent
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isBlocked ? "Application in Progress" :
                      hasEligibility ? "Loan Available" : "Check Eligibility",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isBlocked ? Colors.orange :
                          hasEligibility ? Colors.green : Colors.blueAccent
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isBlocked
                          ? "Complete your current loan process to apply for a new one"
                          : hasEligibility
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
                        color: isBlocked ? Colors.grey.withOpacity(0.1) :
                        hasEligibility ? Colors.green.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isBlocked ? Colors.grey :
                        hasEligibility ? Colors.green : Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text("Maximum Eligible Amount", style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 5),
                          Text(
                            isBlocked ? "Not Available" :
                            hasEligibility ? "Ksh ${_eligibleAmount.toInt()}" : "Check Now",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isBlocked ? Colors.grey :
                                hasEligibility ? Colors.green : Colors.blueAccent
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isBlocked ? null : (_isLoading ? null : _checkEligibility),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBlocked ? Colors.grey : Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : isBlocked
                            ? const Text("Application in Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
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

  Widget _buildStatusBasedView() {
    final status = _activeLoan?['status']?.toString().toLowerCase() ?? 'pending';
    final currentBalance = double.tryParse(_activeLoan?['balance']?.toString() ?? '0') ?? 0;

    if (currentBalance <= 0 && _hasPendingLoan) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _hasPendingLoan = false;
            _waitingForPIN = false;
            _assessmentData = null;
          });
        }
      });
    }

    switch (status) {
      case 'pending':
      case 'approved':
        return _buildPendingLoanView();
      case 'disbursed':
      case 'active':
      case 'overdue':
      case 'partially repaid':
        return _buildRepayLoanView();
      case 'repaid':
      case 'fully repaid':
      case 'completed':
        return _buildFullyRepaidView();
      default:
        return _buildPendingLoanView();
    }
  }

  Widget _buildPendingLoanView() {
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
                    const Icon(Icons.pending_actions, size: 60, color: Colors.orange),
                    const SizedBox(height: 15),
                    const Text(
                      "Loan Pending Approval",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Ksh ${_activeLoan?['amount']?.toString() ?? '0'}",
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        _activeLoan?['status']?.toString().toUpperCase() ?? 'PENDING',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _getStatusDescription(_activeLoan?['status'] ?? 'pending'),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildLoanDetailCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepayLoanView() {
    double amountRepaid = _calculateAmountRepaid();
    double progress = _calculateRepaymentProgress();
    final status = _activeLoan?['status']?.toString() ?? 'active';
    final shouldShowRepayButton = _shouldShowRepayButton();

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

                    Text(
                      _waitingForPIN ? "AWAITING M-PESA PIN" : _getStatusDisplayText(status),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _waitingForPIN ? Colors.orange : _getStatusColor(status),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),
                    Text(
                      _getStatusDescription(status),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
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
                    ],

                    if (_waitingForPIN) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          "STK Push sent to ${widget.userPhone}. Check your phone and enter your M-Pesa PIN",
                          style: const TextStyle(color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    _buildLoanDetailCard(),

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
                                "Repay Loan Now",
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

  Widget _buildFullyRepaidView() {
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
                    const Icon(Icons.check_circle, size: 60, color: Colors.green),
                    const SizedBox(height: 15),
                    const Text(
                      "Loan Fully Repaid!",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Ksh ${_activeLoan?['amount']?.toString() ?? '0'}",
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        "FULLY REPAID",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Congratulations! You have successfully repaid your loan.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildLoanDetailCard(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _hasPendingLoan = false;
                              _activeLoan = null;
                              _assessmentData = null;
                              _waitingForPIN = false;
                            });
                          }
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

  Widget _buildLoanDetailCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Loan Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildLoanDetailRow("Loan Amount", "Ksh ${_activeLoan?['amount']?.toString() ?? '0'}"),
            _buildLoanDetailRow("Outstanding Balance", "Ksh ${_activeLoan?['balance']?.toString() ?? '0'}"),
            _buildLoanDetailRow("Total Repayable", "Ksh ${_activeLoan?['repayable_amount']?.toString() ?? '0'}"),
            if (_activeLoan?['due_date'] != null)
              _buildLoanDetailRow("Due Date", _formatDate(_activeLoan!['due_date'])),
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

  void _showRepaymentDialog() {
    double currentBalance = double.tryParse(_activeLoan?['balance']?.toString() ?? '0') ?? 0;
    double amountRepaid = _calculateAmountRepaid();
    double totalRepayable = double.tryParse(_activeLoan?['repayable_amount']?.toString() ?? '0') ?? 0;
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

    if (_waitingForPIN || currentBalance <= 0) {
      return false;
    }

    final repayableStatuses = ['approved', 'disbursed', 'active', 'overdue', 'partially repaid'];
    return repayableStatuses.contains(status);
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

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'repaid':
      case 'fully repaid':
        return "Your loan has been fully repaid. You can apply for a new loan anytime.";
      case 'partially repaid':
        return "You have partially repaid your loan. Continue with payments to clear the remaining balance.";
      case 'pending':
        return "Your loan application is being processed. You'll be notified once it's approved.";
      case 'approved':
        return "Your loan has been approved! The funds will be disbursed to your account shortly.";
      case 'disbursed':
        return "Loan amount has been disbursed to your account. You can now start repaying.";
      case 'active':
        return "Your loan is active. Make sure to repay on time to avoid penalties.";
      case 'overdue':
        return "Your loan repayment is overdue. Please repay immediately to avoid additional charges.";
      default:
        return "Your loan application is being processed.";
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
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("🏗️ BUILD: Has pending loan: $_hasPendingLoan, Loading: $_isLoading");
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
          : _hasPendingLoan ? _buildStatusBasedView() : _buildLoanRequestView(),
    );
  }
}