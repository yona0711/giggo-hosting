import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceMessage {
  const ServiceMessage({
    required this.id,
    required this.conversationId,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String conversationId;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime sentAt;

  factory ServiceMessage.fromJson(
    String id,
    String conversationId,
    Map<String, dynamic> json,
  ) {
    final timestamp = json['createdAt'];
    DateTime sentAt;
    if (timestamp is Timestamp) {
      sentAt = timestamp.toDate();
    } else {
      sentAt = DateTime.now();
    }

    return ServiceMessage(
      id: id,
      conversationId: conversationId,
      senderUid: (json['senderUid'] as String?) ?? '',
      senderName: (json['senderName'] as String?) ?? 'Guest',
      text: (json['text'] as String?) ?? '',
      sentAt: sentAt,
    );
  }
}
