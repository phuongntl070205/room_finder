import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/listing_model.dart';
import 'post_detail_page.dart';

class PostDeepLinkPage extends StatelessWidget {
  final String postId;

  const PostDeepLinkPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('listings').doc(postId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Bài viết')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bài viết này không tồn tại hoặc đã bị xóa.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final post =
            ListingModel.fromMap(snapshot.data!.data()!, snapshot.data!.id);
        return PostDetailPage(post: post);
      },
    );
  }
}
