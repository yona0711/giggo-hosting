enum EscrowStatus { pendingFunding, funded, released, disputed }

EscrowStatus escrowStatusFromString(String value) {
  return EscrowStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => EscrowStatus.pendingFunding,
  );
}

class EscrowPayment {
  EscrowPayment({
    required this.id,
    required this.gigId,
    required this.amount,
    required this.status,
  });

  final String id;
  final String gigId;
  final double amount;
  EscrowStatus status;

  factory EscrowPayment.fromJson(Map<String, dynamic> json) {
    return EscrowPayment(
      id: json['id'] as String,
      gigId: json['gigId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: escrowStatusFromString(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gigId': gigId,
      'amount': amount,
      'status': status.name,
    };
  }
}
