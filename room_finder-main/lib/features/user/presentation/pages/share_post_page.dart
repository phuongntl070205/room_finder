import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/models/listing_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/chat_service.dart';
import '../../../../data/services/user_service.dart';
import '../../../../presentation/pages/chat_detail_page.dart';

class SharePostSheet extends StatelessWidget {
  final ListingModel post;
  final String shareText;

  const SharePostSheet({
    super.key,
    required this.post,
    required this.shareText,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Chia sẻ bài viết', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.copy)),
              title: const Text('Sao chép nội dung chia sẻ'),
              subtitle: Text(shareText, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: shareText));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép nội dung chia sẻ')));
                }
              },
            ),
            const Divider(),
            const Text('Gửi cho người dùng', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (currentUser == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Vui lòng đăng nhập để chia sẻ qua tin nhắn')),
              )
            else
              SizedBox(
                height: 320,
                child: StreamBuilder<List<UserModel>>(
                  stream: UserService().getPotentialRoommates(currentUser.uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
                    }

                    final users = snapshot.data!;
                    if (users.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Chưa có người dùng khác để chia sẻ')),
                      );
                    }

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                              child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                            ),
                            title: Text(user.displayName),
                            subtitle: Text(user.email),
                            onTap: () async {
                              try {
                                final chatId = await ChatService().getOrCreateChat(user.uid, postId: post.id);
                                await ChatService().sendMessage(chatId, shareText);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatDetailPage(chatId: chatId, otherUserName: user.displayName),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể chia sẻ: $e')));
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
