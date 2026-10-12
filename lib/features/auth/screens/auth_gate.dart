import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/navigation/main_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // ตรวจสอบสถานะการ Log in จาก FirebaseAuth
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 1. ระหว่างรอโหลดสถานะ
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. ถ้ายังไม่ได้ Log in -> ไปหน้า LoginScreen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        // 3. ถ้า Log in เรียบร้อยแล้ว -> ส่งเข้าหน้าหลัก (MainShell) ทันที
        return const MainShell();
      },
    );
  }
}