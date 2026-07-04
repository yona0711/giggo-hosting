import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceConversation {
  const ServiceConversation({
    required this.id,
    required this.providerUid,
    required this.providerName,
    required this.clientUid,
    required this.clientName,
    required this.lastMessage,
    required this.lastUpdated,
  });

  final String id;
  final String providerUid;
  final String providerName;
  final String clientUid;
  final String clientName;
  final String lastMessage;
  final DateTime lastUpdated;

  factory ServiceConversation.fromJson(String id, Map<String, dynamic> json) {
    final timestamp = json['lastUpdated'];
    DateTime lastUpdated;
    if (timestamp is Timestamp) {
      lastUpdated = timestamp.toDate();
    } else {
      lastUpdated = DateTime.now();
    }

    return ServiceConversation(
      id: id,
      providerUid: (json['providerUid'] as String?) ?? '',
      providerName: (json['providerName'] as String?) ?? 'Provider',
      clientUid: (json['clientUid'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? 'Client',
      lastMessage: (json['lastMessage'] as String?) ?? '',
      lastUpdated: lastUpdated,
    );
  }
}
