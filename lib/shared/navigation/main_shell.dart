import 'package:flutter/material.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/stats/screens/stats_screen.dart';

/// ครอบ 3 หน้า (Home/Stats/Profile) ที่ใช้แถบล่างชุดเดียวกันตามดีไซน์
/// หน้า Login/Sign-up/Onboarding/Driving ไม่ผ่าน shell นี้เพราะเป็น flow แยก
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
