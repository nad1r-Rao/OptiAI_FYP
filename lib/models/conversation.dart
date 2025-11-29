import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime timestamp;

  Conversation({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.timestamp,
  });

  factory Conversation.fromMap(String id, Map<String, dynamic> map) {
    return Conversation(
      id: id,
      title: map['title'] ?? 'New Conversation',
      lastMessage: map['lastMessage'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
