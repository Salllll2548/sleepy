import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/risk_levels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/drive_session_model.dart';
import '../../driving/screens/driving_detection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // =========================
  // Firebase User Name
  // =========================

  String _userName = 'กำลังโหลด...';

  // =========================
  // Driving Session
  // =========================

  DriveSession? _lastSession;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  // =========================
  // Load Name From Firestore
  // =========================

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _userName = 'ผู้ใช้';
      });

      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();

        final firstName = data?['firstName'] ?? '';
        final lastName = data?['lastName'] ?? '';

        final fullName = '$firstName $lastName'.trim();

        setState(() {
          _userName = fullName.isEmpty ? 'ผู้ใช้' : fullName;
        });
      } else {
        // ถ้าไม่มีข้อมูลใน Firestore
        setState(() {
          _userName = user.displayName ?? 'ผู้ใช้';
        });
      }
    } catch (e) {
      if (!mounted) return;

      // ถ้าอ่าน Firestore ไม่สำเร็จ
      // ใช้ชื่อจาก Firebase Authentication แทน
      setState(() {
        _userName = user.displayName ?? 'ผู้ใช้';
      });
    }
  }

  // =========================
  // Start Driving
  // =========================

  Future<void> _saveSessionToFirestore(DriveSession session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .add({
        'startedAt': Timestamp.fromDate(session.startedAt),
        'elapsedSeconds': session.elapsed.inSeconds,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('บันทึกทริปลง Firestore สำเร็จ!');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกทริป: $e');
    }
  }

  // 2. เรียกใช้ใน _startDriving
  Future<void> _startDriving() async {
    final result = await Navigator.push<DriveSession>(
      context,
      MaterialPageRoute(
        builder: (_) => const DrivingDetectionScreen(),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _lastSession = result;
      });

      // 💡 บันทึกข้อมูลทริปลง Firestore ทันทีที่ขับเสร็จ
      await _saveSessionToFirestore(result);

      print('ขับรถเสร็จสิ้น: ${_lastSession?.elapsedLabel}');
    }
  }
  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // User Name
            // =========================
            Text(
              'สวัสดี $_userName',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),

      // =========================
      // Body
      // =========================

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // Main Status (ปุ่มเริ่มต้นขับขี่)
          // =========================

          _MainStatusCard(
            onTap: _startDriving,
          ),

          const SizedBox(height: 16),

          // =========================
          // Risk Level
          // =========================

          const Text(
            'ระดับความเสี่ยง (Drowsiness Risk)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              for (final info in RiskLevels.all)
                Expanded(
                  child: _RiskLevelChip(
                    info: info,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Main Status Card (ปุ่มกดเริ่มต้น)
// ============================================================

class _MainStatusCard extends StatelessWidget {
  final VoidCallback onTap;

  const _MainStatusCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF133440), // สีพื้นหลังการ์ดเข้ม
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // 🟢 1. ปุ่มวงกลมตรงกลาง (ใส่ Padding รอบปุ่มเพื่อกำหนดความสูงการ์ดแทน)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Center(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 200,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF98D9CC), // สีเขียวพาสเทลวงกลม
                    border: Border.all(color: Colors.white, width: 3), // ขอบขาว
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF516F68),
                        offset: Offset(0, 8),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'PRESS TO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF133440),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF026D45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Start!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF67EF9B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'กดเพื่อเริ่มตรวจจับ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF133440),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Status Pill
// ============================================================

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Risk Level Chip
// ============================================================

class _RiskLevelChip extends StatelessWidget {
  final RiskLevelInfo info;

  const _RiskLevelChip({
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: info.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 4,
              backgroundColor: info.color,
            ),
            const SizedBox(height: 4),
            Text(
              info.rangeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: info.color,
              ),
            ),
            Text(
              info.nameLabel,
              style: const TextStyle(
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}