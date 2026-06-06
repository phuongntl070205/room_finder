import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Trợ giúp & Hỗ trợ',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HelpItem(
            icon: Icons.search,
            title: 'Tìm phòng',
            body:
                'Nhập khu vực, địa chỉ hoặc địa danh ở tab Khám phá để lọc bài đăng phù hợp.',
          ),
          _HelpItem(
            icon: Icons.map_outlined,
            title: 'Xem bản đồ',
            body:
                'Dùng chế độ bản đồ để xem vị trí phòng, khoảng cách và mở chỉ đường bằng Google Maps.',
          ),
          _HelpItem(
            icon: Icons.chat_bubble_outline,
            title: 'Liên hệ',
            body:
                'Mở chi tiết bài đăng rồi nhắn tin cho chủ bài. Nếu đó là bài của bạn, app sẽ hiển thị nút chỉnh sửa.',
          ),
          _HelpItem(
            icon: Icons.verified_outlined,
            title: 'Tu kiem duyet',
            body:
                'Bai dang moi se duoc he thong tu kiem duyet. Neu hop le, bai se hien thi cong khai ngay.',
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(body),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }
}
