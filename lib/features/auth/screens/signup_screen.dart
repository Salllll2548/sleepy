import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../onboarding/screens/pre_drive_setup_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _authService = AuthService();

  bool _isLoading = false;
  static const Color primaryColor = Color(0xFF0C897E);
  static const Color backgroundColor = Color(0xFFFFF0F0);

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12,
        color: Colors.black87,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE6E6E6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE6E6E6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: primaryColor,
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final dateOfBirth = _dateController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        dateOfBirth.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง'),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password ต้องมีอย่างน้อย 6 ตัวอักษร',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final error = await _authService.signUp(
      firstName: firstName,
      lastName: lastName,
      email: email,
      dateOfBirth: dateOfBirth,
      phone: phone,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('สมัครสมาชิกสำเร็จ'),
          content: Text(
            'เราได้ส่งอีเมลยืนยันไปที่\n'
            '$email\n\n'
            'กรุณาเปิด Gmail และกดลิงก์ Verify Email ก่อนเข้าสู่ระบบ',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'ไปหน้า Login',
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dateController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Green background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 305,
              child: Container(
                color: primaryColor,
              ),
            ),

            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 45),

                  // Back
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Already have an account? Log In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),

                  const SizedBox(height: 35),

                  // White Card
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      children: [
                        // First + Last Name
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _firstNameController,
                                decoration: _decoration('First name'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _lastNameController,
                                decoration: _decoration('Last name'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Email
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _decoration('Email'),
                        ),

                        const SizedBox(height: 12),

                        // Date
                        TextField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: _decoration(
                            'Date of birth',
                          ).copyWith(
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 17,
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              initialDate: DateTime(2000),
                            );

                            if (date != null) {
                              _dateController.text =
                                  '${date.day.toString().padLeft(2, '0')}/'
                                  '${date.month.toString().padLeft(2, '0')}/'
                                  '${date.year}';
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        // Phone
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _decoration(
                            '+66  Phone number',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Password
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _decoration(
                            'Password',
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Sign Up button
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              disabledBackgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // OR
                        Row(
                          children: const [
                            Expanded(
                              child: Divider(),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'Or',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Google
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() {
                                      _isLoading = true;
                                    });

                                    final error =
                                        await _authService.signInWithGoogle();

                                    if (!mounted) return;

                                    setState(() {
                                      _isLoading = false;
                                    });

                                    if (error == null) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PreDriveSetupScreen(),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(error),
                                        ),
                                      );
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFE5E5E5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'G',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Sign up with Google',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
