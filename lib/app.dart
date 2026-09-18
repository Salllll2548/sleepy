import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';

/// ใช้ navigatorKey เพื่อให้ NotificationService สั่ง navigate ได้แม้ตอนที่
/// callback มาจาก native/notification tap ซึ่งไม่มี BuildContext ตรง ๆ
final navigatorKey = GlobalKey<NavigatorState>();

class DrowsinessApp extends StatelessWidget {
  const DrowsinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ตรวจจับอาการหลับใน',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
