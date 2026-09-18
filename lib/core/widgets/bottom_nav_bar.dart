import 'package:flutter/material.dart';

/// แถบล่าง เริ่ม/สถิติ/โปรไฟล์ ตามดีไซน์หน้า 4-8
/// ใช้ร่วมกับ MainShell ที่ควบคุม index ปัจจุบัน
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.power_settings_new_outlined),
          label: 'เริ่ม',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          label: 'สถิติ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'โปรไฟล์',
        ),
      ],
    );
  }
}
