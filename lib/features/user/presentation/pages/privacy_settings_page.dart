import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _showEmail = false;
  bool _showPhone = false;
  bool _allowProfileView = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showEmail = prefs.getBool('privacy_show_email') ?? false;
      _showPhone = prefs.getBool('privacy_show_phone') ?? false;
      _allowProfileView = prefs.getBool('privacy_allow_profile_view') ?? true;
    });
  }

  Future<void> _setValue(String key, bool value, void Function(bool) update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (mounted) setState(() => update(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quyền riêng tư', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        children: [
          SwitchListTile(
            value: _allowProfileView,
            onChanged: (value) => _setValue('privacy_allow_profile_view', value, (v) => _allowProfileView = v),
            title: const Text('Cho phép xem hồ sơ'),
            subtitle: const Text('Người dùng khác có thể mở trang hồ sơ của bạn'),
          ),
          SwitchListTile(
            value: _showEmail,
            onChanged: (value) => _setValue('privacy_show_email', value, (v) => _showEmail = v),
            title: const Text('Hiển thị email'),
            subtitle: const Text('Email sẽ xuất hiện trên hồ sơ công khai'),
          ),
          SwitchListTile(
            value: _showPhone,
            onChanged: (value) => _setValue('privacy_show_phone', value, (v) => _showPhone = v),
            title: const Text('Hiển thị số điện thoại'),
            subtitle: const Text('Chỉ nên bật khi bạn muốn người thuê liên hệ trực tiếp'),
          ),
        ],
      ),
    );
  }
}
