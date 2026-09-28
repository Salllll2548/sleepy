import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ชื่อผู้ใช้จาก Firebase
  String _userName = 'กำลังโหลด...';

  // ข้อมูล Profile เดิม
  UserProfile _profile = const UserProfile(
    name: 'ผู้ใช้',
    faceVerified: true,
    bluetoothConnected: true,
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // โหลดชื่อจาก Firestore
  // ============================================================

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _userName = 'ผู้ใช้';
      });

      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();

        final firstName = data?['firstName']?.toString() ?? '';

        final lastName = data?['lastName']?.toString() ?? '';

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
      // ถ้าอ่าน Firestore ไม่ได้
      // ใช้ชื่อจาก Firebase Authentication แทน
      if (!mounted) return;

      setState(() {
        _userName = user.displayName ?? 'ผู้ใช้';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ผู้ขับ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======================================================
          // Profile Header
          // ======================================================

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ชื่อจาก Firebase
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _profile.faceVerified
                            ? 'ยืนยันใบหน้าแล้ว'
                            : 'ยังไม่ยืนยันใบหน้า',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                      Text(
                        _profile.bluetoothConnected
                            ? 'BT เชื่อมต่อ'
                            : 'BT ยังไม่เชื่อมต่อ',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ======================================================
          // การตั้งค่าการเตือน
          // ======================================================

          const Text(
            'การตั้งค่าการเตือน',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          _SettingsCard(
            children: [
              // ==================================================
              // เสียงเตือน
              // ==================================================

              _ToggleRow(
                icon: Icons.volume_up_outlined,
                title: 'เสียงเตือนผ่านลำโพงรถ',
                subtitle: 'เปิด',
                value: _profile.alarmThroughCarSpeaker,
                onChanged: (v) {
                  setState(() {
                    _profile = _profile.copyWith(
                      alarmThroughCarSpeaker: v,
                    );
                  });
                },
              ),

              const Divider(height: 1),

              // ==================================================
              // Notification
              // ==================================================

              _ToggleRow(
                icon: Icons.notifications_none,
                title: 'การแจ้งเตือนระบบ',
                subtitle: 'ทุกระดับ',
                value: _profile.systemNotificationsOn,
                onChanged: (v) {
                  setState(() {
                    _profile = _profile.copyWith(
                      systemNotificationsOn: v,
                    );
                  });
                },
              ),

              const Divider(height: 1),

              // ==================================================
              // Night Mode
              // ==================================================

              _ToggleRow(
                icon: Icons.nights_stay_outlined,
                title: 'โหมดขับกลางคืน',
                subtitle: 'ปิดใช้งาน',
                value: _profile.nightDrivingMode,
                onChanged: (v) {
                  setState(() {
                    _profile = _profile.copyWith(
                      nightDrivingMode: v,
                    );
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Settings Card
// ================================================================

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ================================================================
// Toggle Row
// ================================================================

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.primary,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
