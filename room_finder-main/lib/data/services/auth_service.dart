import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get userStream => _auth.authStateChanges();

  // Lấy dữ liệu UserModel từ Firestore dựa trên UID
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      print("Lỗi lấy thông tin User: $e");
    }
    return null;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Gọi dịch vụ Google (hiện bảng chọn tài khoản)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await syncUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      print("Lỗi Google Sign-In: $e");
      rethrow; // Quăng lỗi để UI xử lý báo lỗi cho người dùng
    }
  }

  Future<void> syncUserToFirestore(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Người dùng mới',
        avatarUrl: user.photoURL,
        role: 'user', // Mặc định là user thường
        createdAt: DateTime.now(),
      );
      await docRef.set(newUser.toMap());
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
