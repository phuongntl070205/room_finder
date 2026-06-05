import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _budgetController = TextEditingController(); // Đã gộp
  final _habitInputController = TextEditingController(); // Thêm ô nhập sở thích

  final List<String> _habitTags = [];
  final List<String> _preferredAreas = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await AuthService().getUserData(user.uid);
      if (userData != null) {
        setState(() {
          _nameController.text = userData.displayName;
          _phoneController.text = userData.phoneNumber ?? '';
          _budgetController.text = (userData.budgetMax > 0) ? userData.budgetMax.toString() : '';
          _habitTags.addAll(userData.habitTags);
          _preferredAreas.addAll(userData.preferredAreas);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'displayName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'budget': double.tryParse(_budgetController.text) ?? 0, // Lưu 1 trường duy nhất
          'preferredAreas': _preferredAreas,
          'habitTags': _habitTags,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
          Navigator.pop(context);
        }
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
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thông tin cơ bản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()), keyboardType: TextInputType.phone),

              const SizedBox(height: 24),
              // Ô NGÂN SÁCH MỚI
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(labelText: 'Ngân sách bạn cần có (VNĐ)', border: OutlineInputBorder(), suffixText: '₫'),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 24),
              const Text('Sở thích ở ghép', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              // Ô NHẬP SỞ THÍCH MỚI
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _habitInputController,
                      decoration: const InputDecoration(labelText: 'Nhập sở thích mới...', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue),
                    onPressed: () {
                      if (_habitInputController.text.isNotEmpty) {
                        setState(() {
                          _habitTags.add(_habitInputController.text.trim());
                          _habitInputController.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _habitTags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _habitTags.remove(tag)),
                )).toList(),
              ),

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text('LƯU THAY ĐỔI'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}