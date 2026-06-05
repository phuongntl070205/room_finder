import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _messages = true;
  bool _postUpdates = true;
  bool _recommendations = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _messages = prefs.getBool('notify_messages') ?? true;
      _postUpdates = prefs.getBool('notify_post_updates') ?? true;
      _recommendations = prefs.getBool('notify_recommendations') ?? false;
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
      appBar: AppBar(title: const Text('Cài đặt thông báo', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        children: [
          SwitchListTile(
            value: _messages,
            onChanged: (value) => _setValue('notify_messages', value, (v) => _messages = v),
            title: const Text('Tin nhắn mới'),
            subtitle: const Text('Nhận thông báo khi có người nhắn tin'),
          ),
          SwitchListTile(
            value: _postUpdates,
            onChanged: (value) => _setValue('notify_post_updates', value, (v) => _postUpdates = v),
            title: const Text('Trạng thái bài đăng'),
            subtitle: const Text('Duyệt, từ chối hoặc cập nhật liên quan tới bài đăng'),
          ),
          SwitchListTile(
            value: _recommendations,
            onChanged: (value) => _setValue('notify_recommendations', value, (v) => _recommendations = v),
            title: const Text('Gợi ý phòng phù hợp'),
            subtitle: const Text('Nhận gợi ý dựa trên khu vực và ngân sách của bạn'),
          ),
        ],
      ),
    );
  }
}
