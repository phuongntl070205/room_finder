import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/deep_link_service.dart';
import '../../data/services/chat_service.dart';
import 'post_detail_page.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const ChatDetailPage(
      {super.key, required this.chatId, required this.otherUserName});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final messageText = _messageController.text.trim();
    _messageController.clear();
    await _chatService.sendMessage(widget.chatId, messageText);
    await _markAsRead();
  }

  Future<void> _markAsRead() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .set({'unreadCount': {uid: 0}}, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _viewLinkedPost() async {
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    final chatData = chatDoc.data();
    final linkedPostId = chatData?['postId'] as String? ?? chatData?['listingId'] as String?;

    if (linkedPostId == null || linkedPostId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy bài đăng liên quan.')));
      }
      return;
    }

    final postDoc = await FirebaseFirestore.instance.collection('listings').doc(linkedPostId).get();
    if (!postDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bài đăng này đã bị xóa hoặc không tồn tại.')));
      }
      return;
    }

    final post = ListingModel.fromMap(postDoc.data() as Map<String, dynamic>, postDoc.id);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(post: post)));
    }
  }

  Future<void> _openSharedPost(String postId) async {
    await DeepLinkService.openPost(context, postId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Xem bài đăng',
            onPressed: _viewLinkedPost,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner gợi ý đã bị xóa
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('Bắt đầu trò chuyện ngay'));
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == _currentUser?.uid;
                    final text = msg['text'] as String? ?? '';
                    final sharedPostId = DeepLinkService.extractPostIdFromText(text);

                    final bubble = Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[600] : Colors.grey[200],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                          bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                          if (sharedPostId != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new, size: 14, color: isMe ? Colors.white : Colors.blue),
                                const SizedBox(width: 4),
                                Text('Mở bài viết', style: TextStyle(color: isMe ? Colors.white : Colors.blue, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: sharedPostId == null
                          ? bubble
                          : InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openSharedPost(sharedPostId),
                        child: bubble,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}