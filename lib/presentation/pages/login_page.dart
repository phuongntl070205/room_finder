import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[400]!, Colors.blue[800]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( // Fix overflow tại đây
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.home_work, size: 80, color: Colors.blue),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Room Finder Social',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Kết nối người tìm trọ & chủ trọ\nTìm bạn ở ghép thông minh',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 100),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await authService.signInWithGoogle();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đăng nhập thất bại: $e')),
                        );
                      }
                    }
                  },
                  icon: SizedBox(
                    width: 24,
                    height: 24,
                    child: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  label: const Text(
                    'Tiếp tục với Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bằng cách đăng nhập, bạn đồng ý với các điều khoản của chúng tôi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
