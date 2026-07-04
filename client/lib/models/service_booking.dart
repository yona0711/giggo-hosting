import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceBooking {
  const ServiceBooking({
    required this.id,
    required this.providerUid,
    required this.providerName,
    required this.clientUid,
    required this.clientName,
    required this.serviceTitle,
    required this.scheduledDate,
    required this.customerAddress,
    required this.notes,
    required this.createdAt,
    this.escrowAmount = 0,
    this.providerSubscriptionActive = false,
    this.requiresGuardianApproval = false,
    this.guardianApprovalStatus = 'notRequired',
    this.guardianPresenceConfirmed = false,
    this.guardianEmail = '',
    this.guardianUid,
    this.guardianApprovedAt,
    this.paymentStatus = 'pendingFunding',
  });

  final String id;
  final String providerUid;
  final String providerName;
  final String clientUid;
  final String clientName;
  final String serviceTitle;
  final DateTime scheduledDate;
  final String customerAddress;
  final String notes;
  final DateTime createdAt;
  final double escrowAmount;
  final bool providerSubscriptionActive;
  final bool requiresGuardianApproval;
  final String guardianApprovalStatus;
  final bool guardianPresenceConfirmed;
  final String guardianEmail;
  final String? guardianUid;
  final DateTime? guardianApprovedAt;
  final String paymentStatus;

  bool get pendingGuardianApproval =>
      requiresGuardianApproval && guardianApprovalStatus == 'pending';
  bool get guardianApproved =>
      !requiresGuardianApproval || guardianApprovalStatus == 'approved';

  factory ServiceBooking.fromJson(String id, Map<String, dynamic> json) {
    final scheduledValue = json['scheduledDate'];
    final createdValue = json['createdAt'];
    final approvedValue = json['guardianApprovedAt'];

    DateTime toDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    final now = DateTime.now();

    return ServiceBooking(
      id: id,
      providerUid: (json['providerUid'] as String?) ?? '',
      providerName: (json['providerName'] as String?) ?? 'Provider',
      clientUid: (json['clientUid'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? 'Client',
      serviceTitle: (json['serviceTitle'] as String?) ?? 'Service',
      scheduledDate: toDate(scheduledValue, now),
      customerAddress: (json['customerAddress'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      createdAt: toDate(createdValue, now),
      escrowAmount: (json['escrowAmount'] as num?)?.toDouble() ?? 0,
      providerSubscriptionActive:
          (json['providerSubscriptionActive'] as bool?) ?? false,
      requiresGuardianApproval:
          (json['requiresGuardianApproval'] as bool?) ?? false,
      guardianApprovalStatus:
          (json['guardianApprovalStatus'] as String?) ?? 'notRequired',
      guardianPresenceConfirmed:
          (json['guardianPresenceConfirmed'] as bool?) ?? false,
      guardianEmail: (json['guardianEmail'] as String?) ?? '',
      guardianUid: json['guardianUid'] as String?,
      guardianApprovedAt:
          approvedValue == null ? null : toDate(approvedValue, now),
      paymentStatus: (json['paymentStatus'] as String?) ?? 'pendingFunding',
    );
  }
}
