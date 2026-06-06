import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final String? lastMessageSenderId;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = const {},
    this.lastMessageSenderId,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      lastMessageSenderId: map['lastMessageSenderId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'participants': participants,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
    'unreadCount': unreadCount,
    'lastMessageSenderId': lastMessageSenderId,
  };
}
