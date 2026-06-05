import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/admin_service.dart';

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Quản lý nội dung hệ thống', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chờ duyệt', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Tất cả bài đăng', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(),
          _buildAllPostsList(),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    return StreamBuilder<List<ListingModel>>(
      stream: _adminService.getPendingPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green[200]),
                const SizedBox(height: 16),
                const Text('Tuyệt vời! Không còn bài đăng nào chờ duyệt.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final post = snapshot.data![index];
            return _buildAdminPostCard(post);
          },
        );
      },
    );
  }

  Widget _buildAllPostsList() {
    return StreamBuilder<List<ListingModel>>(
      stream: _adminService.getAllPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Chưa có bài đăng nào trong hệ thống.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final post = snapshot.data![index];
            return _buildAdminPostCard(post, showStatus: true);
          },
        );
      },
    );
  }

  Widget _buildAdminPostCard(ListingModel post, {bool showStatus = false}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: ExpansionTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: post.mediaUrls.isNotEmpty 
            ? Image.network(post.mediaUrls.first, width: 60, height: 60, fit: BoxFit.cover)
            : Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image)),
        ),
        title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${post.postType == PostType.roomForRent ? "Phòng trọ" : "Ở ghép"} • ${currencyFormat.format(post.price)}',
                style: TextStyle(color: Colors.blue[700], fontSize: 13),
              ),
              if (showStatus) _statusChip(post.status),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _infoRow(Icons.person_outline, 'ID Tác giả:', post.authorId),
                _infoRow(Icons.location_on_outlined, 'Địa chỉ:', post.address),
                _infoRow(Icons.description_outlined, 'Mô tả:', post.description),
                if (post.moderationComment != null && post.moderationComment!.isNotEmpty)
                  _infoRow(Icons.info_outline, 'Lý do từ chối:', post.moderationComment!),
                const SizedBox(height: 20),
                _buildActionRow(post),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionRow(ListingModel post) {
    if (post.status == ListingStatus.closed) {
      return const Text('Bài đăng đã đóng.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
    }

    final actions = <Widget>[];

    if (post.status != ListingStatus.rejected) {
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRejectDialog(post.id),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text('Từ chối', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          ),
        ),
      );
    }

    if (post.status != ListingStatus.published) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
      actions.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _runAdminAction(
              () => _adminService.approvePost(post.id),
              'Đã phê duyệt bài đăng',
            ),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Phê duyệt', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
      );
    } else {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _runAdminAction(
              () => _adminService.closePost(post.id),
              'Đã đóng bài đăng',
            ),
            icon: const Icon(Icons.archive_outlined, color: Colors.grey),
            label: const Text('Đóng bài', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return Row(children: actions);
  }

  Future<bool> _runAdminAction(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể cập nhật bài đăng: $e')));
      return false;
    }
  }

  Widget _statusChip(ListingStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _statusLabel(ListingStatus status) {
    switch (status) {
      case ListingStatus.pending:
        return 'Chờ duyệt';
      case ListingStatus.published:
        return 'Đã duyệt';
      case ListingStatus.rejected:
        return 'Bị từ chối';
      case ListingStatus.closed:
        return 'Đã đóng';
    }
  }

  Color _statusColor(ListingStatus status) {
    switch (status) {
      case ListingStatus.pending:
        return Colors.orange;
      case ListingStatus.published:
        return Colors.green;
      case ListingStatus.rejected:
        return Colors.red;
      case ListingStatus.closed:
        return Colors.grey;
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _showRejectDialog(String postId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lý do từ chối bài đăng'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập lý do (VD: Thông tin sai sự thật, ảnh không phù hợp...)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do từ chối')),
                );
                return;
              }

              final success = await _runAdminAction(
                () => _adminService.rejectPost(postId, reason),
                'Đã từ chối bài đăng',
              );
              if (success && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xác nhận chặn bài'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
