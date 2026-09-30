import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/navigation/main_shell.dart';
import 'login_screen.dart';
import '../../onboarding/screens/pre_drive_setup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. ตรวจสอบว่ามีการ Log in อยู่ในเครื่องหรือไม่
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ [สเต็ปที่ 1] ถ้ายังไม่ได้ Log in หรือกด Sign Out ออกมา -> ต้องไปหน้า LoginScreen ก่อนเสมอ!
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final user = authSnapshot.data!;

        // 🟢 [สเต็ปที่ 2] Log in เรียบร้อยแล้ว -> ดึงข้อมูลใน Firestore มาเช็กต่อ
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final isCalibrated = userData?['isCalibrated'] ?? false;

            // ✅ [กรณีผู้ใช้เดิม] เคยสแกนใบหน้าแล้ว -> เข้าหน้าหลัก (MainShell) ทันที
            if (isCalibrated) {
              return const MainShell();
            }

            // 🟡 [กรณีผู้ใช้ใหม่] เพิ่ง Log in แต่ยังไม่ได้สแกนหน้า -> ส่งไปหน้าขอสิทธิ์ (PreDriveSetupScreen)
            return const PreDriveSetupScreen();
          },
        );
      },
    );
  }
}