import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/moderation/image_moderation_service.dart';
import '../../core/moderation/moderation_result.dart';
import '../../core/moderation/text_moderation_service.dart';
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
  final TextModerationService _textModerationService = TextModerationService();
  final ImageModerationService _imageModerationService =
      ImageModerationService();
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];

  bool _isLoading = false;
  final List<String> _selectedHabits = [];
  final List<String> _selectedAreas = [];

  final List<String> _wardOptions = [
    'Phường Tân Sơn Nhì',
    'Phường Tây Thạnh',
    'Phường Sơn Kỳ',
    'Phường Tân Quý',
    'Phường Tân Thạnh',
    'Phường Phú Thọ Hòa',
    'Phường Phú Thạnh',
    'Phường Phú Trung',
    'Phường Hòa Thạnh',
    'Phường Hiệp Tân',
    'Phường Tân Thới Hòa',
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
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;
    if (!mounted) return;

    final total = _selectedImages.length + images.length;
    if (total > ImageModerationService.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ được chọn tối đa 10 ảnh.')),
      );
      return;
    }

    setState(() {
      _selectedImages.addAll(images.map((image) => File(image.path)));
    });
  }

  Future<void> _submitPost() => _submitPostModerated();

  Future<void> _submitPostModerated() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn cần đăng nhập để đăng bài.')),
        );
        return;
      }

      final postRef = FirebaseFirestore.instance.collection('listings').doc();
      final title = _titleController.text.trim();
      final address = _selectedAreas.join(', ');
      final description = [
        _descriptionController.text.trim(),
        if (_selectedHabits.isNotEmpty)
          'Sở thích: ${_selectedHabits.join(', ')}',
      ].join('\n');

      final textResult = await _textModerationService.moderateListing(
        title: title,
        description: description,
        address: address,
      );
      if (!textResult.passed) {
        _showViolation(
          textResult.message,
          'Nội dung có chứa từ ngữ nhạy cảm. Vui lòng chỉnh sửa lại.',
        );
        return;
      }

      ModerationResult imageResult = ModerationResult.passed(
        message: 'Bài đăng không có ảnh cần kiểm duyệt.',
        details: const {'source': 'no_images'},
      );
      if (_selectedImages.isNotEmpty) {
        imageResult =
            await _imageModerationService.moderateImages(_selectedImages);
        if (!imageResult.passed) {
          _showViolation(
            imageResult.message,
            'Ảnh không hợp lệ. Vui lòng tải ảnh khác.',
          );
          return;
        }
      }

      final imageUrls = _selectedImages.isEmpty
          ? <String>[]
          : await _storageService.uploadPostImages(
              postRef.id,
              _selectedImages,
            );

      final approvedResult = ModerationResult.passed(
        message: 'Bài đăng đã được kiểm duyệt và đăng công khai.',
        details: {
          'checkedBy': 'gemini_api',
          'textResult': textResult.toMap(),
          'imageResult': imageResult.toMap(),
        },
      );

      await PostService().createPost(
        _buildPost(
          id: postRef.id,
          authorId: user.uid,
          title: title,
          description: description,
          address: address,
          mediaUrls: imageUrls,
          moderationResult: approvedResult,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng bài thành công!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đăng bài: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ListingModel _buildPost({
    required String id,
    required String authorId,
    required String title,
    required String description,
    required String address,
    required List<String> mediaUrls,
    required ModerationResult moderationResult,
  }) {
    final now = DateTime.now();
    return ListingModel(
      id: id,
      authorId: authorId,
      postType: PostType.roommateWanted,
      title: title,
      description: description,
      price: _parseNumber(_budgetController.text),
      status: ListingStatus.published,
      location: const GeoPoint(0, 0),
      address: address,
      mediaUrls: mediaUrls,
      createdAt: now,
      updatedAt: now,
      moderationComment: null,
      moderationStatus: ModerationStatus.approved,
      moderationResult: moderationResult.toMap(),
      moderationCheckedAt: now,
    );
  }

  void _showViolation(String message, String fallback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.isEmpty ? fallback : message)),
    );
  }

  double _parseNumber(String value) =>
      double.tryParse(value.replaceAll(',', '').trim()) ?? 0;

  String? _validateBudget(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập ngân sách';
    }
    final amount = _parseNumber(value);
    if (amount <= 0) return 'Ngân sách phải lớn hơn 0';
    if (amount < 1000000) {
      return 'Ngân sách tối thiểu là 1.000.000 VND';
    }
    return null;
  }

  String _formatCurrency(String value) {
    final clean = value.replaceAll(',', '');
    if (clean.isEmpty) return '';
    return NumberFormat('#,###').format(int.tryParse(clean) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tìm bạn ở ghép',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hình ảnh thực tế (không bắt buộc)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildImagePicker(),
              const SizedBox(height: 20),
              const Text(
                'Tiêu đề',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: Tìm bạn ở ghép Lê Trọng Tấn',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Nhập tiêu đề' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Mô tả chi tiết',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Yêu cầu về người ở ghép...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Nhập mô tả' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ngân sách bạn cần có (VND)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Nhập số tiền',
                  border: OutlineInputBorder(),
                ),
                validator: _validateBudget,
                onChanged: (value) {
                  final formatted = _formatCurrency(value);
                  if (formatted != value) {
                    _budgetController.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Phường tại Tân Phú',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _wardOptions
                    .map(
                      (ward) => FilterChip(
                        label: Text(ward),
                        selected: _selectedAreas.contains(ward),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAreas.add(ward);
                            } else {
                              _selectedAreas.remove(ward);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sở thích ở ghép',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _habitInputController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập sở thích...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final habit = _habitInputController.text.trim();
                      if (habit.isEmpty) return;
                      setState(() {
                        _selectedHabits.add(habit);
                        _habitInputController.clear();
                      });
                    },
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _selectedHabits
                    .map(
                      (habit) => Chip(
                        label: Text(habit),
                        onDeleted: () =>
                            setState(() => _selectedHabits.remove(habit)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPost,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ĐĂNG BÀI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: Colors.grey,
                  size: 30,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImages[index],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedImages.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
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
