import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/listing_model.dart';
import 'package:intl/intl.dart';
import '../pages/post_detail_page.dart';
import '../pages/chat_detail_page.dart';
import '../../features/user/presentation/pages/comments_page.dart';

class PostCard extends StatelessWidget {
  final ListingModel post;
  const PostCard({super.key, required this.post});

  Future<void> _startChat(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == post.authorId) return;

    List<String> ids = [currentUser.uid, post.authorId];
    ids.sort();
    String chatId = ids.join('_');

    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': ids,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'postId': post.id,
        'unreadCount': {currentUser.uid: 0, post.authorId: 0},
      });
    } else {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'postId': post.id,
      }, SetOptions(merge: true));
    }

    final authorDoc = await FirebaseFirestore.instance.collection('users').doc(post.authorId).get();
    final authorName = (authorDoc.data() as Map<String, dynamic>?)?['displayName'] ?? 'Người dùng';

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ChatDetailPage(chatId: chatId, otherUserName: authorName),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(post: post))),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Giúp Card tự co giãn theo nội dung
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.grey[200],
                    child: post.mediaUrls.isNotEmpty 
                      ? Image.network(post.mediaUrls.first, fit: BoxFit.cover) 
                      : const Icon(Icons.image, size: 50, color: Colors.grey),
                  ),
                ),
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                    child: Text(post.postType == PostType.roomForRent ? 'Cho thuê' : 'Tìm ở ghép', 
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currencyFormat.format(post.price), 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                        child: Text('~ ${currencyFormat.format(post.estimatedMonthlyCost)}/tháng', 
                            style: TextStyle(fontSize: 11, color: Colors.blue[800], fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(post.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), 
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(post.address, style: const TextStyle(color: Colors.grey, fontSize: 12), 
                        maxLines: 1, overflow: TextOverflow.ellipsis))
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(post.authorId).get(),
                        builder: (context, snapshot) {
                          final userData = snapshot.data?.data() as Map<String, dynamic>?;
                          final name = userData?['displayName'] ?? 'Người dùng';
                          final avatar = userData?['avatarUrl'];
                          return Row(children: [
                            CircleAvatar(radius: 10, backgroundImage: avatar != null ? NetworkImage(avatar) : null, 
                                child: avatar == null ? const Icon(Icons.person, size: 12) : null),
                            const SizedBox(width: 6),
                            Text(name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ]);
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.blue), 
                        onPressed: () => _startChat(context),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.mode_comment_outlined, size: 18, color: Colors.blueGrey),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CommentsPage(postId: post.id, postTitle: post.title)),
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.bookmark_border, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
