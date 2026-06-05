import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/listing_model.dart';
import '../widgets/post_card.dart';

class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bài đăng của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Đã đăng'),
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Bị từ chối'),
            ],
          ),
        ),
        body: currentUser == null
            ? const Center(child: Text('Vui lòng đăng nhập'))
            : TabBarView(
                children: [
                  _buildPostList(currentUser.uid, ListingStatus.published),
                  _buildPostList(currentUser.uid, ListingStatus.pending),
                  _buildPostList(currentUser.uid, ListingStatus.rejected),
                ],
              ),
      ),
    );
  }

  Widget _buildPostList(String userId, ListingStatus status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('authorId', isEqualTo: userId)
          .where('status', isEqualTo: status.name)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Không có bài đăng nào ở trạng thái này', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final post = ListingModel.fromMap(
              snapshot.data!.docs[index].data() as Map<String, dynamic>,
              snapshot.data!.docs[index].id,
            );
            return PostCard(post: post);
          },
        );
      },
    );
  }
}
