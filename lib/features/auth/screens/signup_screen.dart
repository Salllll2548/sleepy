import 'package:flutter/material.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/auth_service.dart';
import '../../onboarding/screens/pre_drive_setup_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await _authService.signUp(
      name: _nameController.text,
      username: _usernameController.text,
      email: _usernameController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PreDriveSetupScreen()),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Sign-up',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 16),
              // จุดสีตกแต่งตามดีไซน์ (เขียว/แดง/ชมพู)
              const Row(
                children: [
                  CircleAvatar(radius: 14, backgroundColor: Color(0xFFA8E063)),
                  SizedBox(width: 8),
                  CircleAvatar(radius: 18, backgroundColor: Color(0xFFE57373)),
                  SizedBox(width: 8),
                  CircleAvatar(radius: 12, backgroundColor: Color(0xFFF3B6E0)),
                ],
              ),
              const SizedBox(height: 24),
              AppTextField(label: 'Name', controller: _nameController),
              const SizedBox(height: 12),
              AppTextField(label: 'Username', controller: _usernameController),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Confirm password',
                controller: _confirmPasswordController,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Sign-up',
                onPressed: _handleSignUp,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
