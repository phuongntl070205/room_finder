import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> uploadPostImages(
      String postId, List<File> images) async {
    final imageUrls = <String>[];

    for (var i = 0; i < images.length; i++) {
      try {
        final extension = _extension(images[i].path);
        final fileName =
            'image_${i}_${DateTime.now().millisecondsSinceEpoch}$extension';
        final ref = _storage.ref().child('posts').child(postId).child(fileName);

        final uploadTask = ref.putFile(
          images[i],
          SettableMetadata(contentType: _contentType(extension)),
        );
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        throw Exception('Không thể tải ảnh ${i + 1}: $e');
      }
    }

    return imageUrls;
  }

  String _extension(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final fileName = normalized.split('/').last.toLowerCase();
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex == -1 ? '.jpg' : fileName.substring(dotIndex);
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
