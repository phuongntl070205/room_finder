import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lấy danh sách người dùng tiềm năng để ghép đôi (trừ bản thân)
  Stream<List<UserModel>> getPotentialRoommates(String currentUid) {
    return _db.collection('users')
        .where(FieldPath.documentId, isNotEqualTo: currentUid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Thuật toán tính % phù hợp đơn giản
  double calculateMatchPercentage(UserModel current, UserModel other) {
    if (current.habitTags.isEmpty) return 0.0;
    
    // 1. So khớp thói quen (Habit Tags) - Trọng số 70%
    int commonTags = current.habitTags.where((tag) => other.habitTags.contains(tag)).length;
    double habitScore = (commonTags / current.habitTags.length) * 100;

    // 2. So khớp ngân sách - Trọng số 30%
    // Nếu ngân sách giao thoa nhau thì được điểm
    bool budgetMatch = (current.budgetMin <= other.budgetMax && current.budgetMax >= other.budgetMin);
    double budgetScore = budgetMatch ? 100.0 : 0.0;

    return (habitScore * 0.7) + (budgetScore * 0.3);
  }
}
