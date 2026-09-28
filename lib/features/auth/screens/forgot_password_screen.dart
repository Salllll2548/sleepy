import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color primaryColor = Color(0xFF0C897E);
  static const Color backgroundColor = Color(0xFFFFF0F0);

  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอก Gmail'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final error = await _authService.resetPassword(
      email: email,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (error == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ส่งอีเมลแล้ว'),
          content: Text(
            'เราได้ส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปที่\n$email\n\n'
            'กรุณาเปิด Gmail แล้วกดลิงก์ในอีเมล',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'ตกลง',
                style: TextStyle(
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Forgot Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'กรอก Gmail ที่ใช้สมัครสมาชิก\n'
              'เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Gmail',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        'Send Reset Email',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
