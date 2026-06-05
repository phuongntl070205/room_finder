import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import service
import 'package:room_finder/data/services/auth_service.dart';

// Import các trang từ thư mục user
import 'my_posts_page.dart';
import 'saved_posts_page.dart';
import 'edit_profile_page.dart';
import 'cost_calculator_page.dart';
import 'settings_page.dart';

// Import các trang từ thư mục admin
import 'package:room_finder/features/admin/presentation/pages/admin_moderation_page.dart';
import 'package:room_finder/features/admin/presentation/pages/booking_management_page.dart';
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = FirebaseAuth.instance.currentUser;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Cá nhân', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text('Không tìm thấy dữ State người dùng'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final displayName = userData['displayName'] ?? 'Người dùng';
          final email = userData['email'] ?? '';
          final avatarUrl = userData['avatarUrl'];
          final role = userData['role'] ?? 'user';
          final habitTags = List<String>.from(userData['habitTags'] ?? []);
          final budgetMin = (userData['budgetMin'] ?? 0).toDouble();
          final budgetMax = (userData['budgetMax'] ?? 0).toDouble();
          final preferredAreas = List<String>.from(userData['preferredAreas'] ?? []);

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
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.blue) : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 20),
                        ],
                      ),
                      Text(email, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      if (habitTags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: habitTags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.blue[50],
                            side: BorderSide.none,
                          )).toList(),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildInfoItem('Ngân sách', (budgetMin > 0 || budgetMax > 0) 
                              ? '${currencyFormat.format(budgetMin)} - ${currencyFormat.format(budgetMax)}'
                              : 'Chưa thiết lập'),
                          _buildInfoItem('Khu vực', preferredAreas.isNotEmpty ? preferredAreas.join(', ') : 'Chưa thiết lập'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (role == 'admin')
                        _buildMenuItem(
                          icon: Icons.admin_panel_settings,
                          title: 'Quản trị viên: Duyệt bài',
                          color: Colors.orange,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminModerationPage())),
                        ),
                      _buildMenuItem(
                        icon: Icons.calculate_outlined, // Icon cho máy tính
                        title: 'Máy tính chi phí phòng',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CostCalculatorPage())),
                      ),
                      _buildMenuItem(
                        icon: Icons.list_alt,
                        title: 'Bài đăng của tôi',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostsPage())),
                      ),
                      _buildMenuItem(
                        icon: Icons.bookmark_border,
                        title: 'Bài đã lưu',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPostsPage())),
                      ),
                      _buildMenuItem(
                        icon: Icons.edit_outlined,
                        title: 'Chỉnh sửa hồ sơ',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage())),
                      ),
                      _buildMenuItem(
                        icon: Icons.logout,
                        title: 'Đăng xuất',
                        color: Colors.red,
                        onTap: () => authService.signOut(),
                      ),
                      _buildMenuItem(
                        icon: Icons.calendar_month,
                        title: 'Quản lý lịch hẹn',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BookingManagementPage())
                        ),
                      ),
                    ],
                  ),
                ),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
