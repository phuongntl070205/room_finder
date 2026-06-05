import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_model.dart';

class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Tạo bài đăng mới
  Future<void> createPost(ListingModel post) async {
    final docRef = post.id.isEmpty
        ? _db.collection('listings').doc()
        : _db.collection('listings').doc(post.id);
    await docRef.set(post.toMap());
  }

  // Logic Lưu/Bỏ lưu bài đăng
  Future<void> toggleSavePost(String userId, String postId, bool isSaved) async {
    final userRef = _db.collection('users').doc(userId);
    if (isSaved) {
      await userRef.update({
        'savedPostIds': FieldValue.arrayRemove([postId])
      });
    } else {
      await userRef.update({
        'savedPostIds': FieldValue.arrayUnion([postId])
      });
    }
  }

  // Lấy danh sách bài đã lưu thực tế
  Stream<List<ListingModel>> getSavedPosts(List<String> savedIds) {
    if (savedIds.isEmpty) return Stream.value([]);
    
    // Firestore whereIn giới hạn tối đa 10 IDs, nhưng với quy mô đồ án ta dùng tạm cách này
    // Nếu nhiều hơn 10 bài, cần query từng cái hoặc dùng collection group
    return _db.collection('listings')
        .where(FieldPath.documentId, whereIn: savedIds.take(10).toList())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ListingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Xóa bài đăng
  Future<void> deletePost(String postId) async {
    await _db.collection('listings').doc(postId).delete();
  }
}
