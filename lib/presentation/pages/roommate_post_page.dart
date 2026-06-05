import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/post_service.dart';
import '../../data/services/storage_service.dart';

class RoommatePostPage extends StatefulWidget {
  const RoommatePostPage({super.key});

  @override
  State<RoommatePostPage> createState() => _RoommatePostPageState();
}

class _RoommatePostPageState extends State<RoommatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _habitInputController = TextEditingController();

  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];

  bool _isLoading = false;
  List<String> _selectedHabits = [];
  List<String> _selectedAreas = [];

  final List<String> _wardOptions = [
    'Phường Tân Sơn Nhì', 'Phường Tây Thạnh', 'Phường Sơn Kỳ',
    'Phường Tân Quý', 'Phường Tân Thành', 'Phường Phú Thọ Hòa',
    'Phường Phú Thạnh', 'Phường Phú Trung', 'Phường Hòa Thạnh',
    'Phường Hiệp Tân', 'Phường Tân Thới Hòa'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _habitInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((e) => File(e.path)).toList());
      });
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      final postRef = FirebaseFirestore.instance.collection('listings').doc();
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _storageService.uploadPostImages(postRef.id, _selectedImages);
      }

      final post = ListingModel(
        id: postRef.id,
        authorId: user.uid,
        postType: PostType.roommateWanted,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_budgetController.text.replaceAll(',', '')) ?? 0,
        status: ListingStatus.pending,
        location: const GeoPoint(0, 0),
        address: _selectedAreas.join(', '),
        mediaUrls: imageUrls,
        createdAt: DateTime.now(),
        electricPrice: 0, waterPrice: 0, serviceFee: 0, otherFee: 0,
      );

      await PostService().createPost(post);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng bài thành công!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm bạn ở ghép', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hình ảnh thực tế
              const Text('Hình ảnh thực tế', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildImagePicker(),
              const SizedBox(height: 20),

              // 2. Tiêu đề
              const Text('Tiêu đề', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'Ví dụ: Tìm bạn ở ghép Lê Trọng Tấn', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Nhập tiêu đề' : null,
              ),
              const SizedBox(height: 16),

              // 3. Mô tả
              const Text('Mô tả chi tiết', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Yêu cầu về người ở ghép...', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Nhập mô tả' : null,
              ),
              const SizedBox(height: 16),

              // 4. Ngân sách
              const Text('Ngân sách bạn cần có (VNĐ)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Nhập số tiền', border: OutlineInputBorder(), suffixText: ''),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập ngân sách';
                  }
                  // Loại bỏ dấu phẩy để lấy số thực
                  final amount = double.tryParse(value.replaceAll(',', ''));
                  if (amount == null) {
                    return 'Giá trị không hợp lệ';
                  }
                  // Kiểm tra điều kiện tối thiểu 1 triệu
                  if (amount < 1000000) {
                    return 'Ngân sách tối thiểu phải là 1,000,000 VNĐ';
                  }
                  return null;
                },
                onChanged: (v) {
                  final formatted = _formatCurrency(v);
                  if (formatted != v) {
                    _budgetController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                  }
                },
              ),
              const SizedBox(height: 16),

              // 5. Phường tại Tân Phú
              const Text('Phường tại Tân Phú', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _wardOptions.map((ward) => FilterChip(
                  label: Text(ward),
                  selected: _selectedAreas.contains(ward),
                  onSelected: (s) => setState(() => s ? _selectedAreas.add(ward) : _selectedAreas.remove(ward)),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // 6. Sở thích
              const Text('Sở thích ở ghép', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _habitInputController,
                      decoration: const InputDecoration(hintText: 'Nhập sở thích...'),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add), onPressed: () {
                    if (_habitInputController.text.isNotEmpty) {
                      setState(() {
                        _selectedHabits.add(_habitInputController.text.trim());
                        _habitInputController.clear();
                      });
                    }
                  }),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _selectedHabits.map((h) => Chip(label: Text(h), onDeleted: () => setState(() => _selectedHabits.remove(h)))).toList(),
              ),
              const SizedBox(height: 30),

              // 7. Nút đăng bài
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPost,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ĐĂNG BÀI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Khung chọn ảnh
  Widget _buildImagePicker() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 30),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_selectedImages[index], width: 100, height: 100, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  String _formatCurrency(String value) {
    final clean = value.replaceAll(',', '');
    if (clean.isEmpty) return '';
    return NumberFormat('#,###').format(int.tryParse(clean) ?? 0);
  }
}