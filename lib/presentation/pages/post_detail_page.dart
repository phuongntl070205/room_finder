import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/deep_link_service.dart';
import '../../data/services/post_service.dart';
import '../../data/services/chat_service.dart'; // Thêm import này
import '../../features/user/presentation/pages/comments_page.dart';
import '../../features/user/presentation/pages/edit_post_page.dart';
import '../../features/user/presentation/pages/share_post_page.dart';
import 'chat_detail_page.dart';
import 'user_profile_page.dart';

class PostDetailPage extends StatefulWidget {
  final ListingModel post;
  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _postService = PostService();
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = false; // Sẽ được cập nhật từ StreamBuilder
  }

  Future<void> _toggleSave() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để lưu bài')),
        );
      }
      return;
    }

    try {
      await _postService.toggleSavePost(
          currentUser.uid, widget.post.id, _isSaved);
      if (!mounted) return;
      setState(() {
        _isSaved = !_isSaved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isSaved ? 'Đã lưu bài đăng' : 'Đã bỏ lưu bài đăng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi khi lưu bài đăng')),
      );
    }
  }

  Future<void> _startChat(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin')),
      );
      return;
    }

    if (currentUser.uid == widget.post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không thể nhắn tin cho chính mình')),
      );
      return;
    }

    try {
      // Sử dụng ChatService để khởi tạo cuộc trò chuyện chuẩn hóa
      final chatService = ChatService();
      final chatId = await chatService.getOrCreateChat(widget.post.authorId,
          postId: widget.post.id);

      // Lấy thông tin người nhận để hiển thị tiêu đề chat
      final authorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post.authorId)
          .get();
      final authorData = authorDoc.data() as Map<String, dynamic>?;
      final authorName = authorData?['displayName'] ?? 'Người dùng';

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatId,
              otherUserName: authorName,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi kết nối: $e')),
        );
      }
    }
  }

  String _buildShareText() {
    final price = NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
        .format(widget.post.price);
    return '${widget.post.title}\n$price\n${widget.post.address}\n${DeepLinkService.postUri(widget.post.id)}';
  }

  void _sharePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SharePostSheet(
        post: widget.post,
        shareText: _buildShareText(),
      ),
    );
  }

  void _openEditPost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPostPage(post: widget.post)),
    );
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa bài đăng này không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _postService.deletePost(widget.post.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài đăng')),
        );
        Navigator.pop(context); // Quay lại trang trước đó
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa bài đăng: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bài đăng'),
        actions: [
          if (currentUser?.uid == widget.post.authorId) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEditPost,
              tooltip: 'Chỉnh sửa bài đăng',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deletePost,
              tooltip: 'Xóa bài đăng',
            ),
          ],
          IconButton(
              icon: const Icon(Icons.share_outlined), onPressed: _sharePost),
          StreamBuilder<DocumentSnapshot>(
            stream: currentUser != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Vui lòng đăng nhập để lưu bài')),
                  ),
                );
              }
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final savedIds =
                  List<String>.from(userData['savedPostIds'] ?? []);
              final isSaved = savedIds.contains(widget.post.id);
              if (_isSaved != isSaved) {
                _isSaved = isSaved;
              }
              return IconButton(
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.blue : null),
                onPressed: _toggleSave,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey[200],
              child: widget.post.mediaUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: widget.post.mediaUrls.length,
                      itemBuilder: (context, index) => Image.network(
                          widget.post.mediaUrls[index],
                          fit: BoxFit.cover),
                    )
                  : const Icon(Icons.image, size: 100, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currencyFormat.format(widget.post.price),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          widget.post.postType == PostType.roomForRent
                              ? 'Cho thuê'
                              : 'Tìm ở ghép',
                          style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(widget.post.title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(widget.post.address,
                              style: const TextStyle(color: Colors.grey))),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildCostEstimationSection(context, currencyFormat),
                  const Divider(height: 32),
                  const Text('Mô tả',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.post.description,
                      style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 24),
                  const Text('Tiện ích',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.post.amenities.entries
                        .where((e) => e.value)
                        .map((e) => Chip(
                              label: Text(e.key),
                              backgroundColor: Colors.grey[100],
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Vị trí',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(widget.post.location.latitude,
                              widget.post.location.longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('post-location'),
                            position: LatLng(widget.post.location.latitude,
                                widget.post.location.longitude),
                          ),
                        },
                        liteModeEnabled: true,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: true,
                        zoomControlsEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Phần bình luận
                  const Text('Bình luận',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('listings')
                        .doc(widget.post.id)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .limit(2)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return const Text('Không thể tải bình luận');
                      final comments = snapshot.data?.docs ?? [];

                      return Column(
                        children: [
                          if (comments.isEmpty)
                            const Text('Chưa có bình luận nào.',
                                style: TextStyle(color: Colors.grey))
                          else
                            ...comments.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 15,
                                  backgroundImage: data['authorAvatar'] != null
                                      ? NetworkImage(data['authorAvatar'])
                                      : null,
                                  child: data['authorAvatar'] == null
                                      ? const Icon(Icons.person, size: 15)
                                      : null,
                                ),
                                title: Text(data['authorName'] ?? 'Người dùng',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(data['text'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }),
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CommentsPage(
                                        postId: widget.post.id,
                                        postTitle: widget.post.title))),
                            child: const Text('Xem tất cả bình luận'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // Thông tin người đăng thực tế
                  const Text('Người đăng',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.post.authorId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final name = userData?['displayName'] ?? 'Người dùng';
                      final avatar = userData?['avatarUrl'];

                      return GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserProfilePage(userId: widget.post.authorId),
                            )),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundImage:
                                  avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const Text('Đã xác minh',
                                    style: TextStyle(
                                        color: Colors.green, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildCTA(context),
    );
  }

  Widget _buildCostEstimationSection(
      BuildContext context, NumberFormat format) {
    final electricCost =
        widget.post.electricPrice * widget.post.defaultElectricUsage;
    final waterCost = widget.post.waterPrice * widget.post.defaultWaterUsage;
    final estimatedTotal = widget.post.price +
        electricCost +
        waterCost +
        widget.post.serviceFee +
        widget.post.otherFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50]!.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng chi phí ước tính',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(format.format(estimatedTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          _costRow('Tiền phòng', format.format(widget.post.price)),
          _costRow('Điện (tạm tính)', format.format(electricCost)),
          _costRow('Nước (tạm tính)', format.format(waterCost)),
          _costRow('Phí dịch vụ', format.format(widget.post.serviceFee)),
          if (widget.post.otherFee > 0)
            _costRow('Phí khác', format.format(widget.post.otherFee)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showCostDetails(context, format),
            child: const Text('Xem cách tính chi tiết'),
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          const SizedBox(width: 12),
          Text(value),
        ],
      ),
    );
  }

  void _showCostDetails(BuildContext context, NumberFormat format) {
    final formKey = GlobalKey<FormState>();
    final electricUsageController = TextEditingController(
        text: widget.post.defaultElectricUsage.toStringAsFixed(0));
    final waterUsageController = TextEditingController(
        text: widget.post.defaultWaterUsage.toStringAsFixed(0));

    double parseUsage(TextEditingController controller) {
      return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    }

    String? validateUsage(String? value) {
      if (value == null || value.trim().isEmpty) return 'Không được để trống';
      final number = double.tryParse(value.trim().replaceAll(',', '.'));
      if (number == null) return 'Vui lòng nhập số hợp lệ';
      if (number < 0) return 'Không được nhập số âm';
      return null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final electricUsage = parseUsage(electricUsageController);
          final waterUsage = parseUsage(waterUsageController);
          final electricCost = widget.post.electricPrice * electricUsage;
          final waterCost = widget.post.waterPrice * waterUsage;
          final total = widget.post.price +
              electricCost +
              waterCost +
              widget.post.serviceFee +
              widget.post.otherFee;

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chi tiết cách tính',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: electricUsageController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Số kWh điện',
                                border: OutlineInputBorder()),
                            validator: validateUsage,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: waterUsageController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Số khối nước',
                                border: OutlineInputBorder()),
                            validator: validateUsage,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _costRow('Tiền phòng', format.format(widget.post.price)),
                    _costRow(
                        'Điện: ${format.format(widget.post.electricPrice)}/kWh x $electricUsage kWh',
                        format.format(electricCost)),
                    _costRow(
                        'Nước: ${format.format(widget.post.waterPrice)}/m3 x $waterUsage m3',
                        format.format(waterCost)),
                    _costRow(
                        'Phí dịch vụ', format.format(widget.post.serviceFee)),
                    if (widget.post.otherFee > 0)
                      _costRow('Phí khác', format.format(widget.post.otherFee)),
                    const Divider(height: 24),
                    _costRow('Tổng ước tính', format.format(total)),
                    const SizedBox(height: 12),
                    const Text(
                      '* Bạn có thể thay đổi số điện/nước để xem chi phí theo mức sử dụng thực tế.',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      electricUsageController.dispose();
      waterUsageController.dispose();
    });
  }

  Widget _buildCTA(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.post.authorId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isOwner ? _openEditPost : () => _startChat(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50)),
              child: Text(isOwner ? 'Chỉnh sửa bài viết' : 'Nhắn tin ngay'),
            ),
          ),
        ],
      ),
    );
  }
}
