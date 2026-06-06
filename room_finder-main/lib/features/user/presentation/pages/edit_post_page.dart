import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/moderation/image_moderation_service.dart';
import '../../../../core/moderation/moderation_result.dart';
import '../../../../core/moderation/text_moderation_service.dart';
import '../../../../data/models/listing_model.dart';
import '../../../../data/services/location_service.dart';
import '../../../../data/services/storage_service.dart';
import 'location_picker_page.dart';

class EditPostPage extends StatefulWidget {
  final ListingModel post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _addressController;
  late final TextEditingController _electricPriceController;
  late final TextEditingController _waterPriceController;
  late final TextEditingController _serviceFeeController;
  late final TextEditingController _otherFeeController;

  final TextModerationService _textModerationService = TextModerationService();
  final ImageModerationService _imageModerationService =
      ImageModerationService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  late GeoPoint _location;
  late Map<String, String> _addressComponents;
  late List<String> _currentImageUrls;
  final List<File> _selectedImages = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _descriptionController =
        TextEditingController(text: widget.post.description);
    _priceController =
        TextEditingController(text: widget.post.price.toStringAsFixed(0));
    _addressController = TextEditingController(text: widget.post.address);
    _electricPriceController = TextEditingController(
      text: widget.post.electricPrice.toStringAsFixed(0),
    );
    _waterPriceController =
        TextEditingController(text: widget.post.waterPrice.toStringAsFixed(0));
    _serviceFeeController =
        TextEditingController(text: widget.post.serviceFee.toStringAsFixed(0));
    _otherFeeController =
        TextEditingController(text: widget.post.otherFee.toStringAsFixed(0));
    _location = widget.post.location;
    _addressComponents =
        Map<String, String>.from(widget.post.addressComponents);
    _currentImageUrls = List<String>.from(widget.post.mediaUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _electricPriceController.dispose();
    _waterPriceController.dispose();
    _serviceFeeController.dispose();
    _otherFeeController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: _location,
          initialAddress: _addressController.text,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _location = picked.point;
      _addressController.text = picked.address;
      _addressComponents = picked.addressComponents;
    });
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;
    if (!mounted) return;
    if (images.length > ImageModerationService.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chi duoc chon toi da ${ImageModerationService.maxImages} anh.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(images.map((image) => File(image.path)));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final resolvedAddress = await LocationService().resolve(
        point: _location,
        address: _addressController.text,
      );
      if (resolvedAddress == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Khong the xac dinh dia chi nay.')),
        );
        return;
      }

      final textResult = await _textModerationService.moderateListing(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        address: resolvedAddress.address,
      );
      if (!textResult.passed) {
        _showModerationMessage(
          textResult,
          fallback: 'Noi dung co chua tu ngu nhay cam. Vui long chinh sua lai.',
        );
        return;
      }

      var imageUrls = List<String>.from(_currentImageUrls);
      var imageResult = ModerationResult.passed(
        message: 'Khong thay doi anh bai dang.',
        details: const {'source': 'existing_images'},
      );
      if (_selectedImages.isNotEmpty) {
        imageResult =
            await _imageModerationService.moderateImages(_selectedImages);
        if (!imageResult.passed) {
          _showModerationMessage(
            imageResult,
            fallback: 'Anh khong hop le. Vui long tai anh khac.',
          );
          return;
        }
        imageUrls = await _storageService.uploadPostImages(
          widget.post.id,
          _selectedImages,
        );
      }

      if (widget.post.postType == PostType.roomForRent && imageUrls.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Can it nhat 1 anh cho bai dang.')),
        );
        return;
      }

      _location = resolvedAddress.point;
      _addressComponents = resolvedAddress.components;

      final approvedResult = ModerationResult.passed(
        message: 'Bai dang da duoc kiem duyet va cap nhat cong khai.',
        details: {
          'checkedBy': 'gemini_api',
          'textResult': textResult.toMap(),
          'imageResult': imageResult.toMap(),
        },
      );

      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.post.id)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _parseNumber(_priceController.text),
        'address': resolvedAddress.address,
        'addressComponents': _addressComponents,
        'location': {'geopoint': _location},
        'mediaUrls': imageUrls,
        'electricPrice': _parseNumber(_electricPriceController.text),
        'waterPrice': _parseNumber(_waterPriceController.text),
        'serviceFee': _parseNumber(_serviceFeeController.text),
        'otherFee': _parseNumber(_otherFeeController.text),
        'status': ListingStatus.published.name,
        'moderationComment': null,
        'moderationStatus': ModerationStatus.approved.firestoreValue,
        'moderationResult': approvedResult.toMap(),
        'moderationCheckedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da cap nhat bai viet.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khong the cap nhat: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showModerationMessage(
    ModerationResult result, {
    required String fallback,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(result.message.isEmpty ? fallback : result.message)),
    );
  }

  double _parseNumber(String value) =>
      double.tryParse(value.replaceAll(',', '').trim()) ?? 0;

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Khong duoc de trong';
    }
    return null;
  }

  String? _validPositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Khong duoc de trong';
    }
    final number = double.tryParse(value.replaceAll(',', '').trim());
    if (number == null) return 'Vui long nhap so hop le';
    if (number <= 0) return 'Phai lon hon 0';
    return null;
  }

  String? _validRoomPrice(String? value) {
    final positiveError = _validPositiveNumber(value);
    if (positiveError != null) return positiveError;

    final number = double.parse(value!.replaceAll(',', '').trim());
    if (number < 1000000) {
      return 'Gia phong toi thieu la 1,000,000 VND';
    }
    return null;
  }

  String? _validOptionalNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = double.tryParse(text.replaceAll(',', ''));
    if (number == null) return 'Vui long nhap so hop le';
    if (number < 0) return 'Khong duoc nhap so am';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chinh sua bai viet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Luu'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                _titleController,
                'Tieu de',
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _descriptionController,
                'Mo ta',
                maxLines: 4,
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _priceController,
                'Gia thue / thang',
                keyboardType: TextInputType.number,
                validator: widget.post.postType == PostType.roomForRent
                    ? _validRoomPrice
                    : _validPositiveNumber,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _addressController,
                'Dia chi',
                maxLines: 2,
                validator: _requiredText,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Chon lai vi tri tren ban do'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hinh anh',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildImagePicker(),
              const SizedBox(height: 20),
              const Text(
                'Chi phi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _electricPriceController,
                      'Dien/kWh',
                      keyboardType: TextInputType.number,
                      validator: _validOptionalNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _waterPriceController,
                      'Nuoc/m3',
                      keyboardType: TextInputType.number,
                      validator: _validOptionalNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _serviceFeeController,
                      'Phi dich vu',
                      keyboardType: TextInputType.number,
                      validator: _validOptionalNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _otherFeeController,
                      'Phi khac',
                      keyboardType: TextInputType.number,
                      validator: _validOptionalNumber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasSelectedImages = _selectedImages.isNotEmpty;
    final imageCount =
        hasSelectedImages ? _selectedImages.length : _currentImageUrls.length;

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageCount + 1,
        itemBuilder: (context, index) {
          if (index == imageCount) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Icon(
                  imageCount == 0
                      ? Icons.add_a_photo_outlined
                      : Icons.change_circle_outlined,
                  color: Colors.grey,
                  size: 30,
                ),
              ),
            );
          }

          if (hasSelectedImages) {
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
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedImages.removeAt(index);
                      }),
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
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentImageUrls[index],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
