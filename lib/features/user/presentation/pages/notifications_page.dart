import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/services/deep_link_service.dart';
import '../../../../presentation/pages/chat_detail_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? const Center(child: Text('Vui lòng đăng nhập để xem thông báo'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(
                      includeMetadataChanges:
                          true), // Quan trọng: Để bắt kịp thông báo mới tức thì
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _NotificationTile(
                        icon: Icons.info_outline,
                        title: 'Chưa có thông báo mới',
                        body:
                            'Các cập nhật về bài đăng, tin nhắn và hệ thống sẽ xuất hiện tại đây.',
                        timeText: '',
                        isUnread: false,
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final createdAt =
                        (data['createdAt'] as Timestamp?)?.toDate();
                    return _NotificationTile(
                      icon: _iconForType(data['type'] as String?),
                      title: data['title'] ?? 'Thông báo',
                      body: data['body'] ?? '',
                      timeText:
                          createdAt != null ? dateFormat.format(createdAt) : '',
                      isUnread: data['read'] != true,
                      onTap: () => _handleNotificationTap(context, docs[index]),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _handleNotificationTap(
      BuildContext context, QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    await doc.reference.update({'read': true});
    if (!context.mounted) return;

    final type = data['type'] as String?;
    if (type == 'message') {
      final chatId = data['chatId'] as String?;
      if (chatId == null || chatId.isEmpty) return;

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      final participants =
          List<String>.from(chatDoc.data()?['participants'] ?? []);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final otherUserId = participants.firstWhere(
        (id) => id != currentUid,
        orElse: () => '',
      );

      var otherUserName = 'Người dùng';
      if (otherUserId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
        otherUserName = userDoc.data()?['displayName'] ?? otherUserName;
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatDetailPage(chatId: chatId, otherUserName: otherUserName),
        ),
      );
      return;
    }

    if (type == 'post_approved' ||
        type == 'post_rejected' ||
        type == 'moderation') {
      final postId = data['postId'] as String?;
      if (postId == null || postId.isEmpty) return;
      await DeepLinkService.openPost(context, postId);
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'post':
      case 'post_approved':
      case 'post_rejected':
        return Icons.article_outlined;
      case 'moderation':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_none;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String timeText;
  final bool isUnread;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.timeText,
    required this.isUnread,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isUnread ? Colors.blue[50] : Colors.grey[100],
        child: Icon(icon, color: isUnread ? Colors.blue : Colors.grey),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty) Text(body),
          if (timeText.isNotEmpty)
            Text(timeText,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
      trailing: isUnread
          ? const Icon(Icons.circle, size: 10, color: Colors.blue)
          : null,
    );
  }
}
