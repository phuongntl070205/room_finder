import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_model.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lấy danh sách tất cả bài đăng đang chờ duyệt (pending)
  Stream<List<ListingModel>> getPendingPosts() {
    return _db
        .collection('listings')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ListingModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Lay danh sach tat ca bai dang de admin quan ly theo trang thai.
  Stream<List<ListingModel>> getAllPosts() {
    return _db
        .collection('listings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ListingModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Phê duyệt bài đăng
  Future<void> approvePost(String postId) async {
    final doc = await _db.collection('listings').doc(postId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final authorId = data['authorId'];
    final title = data['title'] ?? 'Bài đăng của bạn';

    await _db.collection('listings').doc(postId).update({
      'status': 'published',
      'moderationComment': null,
    });

    if (authorId != null) {
      print('Sending approve notification to: $authorId'); // Debug log
      await _sendNotification(
        authorId,
        'Bài đăng đã được duyệt',
        'Chúc mừng! Bài đăng "$title" của bạn đã được phê duyệt.',
        'post_approved',
        data: {'postId': postId},
      );
    }
  }

  // Từ chối bài đăng kèm lý do
  Future<void> rejectPost(String postId, String reason) async {
    final doc = await _db.collection('listings').doc(postId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final authorId = data['authorId'];

    await _db.collection('listings').doc(postId).update({
      'status': 'rejected',
      'moderationComment': reason,
    });

    if (authorId != null) {
      print('Sending reject notification to: $authorId'); // Debug log
      await _sendNotification(
        authorId,
        'Bài đăng không được duyệt',
        'Lý do: $reason',
        'post_rejected',
        data: {'postId': postId},
      );
    }
  }

  Future<void> _sendNotification(
    String userId,
    String title,
    String body,
    String type, {
    Map<String, dynamic> data = const {},
  }) async {
    await _db.collection('users').doc(userId).collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      ...data,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closePost(String postId) async {
    await _db.collection('listings').doc(postId).update({
      'status': 'closed',
    });
  }
}
