import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload danh sách hình ảnh và trả về danh sách URL
  Future<List<String>> uploadPostImages(String postId, List<File> images) async {
    List<String> imageUrls = [];
    
    for (int i = 0; i < images.length; i++) {
      try {
        String fileName = 'image_${i}_${DateTime.now().millisecondsSinceEpoch}${path.extension(images[i].path)}';
        Reference ref = _storage.ref().child('posts').child(postId).child(fileName);
        
        // Thêm metadata để Rules có thể kiểm tra (nếu cần)
        UploadTask uploadTask = ref.putFile(images[i]);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        print('Lỗi upload ảnh $i: $e');
      }
    }
    
    return imageUrls;
  }
}
