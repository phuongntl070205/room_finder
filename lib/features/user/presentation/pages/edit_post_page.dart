import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/listing_model.dart';
import '../../../../data/services/location_service.dart';
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
  late GeoPoint _location;
  late Map<String, String> _addressComponents;
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
        text: widget.post.electricPrice.toStringAsFixed(0));
    _waterPriceController =
        TextEditingController(text: widget.post.waterPrice.toStringAsFixed(0));
    _serviceFeeController =
        TextEditingController(text: widget.post.serviceFee.toStringAsFixed(0));
    _otherFeeController =
        TextEditingController(text: widget.post.otherFee.toStringAsFixed(0));
    _location = widget.post.location;
    _addressComponents =
        Map<String, String>.from(widget.post.addressComponents);
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
          const SnackBar(content: Text('Khong the xac dinh dia chi nay')),
        );
        return;
      }
      _location = resolvedAddress.point;
      _addressComponents = resolvedAddress.components;

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
        'electricPrice': _parseNumber(_electricPriceController.text),
        'waterPrice': _parseNumber(_waterPriceController.text),
        'serviceFee': _parseNumber(_serviceFeeController.text),
        'otherFee': _parseNumber(_otherFeeController.text),
        'status': ListingStatus.pending.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã cập nhật bài viết. Bài sẽ chờ duyệt lại.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể cập nhật: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double _parseNumber(String value) =>
      double.tryParse(value.replaceAll(',', '').trim()) ?? 0;

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Không được để trống';
    return null;
  }

  String? _validNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Không được để trống';
    final number = double.tryParse(value.replaceAll(',', '').trim());
    if (number == null) return 'Vui lòng nhập số hợp lệ';
    if (number < 0) return 'Không được nhập số âm';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa bài viết',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lưu'),
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
              _buildTextField(_titleController, 'Tiêu đề',
                  validator: _requiredText),
              const SizedBox(height: 12),
              _buildTextField(_descriptionController, 'Mô tả',
                  maxLines: 4, validator: _requiredText),
              const SizedBox(height: 12),
              _buildTextField(_priceController, 'Giá thuê / tháng',
                  keyboardType: TextInputType.number, validator: _validNumber),
              const SizedBox(height: 12),
              _buildTextField(_addressController, 'Địa chỉ',
                  maxLines: 2, validator: _requiredText),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Chọn lại vị trí trên bản đồ'),
              ),
              const SizedBox(height: 20),
              const Text('Chi phí',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          _electricPriceController, 'Điện/kWh',
                          keyboardType: TextInputType.number,
                          validator: _validNumber)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTextField(_waterPriceController, 'Nước/m3',
                          keyboardType: TextInputType.number,
                          validator: _validNumber)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          _serviceFeeController, 'Phí dịch vụ',
                          keyboardType: TextInputType.number,
                          validator: _validNumber)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTextField(_otherFeeController, 'Phí khác',
                          keyboardType: TextInputType.number,
                          validator: _validNumber)),
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
}
