import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/post_service.dart';
import '../widgets/post_card.dart';

class SavedPostsPage extends StatelessWidget {
  const SavedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final postService = PostService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài đã lưu', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: currentUser == null
          ? const Center(child: Text('Vui lòng đăng nhập để xem bài đã lưu'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final savedIds = List<String>.from(userData?['savedPostIds'] ?? []);

                if (savedIds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Bạn chưa lưu bài đăng nào', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return StreamBuilder<List<ListingModel>>(
                  stream: postService.getSavedPosts(savedIds),
                  builder: (context, postsSnapshot) {
                    if (postsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final posts = postsSnapshot.data ?? [];
                    if (posts.isEmpty) {
                      return const Center(child: Text('Các bài đăng bạn lưu không còn tồn tại hoặc đã bị gỡ.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: posts.length,
                      itemBuilder: (context, index) => PostCard(post: posts[index]),
                    );
                  },
                );
              },
            ),
    );
  }
}
