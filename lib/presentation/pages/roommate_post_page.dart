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
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _areaController = TextEditingController();

  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];

  bool _isLoading = false;
  List<String> _selectedHabits = [];
  List<String> _selectedAreas = [];

  final List<String> _habitOptions = [
    'Sạch sẽ', 'Yên tĩnh', 'Thân thiện', 'Học tập', 'Làm việc văn phòng',
    'Thể thao', 'Âm nhạc', 'Đi chơi', 'Nấu ăn', 'Không hút thuốc'
  ];

  final List<String> _areaOptions = [
    'Quận 1', 'Quận 3', 'Quận 7', 'Quận Bình Thạnh', 'Quận Tân Bình',
    'Quận Phú Nhuận', 'Quận Gò Vấp', 'Quận Tân Phú', 'Quận Thủ Đức',
    'Quận 9', 'Quận 12', 'Quận Bình Tân', 'Huyện Nhà Bè', 'Huyện Hóc Môn'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _areaController.dispose();
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
        title: _titleController.text.trim().isEmpty ? 'Tìm bạn ở ghép' : _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_budgetMaxController.text.replaceAll(',', '')) ?? 0,
        status: ListingStatus.pending,
        location: const GeoPoint(0, 0),
        address: _selectedAreas.isNotEmpty ? _selectedAreas.join(', ') : _areaController.text.trim(),
        mediaUrls: imageUrls,
        createdAt: DateTime.now(),
        electricPrice: 0,
        waterPrice: 0,
        serviceFee: 0,
        otherFee: 0,
      );

      await PostService().createPost(post);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng bài thành công!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm bạn ở ghép', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Đăng', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hình ảnh thực tế', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildImagePicker(),
              const SizedBox(height: 24),
              const Text('Tiêu đề', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: Tìm bạn ở ghép quận 7',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Vui lòng nhập tiêu đề' : null,
              ),
              const SizedBox(height: 20),

              const Text('Mô tả chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Mô tả về bản thân, sở thích, yêu cầu với bạn ở ghép...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Vui lòng nhập mô tả' : null,
              ),
              const SizedBox(height: 20),

              const Text('Ngân sách (VNĐ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMinController,
                      keyboardType: TextInputType.number,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: 'Từ',
                        suffixText: 'đ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final formatted = _formatCurrency(value);
                        if (formatted != value) {
                          _budgetMinController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final num = double.tryParse(v.replaceAll(',', ''));
                          if (num == null) return 'Lỗi';
                          if (num < 0) return 'Không được âm';
                          
                          final maxStr = _budgetMaxController.text.replaceAll(',', '');
                          if (maxStr.isNotEmpty) {
                            final maxNum = double.tryParse(maxStr);
                            if (maxNum != null && num > maxNum) {
                              return 'Phải nhỏ hơn Đến';
                            }
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMaxController,
                      keyboardType: TextInputType.number,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: 'Đến',
                        suffixText: 'đ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final formatted = _formatCurrency(value);
                        if (formatted != value) {
                          _budgetMaxController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nhập giá';
                        final num = double.tryParse(v.replaceAll(',', ''));
                        if (num == null) return 'Lỗi';
                        if (num < 0) return 'Không được âm';

                        final minStr = _budgetMinController.text.replaceAll(',', '');
                        if (minStr.isNotEmpty) {
                          final minNum = double.tryParse(minStr);
                          if (minNum != null && num < minNum) {
                            return 'Phải lớn hơn Từ';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text('Khu vực mong muốn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _areaOptions.map((area) => FilterChip(
                  label: Text(area),
                  selected: _selectedAreas.contains(area),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedAreas.add(area);
                      } else {
                        _selectedAreas.remove(area);
                      }
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),

              const Text('Sở thích & Phong cách sống', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _habitOptions.map((habit) => FilterChip(
                  label: Text(habit),
                  selected: _selectedHabits.contains(habit),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedHabits.add(habit);
                      } else {
                        _selectedHabits.remove(habit);
                      }
                    });
                  },
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(String value) {
    final cleanValue = value.replaceAll(',', '');
    if (cleanValue.isEmpty) return '';
    final number = int.tryParse(cleanValue);
    if (number == null) return value;
    return NumberFormat('#,###').format(number);
  }

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
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 30),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImages[index], width: 100, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImages.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
