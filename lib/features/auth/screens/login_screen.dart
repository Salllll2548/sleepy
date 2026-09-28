import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../onboarding/screens/pre_drive_setup_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  static const Color primaryColor = Color(0xFF0C897E);
  static const Color backgroundColor = Color(0xFFFFF0F0);

  // ============================================================
  // EMAIL / PASSWORD LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอก Gmail และ Password'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final error = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PreDriveSetupScreen(),
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

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    final error = await _authService.signInWithGoogle();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PreDriveSetupScreen(),
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
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(
          color: Color(0xFFE6E6E6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(
          color: Color(0xFFE6E6E6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.2,
        ),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // =========================
            // สีเขียวด้านบน
            // =========================
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 305,
              child: Container(
                decoration: const BoxDecoration(
                  color: primaryColor,
                ),
              ),
            ),

            // =========================
            // เนื้อหา
            // =========================
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Logo
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: primaryColor,
                      size: 27,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Sign in to your\nAccount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      height: 1.05,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Enter your email and password to log in',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),

                  const SizedBox(height: 35),

                  // =========================
                  // White Card
                  // =========================
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
                        // =========================
                        // GOOGLE LOGIN
                        // =========================
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFFE8E8E8),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: primaryColor,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        'G',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // =========================
                        // OR
                        // =========================
                        Row(
                          children: const [
                            Expanded(
                              child: Divider(
                                color: Color(0xFFE5E5E5),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'Or login with',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Color(0xFFE5E5E5),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // =========================
                        // EMAIL
                        // =========================
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            hint: 'Email',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =========================
                        // PASSWORD
                        // =========================
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            hint: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // =========================
                        // REMEMBER + FORGOT
                        // =========================
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Remember me',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Forgot Password ?',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // =========================
                        // LOGIN BUTTON
                        // =========================
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
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
                                    'Log In',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =========================
                        // SIGN UP
                        // =========================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
