import 'package:flutter/material.dart';
import 'create_post_page.dart';
import 'roommate_post_page.dart';

class PostChoicePage extends StatelessWidget {
  const PostChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn muốn đăng tin gì?', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView( // Thêm scroll để tránh overflow
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildChoiceCard(
              context,
              title: 'Cho thuê phòng',
              description: 'Tôi có phòng trống muốn cho thuê, tìm người thuê nhanh chóng.',
              icon: Icons.home_work,
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage())),
            ),
            const SizedBox(height: 20),
            _buildChoiceCard(
              context,
              title: 'Tìm phòng / Ở ghép',
              description: 'Tôi đang tìm phòng hoặc tìm bạn cùng sở thích để ở chung.',
              icon: Icons.people,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const RoommatePostPage())
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard(BuildContext context, {required String title, required String description, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
