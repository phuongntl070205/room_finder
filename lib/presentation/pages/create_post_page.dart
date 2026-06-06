import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/moderation/image_moderation_service.dart';
import '../../core/moderation/moderation_result.dart';
import '../../core/moderation/text_moderation_service.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/storage_service.dart';
import '../../features/user/presentation/pages/location_picker_page.dart';
import 'post_preview_page.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();

  final _electricPriceController = TextEditingController();
  final _waterPriceController = TextEditingController();
  final _serviceFeeController = TextEditingController();
  final _otherFeeController = TextEditingController();

  final StorageService _storageService = StorageService();
  final TextModerationService _textModerationService = TextModerationService();
  final ImageModerationService _imageModerationService =
      ImageModerationService();
  final ImagePicker _picker = ImagePicker();

  final List<File> _selectedImages = [];
  final PostType _selectedPostType = PostType.roomForRent;
  GeoPoint? _selectedLocation;
  Map<String, String> _addressComponents = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _electricPriceController.dispose();
    _waterPriceController.dispose();
    _serviceFeeController.dispose();
    _otherFeeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
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
      _selectedImages.addAll(images.map((e) => File(e.path)).toList());
    });
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: _selectedLocation,
          initialAddress: _addressController.text,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedLocation = picked.point;
      _addressController.text = picked.address;
      _addressComponents = picked.addressComponents;
    });
  }

  Future<ResolvedAddress?> _resolveAddressForSubmit() async {
    try {
      return LocationService().resolve(
        point: _selectedLocation,
        address: _addressController.text,
      );
    } catch (_) {
      return null;
    }
  }

  ListingModel _buildPost({
    required String id,
    required String authorId,
    required ResolvedAddress resolvedAddress,
    required List<String> mediaUrls,
    required ModerationResult moderationResult,
  }) {
    final now = DateTime.now();
    return ListingModel(
      id: id,
      authorId: authorId,
      postType: _selectedPostType,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      price: _parseNumber(_priceController.text),
      status: ListingStatus.published,
      location: resolvedAddress.point,
      address: resolvedAddress.address,
      addressComponents: resolvedAddress.components,
      mediaUrls: mediaUrls,
      createdAt: now,
      updatedAt: now,
      moderationComment: null,
      moderationStatus: ModerationStatus.approved,
      moderationResult: moderationResult.toMap(),
      moderationCheckedAt: now,
      electricPrice: _parseNumber(_electricPriceController.text),
      waterPrice: _parseNumber(_waterPriceController.text),
      serviceFee: _parseNumber(_serviceFeeController.text),
      otherFee: _parseNumber(_otherFeeController.text),
    );
  }

  // ignore: unused_element
  Future<void> _submitPost() => _submitPostModerated();

  Future<void> _submitPostModerated() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần ít nhất 1 ảnh cho bài đăng.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn cần đăng nhập để đăng bài.')),
        );
        return;
      }

      final resolvedAddress = await _resolveAddressForSubmit();
      if (resolvedAddress == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng chọn vị trí hoặc nhập địa chỉ hợp lệ.'),
            ),
          );
        }
        return;
      }

      final postRef = FirebaseFirestore.instance.collection('listings').doc();
      final textResult = await _textModerationService.moderateListing(
        title: _titleController.text,
        description: _descController.text,
        address: resolvedAddress.address,
      );

      if (!textResult.passed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                textResult.message.isEmpty
                    ? 'Nội dung có chứa từ ngữ nhạy cảm. Vui lòng chỉnh sửa lại.'
                    : textResult.message,
              ),
            ),
          );
        }
        return;
      }

      final imageResult =
          await _imageModerationService.moderateImages(_selectedImages);
      if (!imageResult.passed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                imageResult.message.isEmpty
                    ? 'Ảnh không hợp lệ. Vui lòng tải ảnh khác.'
                    : imageResult.message,
              ),
            ),
          );
        }
        return;
      }

      final imageUrls =
          await _storageService.uploadPostImages(postRef.id, _selectedImages);
      _addressComponents = resolvedAddress.components;

      final approvedResult = ModerationResult.passed(
        message: 'Bài đăng đã được kiểm duyệt và đăng công khai.',
        details: {
          'checkedBy': 'gemini_api',
          'textResult': textResult.toMap(),
          'imageResult': imageResult.toMap(),
        },
      );

      final newPost = _buildPost(
        id: postRef.id,
        authorId: user.uid,
        resolvedAddress: resolvedAddress,
        mediaUrls: imageUrls,
        moderationResult: approvedResult,
      );

      await postRef.set(newPost.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng bài thành công!')),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng tin cho thuê',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => _showPreview(),
            child:
                const Text('Xem trước', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hình ảnh thực tế',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Thông tin cơ bản'),
                    _buildTextField(_titleController, 'Tiêu đề bài đăng'),
                    const SizedBox(height: 12),
                    _buildTextField(_descController, 'Mô tả chi tiết',
                        maxLines: 3),
                    const SizedBox(height: 12),
                    _buildTextField(_priceController, 'Giá thuê / tháng',
                        keyboardType: TextInputType.number,
                        minValue: 1000000,
                        minValueMessage:
                            'Giá phòng tối thiểu là 1.000.000 VND'),
                    const SizedBox(height: 12),
                    _buildTextField(_addressController, 'Địa chỉ',
                        icon: Icons.location_on, maxLines: 2),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(_selectedLocation == null
                          ? 'Chọn vị trí trên bản đồ'
                          : 'Đã chọn vị trí trên bản đồ'),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Dữ liệu tính chi phí mặc định'),
                    const Text(
                        'Thông tin này dùng để ước tính tổng chi phí hàng tháng cho người thuê.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(
                                _electricPriceController, 'Điện (VNĐ/kWh)',
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildTextField(
                                _waterPriceController, 'Nước (VNĐ/m3)',
                                keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(
                                _serviceFeeController, 'Phí dịch vụ',
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildTextField(
                                _otherFeeController, 'Phí khác',
                                keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _submitPostModerated,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ĐĂNG BÀI NGAY',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      IconData? icon,
      double? minValue,
      String? minValueMessage}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [
              FilteringTextInputFormatter.digitsOnly,
              ThousandsSeparatorInputFormatter(),
            ]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return 'Không được để trống';
        if (keyboardType == TextInputType.number) {
          final number = double.tryParse(value.replaceAll(',', ''));
          if (number == null) return 'Vui lòng nhập số hợp lệ';
          if (minValue != null && number < minValue) {
            return minValueMessage ?? 'Giá trị không hợp lệ';
          }
          if (number < 0) return 'Không được nhập số âm';
        }
        return null;
      },
    );
  }

  double _parseNumber(String value) =>
      double.tryParse(value.replaceAll(',', '').trim()) ?? 0;

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
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_a_photo, color: Colors.grey),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImages[index],
                      width: 100, height: 100, fit: BoxFit.cover),
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

  void _showPreview() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng đăng nhập để xem trước bài đăng')),
      );
      return;
    }

    final previewPost = ListingModel(
      id: '',
      authorId: user.uid,
      postType: _selectedPostType,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      price: _parseNumber(_priceController.text),
      status: ListingStatus.published,
      location: _selectedLocation ?? const GeoPoint(0, 0),
      address: _addressController.text.trim(),
      addressComponents: _addressComponents,
      mediaUrls: _selectedImages
          .map((file) => file.path)
          .toList(), // Temporary paths for preview
      createdAt: DateTime.now(),
      electricPrice: _parseNumber(_electricPriceController.text),
      waterPrice: _parseNumber(_waterPriceController.text),
      serviceFee: _parseNumber(_serviceFeeController.text),
      otherFee: _parseNumber(_otherFeeController.text),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PostPreviewPage(post: previewPost)),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Xử lý để tránh lỗi khi người dùng xóa hết hoặc nhập không phải số
    final intValue = int.tryParse(newValue.text.replaceAll(',', ''));
    if (intValue == null) return oldValue;

    final formatter = NumberFormat('#,###', 'en_US');
    String newText = formatter.format(intValue);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
