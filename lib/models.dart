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
      id: data['user_id'].toString(),
      phone: data['phone'] ?? '',
      loanId: data['loan_id']?.toString(),
      loanAmount: data['loan_amount']?.toString() ?? '0',
      loanBalance: data['loan_balance']?.toString() ?? '0',
      repayableAmount: data['repayable_amount']?.toString() ?? '0',
      status: data['status'] ?? '',
      loanStatus: data['loan_status'],
    );
  }

  bool get hasActiveLoan {
    if (loanId == null || loanId == "null" || loanId!.isEmpty) return false;

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
      eligibleAmount: (data['eligible_amount'] as num).toDouble(),
      interestRate: (data['interest_rate'] as num).toDouble(),
      interestFee: (data['interest_fee'] as num).toDouble(),
      totalRepayable: (data['total_repayable'] as num).toDouble(),
      repaymentDueDate: data['repayment_due_date'] ?? '',
      tenureDays: data['tenure_days'] ?? 30,
      creditScore: data['credit_score'] ?? 0,
      remarks: data['remarks'] ?? '',
      scoreTrend: data['score_trend'] ?? 0,
    );
  }
}