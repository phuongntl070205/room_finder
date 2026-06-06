import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/user_model.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/chat_service.dart';
import '../widgets/post_card.dart';
import 'chat_detail_page.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Thông tin người dùng', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text('Không tìm thấy thông tin người dùng'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final user = UserModel.fromMap(userData, userId);

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue[50],
                        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                        child: user.avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.blue) : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(user.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 20),
                        ],
                      ),
                      Text(user.email, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                        Text(user.phoneNumber!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text(
                        user.preferredAreas.isNotEmpty
                            ? 'Quan tâm khu vực: ${user.preferredAreas.join(', ')}'
                            : 'Người dùng chưa cập nhật mô tả khu vực mong muốn.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      if (user.habitTags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: user.habitTags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.blue[50],
                            side: BorderSide.none,
                          )).toList(),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildInfoItem('Ngân sách', (user.budgetMin > 0 || user.budgetMax > 0) 
                              ? '${currencyFormat.format(user.budgetMin)} - ${currencyFormat.format(user.budgetMax)}'
                              : 'Chưa thiết lập'),
                          _buildInfoItem('Khu vực', user.preferredAreas.isNotEmpty ? user.preferredAreas.join(', ') : 'Chưa thiết lập'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _MessageButton(userId: user.uid, userName: user.displayName),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.list_alt,
                        title: 'Bài đăng của ${user.displayName}',
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (context) => UserPostsPage(userId: userId, userName: user.displayName),
                        )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _RelatedPostsSection(userId: userId, userName: user.displayName),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _MessageButton extends StatelessWidget {
  final String userId;
  final String userName;

  const _MessageButton({
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == userId) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            final chatId = await ChatService().getOrCreateChat(userId);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: chatId, otherUserName: userName)),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể mở trò chuyện: $e')));
          }
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Nhắn tin'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

class _RelatedPostsSection extends StatelessWidget {
  final String userId;
  final String userName;

  const _RelatedPostsSection({
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Bài đăng liên quan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('listings')
                .where('authorId', isEqualTo: userId)
                .where('status', isEqualTo: 'published')
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Text('$userName chưa có bài đăng công khai.'),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final post = ListingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                  return PostCard(post: post);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class UserPostsPage extends StatelessWidget {
  final String userId;
  final String userName;

  const UserPostsPage({super.key, required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bài đăng của $userName', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('authorId', isEqualTo: userId)
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('$userName chưa có bài đăng nào.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final post = ListingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              return PostCard(post: post);
            },
          );
        },
      ),
    );
  }
}
