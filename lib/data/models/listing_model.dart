import 'package:cloud_firestore/cloud_firestore.dart';

enum ListingStatus { pending, published, rejected, closed }

enum PostType { roomForRent, roommateWanted }

enum ModerationStatus { pendingCheck, approved, rejected }

class ListingModel {
  final String id;
  final String authorId;
  final PostType postType;
  final String title;
  final String description;
  final double price;
  final ListingStatus status;
  final GeoPoint location;
  final String address;
  final Map<String, String> addressComponents;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? moderationComment;
  final ModerationStatus? moderationStatus;
  final Map<String, dynamic> moderationResult;
  final DateTime? moderationCheckedAt;
  final Map<String, bool> amenities;

  // Monthly cost estimation fields
  final double electricPrice;
  final double waterPrice;
  final double serviceFee;
  final double otherFee;

  // Custom default usage (optional)
  final double defaultElectricUsage; // Số điện mặc định/tháng
  final double defaultWaterUsage; // Số khối nước mặc định/tháng

  ListingModel({
    required this.id,
    required this.authorId,
    required this.postType,
    required this.title,
    required this.description,
    required this.price,
    required this.status,
    required this.location,
    required this.address,
    this.addressComponents = const {},
    this.mediaUrls = const [],
    required this.createdAt,
    this.updatedAt,
    this.moderationComment,
    this.moderationStatus,
    this.moderationResult = const {},
    this.moderationCheckedAt,
    this.amenities = const {},
    this.electricPrice = 0,
    this.waterPrice = 0,
    this.serviceFee = 0,
    this.otherFee = 0,
    this.defaultElectricUsage = 50, // Mặc định 50kWh nếu không nhập
    this.defaultWaterUsage = 4, // Mặc định 4 khối nếu không nhập
  });

  double get estimatedMonthlyCost {
    return price +
        serviceFee +
        otherFee +
        (electricPrice * defaultElectricUsage) +
        (waterPrice * defaultWaterUsage);
  }

  factory ListingModel.fromMap(Map<String, dynamic> map, String id) {
    return ListingModel(
      id: id,
      authorId: map['authorId'] ?? '',
      postType: PostType.values.firstWhere(
        (e) => e.name == map['postType'],
        orElse: () => PostType.roomForRent,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      status: ListingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ListingStatus.pending,
      ),
      location: map['location'] is GeoPoint
          ? map['location'] as GeoPoint
          : (map['location'] is Map && map['location']['geopoint'] is GeoPoint)
              ? map['location']['geopoint'] as GeoPoint
              : const GeoPoint(0, 0),
      address: map['address'] ?? '',
      addressComponents:
          Map<String, String>.from(map['addressComponents'] ?? {}),
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      moderationComment: map['moderationComment'],
      moderationStatus: _moderationStatusFromMap(map['moderationStatus']),
      moderationResult:
          Map<String, dynamic>.from(map['moderationResult'] ?? {}),
      moderationCheckedAt: (map['moderationCheckedAt'] as Timestamp?)?.toDate(),
      amenities: Map<String, bool>.from(map['amenities'] ?? {}),
      electricPrice: (map['electricPrice'] ?? 0).toDouble(),
      waterPrice: (map['waterPrice'] ?? 0).toDouble(),
      serviceFee: (map['serviceFee'] ?? 0).toDouble(),
      otherFee: (map['otherFee'] ?? 0).toDouble(),
      defaultElectricUsage: (map['defaultElectricUsage'] ?? 50).toDouble(),
      defaultWaterUsage: (map['defaultWaterUsage'] ?? 4).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'postType': postType.name,
        'title': title,
        'description': description,
        'price': price,
        'status': status.name,
        'location': {'geopoint': location},
        'address': address,
        'addressComponents': addressComponents,
        'mediaUrls': mediaUrls,
        'createdAt': Timestamp.fromDate(createdAt),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        'moderationComment': moderationComment,
        if (moderationStatus != null)
          'moderationStatus': moderationStatus!.firestoreValue,
        if (moderationResult.isNotEmpty) 'moderationResult': moderationResult,
        if (moderationCheckedAt != null)
          'moderationCheckedAt': Timestamp.fromDate(moderationCheckedAt!),
        'amenities': amenities,
        'electricPrice': electricPrice,
        'waterPrice': waterPrice,
        'serviceFee': serviceFee,
        'otherFee': otherFee,
        'defaultElectricUsage': defaultElectricUsage,
        'defaultWaterUsage': defaultWaterUsage,
      };

  static ModerationStatus? _moderationStatusFromMap(dynamic value) {
    if (value == null) return null;
    return ModerationStatus.values.firstWhere(
      (status) => status.firestoreValue == value,
      orElse: () => ModerationStatus.pendingCheck,
    );
  }
}

extension ModerationStatusX on ModerationStatus {
  String get firestoreValue {
    switch (this) {
      case ModerationStatus.pendingCheck:
        return 'pending_check';
      case ModerationStatus.approved:
        return 'approved';
      case ModerationStatus.rejected:
        return 'rejected';
    }
  }
}
