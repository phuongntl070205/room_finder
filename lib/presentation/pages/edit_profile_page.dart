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
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _areaController = TextEditingController();
  
  final List<String> _habitTags = [];
  final List<String> _preferredAreas = [];
  bool _isLoading = false;

  final List<String> _availableHabits = [
    'Không hút thuốc', 'Có thú cưng', 'Giờ giấc tự do', 
    'Sạch sẽ', 'Thân thiện', 'Yên tĩnh', 'Thường xuyên nấu ăn'
  ];

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
          _budgetMinController.text = userData.budgetMin.toString();
          _budgetMaxController.text = userData.budgetMax.toString();
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
          'budgetMin': double.tryParse(_budgetMinController.text) ?? 0,
          'budgetMax': double.tryParse(_budgetMaxController.text) ?? 0,
          'preferredAreas': _preferredAreas,
          'habitTags': _habitTags,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
          );
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
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  const Text('Ngân sách dự kiến', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _budgetMinController,
                          decoration: const InputDecoration(labelText: 'Tối thiểu', border: OutlineInputBorder(), suffixText: '₫'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _budgetMaxController,
                          decoration: const InputDecoration(labelText: 'Tối đa', border: OutlineInputBorder(), suffixText: '₫'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Khu vực quan tâm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _areaController,
                          decoration: const InputDecoration(labelText: 'Thêm khu vực (VD: Quận 1)', border: OutlineInputBorder()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () {
                          if (_areaController.text.isNotEmpty) {
                            setState(() {
                              _preferredAreas.add(_areaController.text.trim());
                              _areaController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _preferredAreas.map((area) => Chip(
                      label: Text(area),
                      onDeleted: () => setState(() => _preferredAreas.remove(area)),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Habit Tags (Sở thích ở)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _availableHabits.map((habit) {
                      final isSelected = _habitTags.contains(habit);
                      return FilterChip(
                        label: Text(habit),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _habitTags.add(habit);
                            } else {
                              _habitTags.remove(habit);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('LƯU THAY ĐỔI'),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
    );
  }
}
