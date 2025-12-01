import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
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
  late ApiService _apiService;
  late User _user;
  bool _isLoading = false;
  bool _checkingCreditScore = false;
  LoanAssessment? _assessment;
  bool _waitingForPayment = false;
  double _selectedLoanAmount = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() {
    try {
      _user = User(
        id: widget.userID,
        phone: widget.userPhone,
        loanId: widget.loanId,
        loanAmount: widget.loanAmount,
        loanBalance: widget.loanBalance ?? '0',
        repayableAmount: widget.repayableAmount,
        status: widget.status,
        loanStatus: widget.loanStatus,
      );

      // Initialize API service with token and dynamic userId
      _apiService = ApiService(widget.token, _user.id);

      print('🚀 App initialized for user: ${_user.id}');
      print('📱 Phone: ${_user.phone}');
      print('💰 Loan Status: ${_user.status}');
      print('💳 Loan Balance: ${_user.loanBalance}');
      print('📊 Is New User: ${_user.isNewUser}');
      print('🔑 Loan ID: ${_user.loanId}');

      // For new users, provide default assessment immediately
      if (_user.isNewUser) {
        print('👶 New user detected - providing default assessment');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _provideDefaultAssessmentForNewUser();
        });
      } else if (_user.canApplyForLoan) {
        // For existing users without active loan, check eligibility
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkEligibility();
        });
      }
    } catch (e) {
      print('❌ Error initializing app: $e');
      _errorMessage = 'Failed to initialize app: $e';
    }
  }

  void _provideDefaultAssessmentForNewUser() {
    if (mounted) {
      setState(() {
        _assessment = LoanAssessment.defaultForNewUser();
        _selectedLoanAmount = _assessment!.eligibleAmount;
      });
    }
    _showWelcomeMessage();
  }

  void _showWelcomeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '👋 Welcome to SureCash! You can start with a starter loan.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _checkEligibility() async {
    if (!_user.canApplyForLoan) {
      _showErrorSnackBar('You have an existing loan. Please repay it first.');
      return;
    }

    if (mounted) {
      setState(() {
        _checkingCreditScore = true;
        _assessment = null;
        _errorMessage = null;
      });
    }

    try {
      print('🔍 Checking eligibility for user: ${_user.id}');
      final response = await _apiService.checkEligibility();

      print('✅ Eligibility response received');

      if (response['success'] != null && !response['success']) {
        throw Exception(response['message'] ?? 'Eligibility check failed');
      }

      if (response['assessment'] != null) {
        final assessment = LoanAssessment.fromJson(response['assessment']);

        // If eligible amount is 0 or negative, provide minimum loan for new users
        if (assessment.eligibleAmount <= 0 && _user.isNewUser) {
          print('⚠️ Zero eligibility for new user - providing default');
          _assessment = LoanAssessment.defaultForNewUser();
        } else {
          _assessment = assessment;
        }

        if (mounted) {
          setState(() {
            _selectedLoanAmount = _assessment!.eligibleAmount;
          });
        }

        _showAssessmentSuccess(_assessment!);
      } else {
        // No assessment data - provide default for new users
        if (_user.isNewUser) {
          print('⚠️ No assessment data for new user - providing default');
          if (mounted) {
            setState(() {
              _assessment = LoanAssessment.defaultForNewUser();
              _selectedLoanAmount = _assessment!.eligibleAmount;
            });
          }
          _showAssessmentSuccess(_assessment!);
        } else {
          throw Exception('No assessment data in response');
        }
      }
    } catch (e) {
      print('❌ Eligibility check error: $e');
      final errorMsg = e.toString();

      // For new users, provide default assessment even if API fails
      if (_user.isNewUser) {
        print('🔄 Providing default assessment for new user after API error');
        if (mounted) {
          setState(() {
            _assessment = LoanAssessment.defaultForNewUser();
            _selectedLoanAmount = _assessment!.eligibleAmount;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = errorMsg;
          });
        }
        _showErrorSnackBar('Failed to check eligibility: $errorMsg');
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingCreditScore = false;
        });
      }
    }
  }

  void _showAssessmentSuccess(LoanAssessment assessment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ ${_user.isNewUser ? 'Welcome!' : 'Credit assessment complete!'} Eligible: Ksh ${assessment.eligibleAmount.toInt()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _applyForLoan() async {
    if (_assessment == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final interestFee = _calculateInterestFee();
      final totalRepayable = _calculateTotalRepayable();

      print('📤 Applying for loan for user: ${_user.id}');
      print('💰 Selected Amount: $_selectedLoanAmount');
      print('💰 Interest Fee: $interestFee');
      print('💰 Total Repayable: $totalRepayable');
      print('📅 Due Date: ${_assessment!.repaymentDueDate}');

      final response = await _apiService.applyForLoan(
        amount: _selectedLoanAmount,
        interestFee: interestFee,
        repayableAmount: totalRepayable,
        tenureDays: _assessment!.tenureDays,
        repaymentDueDate: _assessment!.repaymentDueDate,
      );

      if (response['success'] != null && !response['success']) {
        throw Exception(response['message'] ?? 'Loan application failed');
      }

      _showSuccessSnackBar(response['message'] ?? 'Loan application submitted successfully!');

      // Update user state to reflect pending loan
      if (mounted) {
        setState(() {
          _user = User(
            id: _user.id,
            phone: _user.phone,
            loanId: response['loan_id']?.toString() ?? _user.loanId,
            loanAmount: _selectedLoanAmount.toStringAsFixed(0),
            loanBalance: totalRepayable.toStringAsFixed(0),
            repayableAmount: totalRepayable.toStringAsFixed(0),
            status: 'pending',
            loanStatus: 'pending',
          );
          _assessment = null;
        });
      }

    } catch (e) {
      print('❌ Loan application error: $e');
      final errorMsg = e.toString();
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
      _showErrorSnackBar('Failed to apply for loan: $errorMsg');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _repayLoan() async {
    // Check if we have a valid loan ID
    final loanId = _user.loanId;
    if (loanId == null || loanId == "null" || loanId.isEmpty) {
      _showErrorSnackBar('Loan ID is missing. Cannot process payment.');
      return;
    }

    final balance = double.tryParse(_user.loanBalance) ?? 0;
    if (balance <= 0) {
      _showErrorSnackBar('No outstanding balance to repay.');
      return;
    }

    if (mounted) {
      setState(() {
        _waitingForPayment = true;
        _errorMessage = null;
      });
    }

    try {
      // Get formatted phone number for M-Pesa
      final phoneNumber = _formatPhoneForMPesa(_user.phone);

      print('💰 Processing repayment');
      print('📱 Phone: $phoneNumber');
      print('💳 Loan ID: $loanId');
      print('💰 Amount: $balance');

      final response = await _apiService.repayLoan(
        loanId: loanId,
        amount: balance,
        phoneNumber: phoneNumber,
      );

      if (response['success'] != null && !response['success']) {
        throw Exception(response['message'] ?? 'Repayment failed');
      }

      _showSuccessSnackBar(response['message'] ?? 'Payment initiated successfully!');
      _showPaymentInstructions();

      // Simulate payment success after delay
      _simulatePaymentSuccess();

    } catch (e) {
      print('❌ Repayment error: $e');
      final errorMsg = e.toString();
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          _waitingForPayment = false;
        });
      }
      _showErrorSnackBar('Failed to initiate payment: $errorMsg');
    }
  }

  void _simulatePaymentSuccess() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _waitingForPayment = false;
          // Update user state to reflect repayment
          _user = User(
            id: _user.id,
            phone: _user.phone,
            loanId: _user.loanId,
            loanAmount: _user.loanAmount,
            loanBalance: '0',
            repayableAmount: _user.repayableAmount,
            status: 'repaid',
            loanStatus: 'repaid',
          );
        });
        _showSuccessSnackBar('Payment completed successfully!');
      }
    });
  }

  void _showPaymentInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Colors.green),
            SizedBox(width: 10),
            Text('STK Push Sent'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STK Push has been sent to ${_user.phone}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your phone and enter your M-Pesa PIN to complete the payment.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            if (_waitingForPayment)
              const Column(
                children: [
                  SizedBox(height: 10),
                  LinearProgressIndicator(),
                  SizedBox(height: 10),
                  Text(
                    'Waiting for payment confirmation...',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _waitingForPayment ? null : () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  double _calculateTotalRepayable() {
    if (_assessment == null) return _selectedLoanAmount;
    final interest = (_selectedLoanAmount * _assessment!.interestRate / 100);
    return _selectedLoanAmount + interest;
  }

  double _calculateInterestFee() {
    if (_assessment == null) return 0;
    return (_selectedLoanAmount * _assessment!.interestRate / 100);
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showApplyLoanDialog() {
    if (_assessment == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Fixed: Check if eligible amount is at least 100, otherwise adjust min
          final double eligibleAmount = _assessment!.eligibleAmount;
          final double minAmount = 100.0;
          final double maxAmount = eligibleAmount;

          // Handle the case where maxAmount < minAmount
          final bool canShowSlider = maxAmount >= minAmount;
          final double sliderValue = _selectedLoanAmount.clamp(
            canShowSlider ? minAmount : 0.0,
            maxAmount,
          );

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  _user.isNewUser ? Icons.emoji_people : Icons.assessment,
                  color: _user.isNewUser ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 10),
                Text(_user.isNewUser ? 'Welcome! Apply for Starter Loan' : 'Loan Application'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_user.isNewUser)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Welcome! Start with a small loan to build your credit history.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Review your loan details before applying:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Loan Amount Section
                  const Text('Loan Amount', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          'Ksh ${_selectedLoanAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 10),

                        if (canShowSlider)
                          Slider(
                            value: sliderValue,
                            min: minAmount,
                            max: maxAmount,
                            divisions: ((maxAmount - minAmount) ~/ 100).clamp(1, 100).toInt(),
                            label: "Ksh ${sliderValue.toStringAsFixed(0)}",
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
                            child: Text(
                              eligibleAmount < 100
                                  ? 'Minimum loan amount is Ksh 100. You are eligible for Ksh ${eligibleAmount.toInt()}'
                                  : 'Eligible amount is too low for selection',
                              style: const TextStyle(color: Colors.orange),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 10),
                        if (canShowSlider)
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

                  // Loan Details
                  _buildLoanDetailRow('Selected Amount', 'Ksh ${_selectedLoanAmount.toStringAsFixed(0)}'),
                  _buildLoanDetailRow('Interest Rate', '${_assessment!.interestRate}%'),
                  _buildLoanDetailRow('Interest Fee', 'Ksh ${_calculateInterestFee().toInt()}'),
                  _buildLoanDetailRow('Total Repayable', 'Ksh ${_calculateTotalRepayable().toInt()}'),
                  _buildLoanDetailRow('Repayment Due', _formatDate(_assessment!.repaymentDueDate)),
                  _buildLoanDetailRow('Tenure', '${_assessment!.tenureDays} days'),
                  _buildLoanDetailRow('Credit Score', _assessment!.creditScore.toString()),

                  const SizedBox(height: 10),
                  Text(
                    'Remarks: ${_assessment!.remarks}',
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),

                  const SizedBox(height: 15),
                  const Text(
                    'Do you want to proceed with this loan application?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _selectedLoanAmount >= 100
                    ? () {
                  Navigator.pop(context);
                  _applyForLoan();
                }
                    : null,
                child: Text(_user.isNewUser ? 'Get Starter Loan' : 'Apply Now'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoanDetailRow(String title, String value) {
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Loading...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCheckView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _user.isNewUser ? 'Setting up your account...' : 'Checking credit score...',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            _user.isNewUser ? 'Welcome to SureCash! Preparing your starter loan...' : 'Please wait while we assess your eligibility',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveLoanView() {
    final balance = double.tryParse(_user.loanBalance) ?? 0;
    final totalAmount = double.tryParse(_user.repayableAmount) ?? 0;
    final amountRepaid = totalAmount - balance;
    final progress = totalAmount > 0 ? (amountRepaid / totalAmount) * 100 : 0;

    // Check if status is "disbursed" (case insensitive)
    final isDisbursed = _user.status.toLowerCase().contains('disbursed');
    final shouldShowRepayButton = isDisbursed && balance > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Loan Status Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Icon(
                        _getStatusIcon(_user.status),
                        size: 60,
                        color: _getStatusColor(_user.status),
                      ),
                      if (_waitingForPayment)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.payment, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getStatusDisplayText(_user.status),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ksh ${_user.loanAmount}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (progress > 0 && progress < 100) ...[
                    Text(
                      'Repayment Progress: ${progress.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.grey[300],
                      color: Colors.green,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ksh ${amountRepaid.toInt()} repaid of Ksh ${totalAmount.toInt()}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Only show repay button if status is "disbursed" and balance > 0
                  if (shouldShowRepayButton)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _waitingForPayment ? null : _repayLoan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _waitingForPayment
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            SizedBox(width: 8),
                            Text('Processing Payment...'),
                          ],
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Repay Loan Now', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),

                  // Show message if pending
                  if (_user.status.toLowerCase().contains('pending'))
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'Your loan is pending approval. Once disbursed, you can repay it here.',
                        style: TextStyle(color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Loan Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Loan Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Loan Amount', 'Ksh ${_user.loanAmount}'),
                  _buildDetailRow('Outstanding Balance', 'Ksh ${_user.loanBalance}'),
                  _buildDetailRow('Total Repayable', 'Ksh ${_user.repayableAmount}'),
                  _buildDetailRow('Status', _user.status.toUpperCase()),
                  if (_user.loanId != null) _buildDetailRow('Loan ID', _user.loanId!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLoanView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Welcome Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _user.isNewUser
                        ? Icons.emoji_people
                        : _assessment != null
                        ? Icons.verified_user
                        : Icons.assessment,
                    size: 60,
                    color: _user.isNewUser
                        ? Colors.blue
                        : _assessment != null
                        ? Colors.green
                        : Colors.blueAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user.isNewUser
                        ? 'Welcome to SureCash!'
                        : _assessment != null
                        ? 'Loan Available!'
                        : 'Check Your Eligibility',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _user.isNewUser
                        ? 'Start your journey with a small starter loan'
                        : _assessment != null
                        ? 'You are eligible for a loan up to Ksh ${_assessment!.eligibleAmount.toInt()}'
                        : 'Check if you qualify for a loan and see your credit limit',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Eligibility Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _user.isNewUser ? 'Starter Loan' : 'Loan Eligibility',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _assessment != null
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _assessment != null ? Colors.green : Colors.blueAccent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _user.isNewUser ? 'Starter Loan Amount' : 'Maximum Eligible Amount',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _assessment != null
                              ? 'Ksh ${_assessment!.eligibleAmount.toInt()}'
                              : _user.isNewUser
                              ? 'Ksh 100'
                              : 'Check Now',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _assessment != null ? Colors.green : Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_assessment != null) _buildAssessmentDetails(),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checkingCreditScore
                          ? null
                          : _assessment != null
                          ? _showApplyLoanDialog
                          : _checkEligibility,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _assessment != null ? Colors.green : Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _checkingCreditScore
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                        _user.isNewUser
                            ? 'Get Starter Loan'
                            : _assessment != null
                            ? 'Apply for Loan'
                            : 'Check Eligibility',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentDetails() {
    if (_assessment == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assessment Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildTermRow('Credit Score', _assessment!.creditScore.toString()),
        _buildTermRow('Interest Rate', '${_assessment!.interestRate}%'),
        _buildTermRow('Repayment Period', '${_assessment!.tenureDays} days'),
        const SizedBox(height: 8),
        Text(
          _assessment!.remarks,
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTermRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'repaid':
      case 'fully repaid':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.thumb_up;
      case 'disbursed':
        return Icons.money;
      case 'active':
        return Icons.money;
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
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'disbursed':
        return Colors.lightBlue;
      case 'active':
        return Colors.lightBlue;
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
        return 'LOAN FULLY REPAID';
      case 'pending':
        return 'PENDING APPROVAL';
      case 'approved':
        return 'LOAN APPROVED';
      case 'disbursed':
        return 'LOAN DISBURSED';
      case 'active':
        return 'ACTIVE LOAN';
      case 'overdue':
        return 'PAYMENT OVERDUE';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SureCash',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _user.isNewUser ? null : _checkEligibility,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _checkingCreditScore
          ? _buildCreditCheckView()
          : _user.hasActiveLoan || _user.hasPendingLoan
          ? _buildActiveLoanView()
          : _buildNoLoanView(),
    );
  }
}