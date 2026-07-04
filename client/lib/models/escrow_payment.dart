import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.createdAt,
    this.bookingId,
    this.serviceTitle,
    this.clientUid,
    this.providerUid,
    this.processorPaymentId,
    this.processorMode,
  });

  final String id;
  final String gigId;
  final double amount;
  EscrowStatus status;
  final DateTime? createdAt;
  final String? bookingId;
  final String? serviceTitle;
  final String? clientUid;
  final String? providerUid;
  final String? processorPaymentId;
  final String? processorMode;

  factory EscrowPayment.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime? createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }

    return EscrowPayment(
      id: json['id'] as String,
      gigId: json['gigId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: escrowStatusFromString(json['status'] as String),
      createdAt: createdAt,
      bookingId: json['bookingId'] as String?,
      serviceTitle: json['serviceTitle'] as String?,
      clientUid: json['clientUid'] as String?,
      providerUid: json['providerUid'] as String?,
      processorPaymentId: json['processorPaymentId'] as String?,
      processorMode: json['processorMode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gigId': gigId,
      'amount': amount,
      'status': status.name,
      if (createdAt != null) 'createdAt': createdAt!.toUtc(),
      'bookingId': bookingId,
      'serviceTitle': serviceTitle,
      'clientUid': clientUid,
      'providerUid': providerUid,
      'processorPaymentId': processorPaymentId,
      'processorMode': processorMode,
    };
  }
}
