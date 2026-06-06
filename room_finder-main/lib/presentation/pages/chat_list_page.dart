import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/chat_model.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Trò chuyện', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: currentUser == null
          ? const Center(child: Text('Vui lòng đăng nhập để xem tin nhắn'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUser.uid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Nếu lỗi do thiếu index lastMessageTime, ta sẽ hiện lỗi để bạn biết
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có cuộc trò chuyện nào',
                          style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('Hãy nhắn tin cho chủ trọ để bắt đầu!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final chats = snapshot.data!.docs
                    .map((doc) => ChatModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    // Tìm UID của người kia
                    final otherUserId = chat.participants.firstWhere(
                      (id) => id != currentUser.uid,
                      orElse: () => '',
                    );

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                        final otherUserName = userData?['displayName'] ?? 'Người dùng';
                        final otherUserAvatar = userData?['avatarUrl'];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.blue[50],
                            backgroundImage: otherUserAvatar != null ? NetworkImage(otherUserAvatar) : null,
                            child: otherUserAvatar == null ? const Icon(Icons.person, color: Colors.blue) : null,
                          ),
                          title: Text(
                            otherUserName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            chat.lastMessage?.isEmpty ?? true ? 'Bắt đầu cuộc trò chuyện' : chat.lastMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: (chat.unreadCount[currentUser.uid] ?? 0) > 0 ? Colors.black : Colors.grey[600],
                              fontWeight: (chat.unreadCount[currentUser.uid] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (chat.lastMessageTime != null)
                                Text(
                                  _formatChatTime(chat.lastMessageTime!),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              const SizedBox(height: 4),
                              if ((chat.unreadCount[currentUser.uid] ?? 0) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    '${chat.unreadCount[currentUser.uid]}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailPage(
                                  chatId: chat.id,
                                  otherUserName: otherUserName,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    if (now.day == time.day && now.month == time.month && now.year == time.year) {
      return DateFormat('HH:mm').format(time);
    }
    return DateFormat('dd/MM').format(time);
  }
}
