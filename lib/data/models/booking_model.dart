import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, cancelled }

class BookingModel {
  final String id;
  final String listingId;
  final String listingTitle;
  final String tenantId;
  final String landlordId;
  final String chatId;
  final DateTime scheduledTime;
  final BookingStatus status;
  final String? note;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.tenantId,
    required this.landlordId,
    required this.chatId,
    required this.scheduledTime,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    return BookingModel(
      id: id,
      listingId: map['listingId'] as String? ?? '',
      listingTitle: map['listingTitle'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      landlordId: map['landlordId'] as String? ?? '',
      chatId: map['chatId'] as String? ?? '',
      scheduledTime:
      (map['scheduledTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: BookingStatus.values.firstWhere(
            (e) => e.name == (map['status'] as String? ?? 'pending'),
        orElse: () => BookingStatus.pending,
      ),
      note: map['note'] as String?,
      createdAt:
      (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'listingId': listingId,
    'listingTitle': listingTitle,
    'tenantId': tenantId,
    'landlordId': landlordId,
    'chatId': chatId,
    'scheduledTime': Timestamp.fromDate(scheduledTime),
    'status': status.name,
    'note': note,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  BookingModel copyWith({BookingStatus? status, String? note}) {
    return BookingModel(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      tenantId: tenantId,
      landlordId: landlordId,
      chatId: chatId,
      scheduledTime: scheduledTime,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }
}