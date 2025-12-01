class User {
  final String id;
  final String phone;
  final String? loanId;
  final String loanAmount;
  final String loanBalance;
  final String repayableAmount;
  final String status;
  final String? loanStatus;

  User({
    required this.id,
    required this.phone,
    this.loanId,
    required this.loanAmount,
    required this.loanBalance,
    required this.repayableAmount,
    required this.status,
    this.loanStatus,
  });

  factory User.fromLoginResponse(Map<String, dynamic> data) {
    return User(
      id: data['user_id']?.toString() ?? '0',
      phone: data['phone']?.toString() ?? '',
      loanId: data['loan_id']?.toString(),
      loanAmount: data['loan_amount']?.toString() ?? '0',
      loanBalance: data['loan_balance']?.toString() ?? '0',
      repayableAmount: data['repayable_amount']?.toString() ?? '0',
      status: data['status']?.toString() ?? '',
      loanStatus: data['loan_status']?.toString(),
    );
  }

  bool get hasActiveLoan {
    // Check if loanId is valid and not null
    if (loanId == null || loanId == "null" || loanId!.isEmpty) return false;

    // Check if loan amount is greater than 0
    final loanAmountValue = double.tryParse(loanAmount) ?? 0;
    if (loanAmountValue <= 0) return false;

    // Check if status indicates an active loan
    final loanStatus = this.status.toLowerCase();
    final balance = double.tryParse(loanBalance) ?? 0;

    return !loanStatus.contains('repaid') &&
        !loanStatus.contains('completed') &&
        balance > 0;
  }

  bool get hasPendingLoan {
    if (loanId == null || loanId == "null" || loanId!.isEmpty) return false;

    final loanStatus = this.status.toLowerCase();
    return loanStatus.contains('pending') || loanStatus.contains('approved');
  }

  bool get canApplyForLoan {
    return !hasActiveLoan && !hasPendingLoan;
  }

  bool get isNewUser {
    return (loanId == null || loanId == "null" || loanId!.isEmpty) &&
        (loanAmount == "0" || loanAmount == "null" || loanAmount.isEmpty) &&
        (status.isEmpty || status == "null");
  }
}

class LoanAssessment {
  final double eligibleAmount;
  final double interestRate;
  final double interestFee;
  final double totalRepayable;
  final String repaymentDueDate;
  final int tenureDays;
  final int creditScore;
  final String remarks;
  final int scoreTrend;

  LoanAssessment({
    required this.eligibleAmount,
    required this.interestRate,
    required this.interestFee,
    required this.totalRepayable,
    required this.repaymentDueDate,
    required this.tenureDays,
    required this.creditScore,
    required this.remarks,
    required this.scoreTrend,
  });

  factory LoanAssessment.fromJson(Map<String, dynamic> data) {
    return LoanAssessment(
      eligibleAmount: (data['eligible_amount'] as num?)?.toDouble() ?? 100.0,
      interestRate: (data['interest_rate'] as num?)?.toDouble() ?? 4.5,
      interestFee: (data['interest_fee'] as num?)?.toDouble() ?? 4.5,
      totalRepayable: (data['total_repayable'] as num?)?.toDouble() ?? 104.5,
      repaymentDueDate: data['repayment_due_date'] ?? _calculateDefaultDueDate(),
      tenureDays: data['tenure_days'] ?? 30,
      creditScore: data['credit_score'] ?? 50,
      remarks: data['remarks'] ?? 'Welcome new customer! Start with a small loan.',
      scoreTrend: data['score_trend'] ?? 50,
    );
  }

  factory LoanAssessment.defaultForNewUser() {
    final defaultDueDate = _calculateDefaultDueDate();
    return LoanAssessment(
      eligibleAmount: 100.0,
      interestRate: 4.5,
      interestFee: 4.5,
      totalRepayable: 104.5,
      repaymentDueDate: defaultDueDate,
      tenureDays: 30,
      creditScore: 50,
      remarks: 'Welcome new customer! Start with a small loan to build your credit history.',
      scoreTrend: 50,
    );
  }

  static String _calculateDefaultDueDate() {
    final dueDate = DateTime.now().add(const Duration(days: 30));
    return "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";
  }
}