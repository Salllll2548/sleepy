import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userName = 'กำลังโหลด...';

  // สถานะสิทธิ์จริงจากระบบ (OS Permissions)
  bool _cameraGranted = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

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
        setState(() {
          _userName = user.displayName ?? 'ผู้ใช้';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userName = user.displayName ?? 'ผู้ใช้';
      });
    }
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final notificationStatus = await Permission.notification.status;

    if (!mounted) return;

    setState(() {
      _cameraGranted = cameraStatus.isGranted;
      _notificationGranted = notificationStatus.isGranted;
    });
  }

  Future<void> _handlePermissionToggle(
      Permission permission, bool isCurrentlyGranted) async {
    if (!isCurrentlyGranted) {
      final status = await permission.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'หากต้องการปิดสิทธิ์ กรุณาปิดผ่านการตั้งค่าของเครื่อง (App Settings)'),
        ),
      );
      await openAppSettings();
    }
    await _checkPermissions();
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
                        _cameraGranted
                            ? 'สิทธิ์กล้อง: อนุญาตแล้ว'
                            : 'สิทธิ์กล้อง: ยังไม่อนุญาต',
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

          const Text(
            'การจัดการสิทธิ์การเข้าถึงอุปกรณ์',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.camera_alt_outlined,
                title: 'กล้อง (AI ตรวจจับใบหน้า)',
                subtitle: _cameraGranted ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                value: _cameraGranted,
                onChanged: (_) =>
                    _handlePermissionToggle(Permission.camera, _cameraGranted),
              ),

              const Divider(height: 1),

              _ToggleRow(
                icon: Icons.notifications_none,
                title: 'การแจ้งเตือนระบบ',
                subtitle: _notificationGranted ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                value: _notificationGranted,
                onChanged: (_) => _handlePermissionToggle(
                    Permission.notification, _notificationGranted),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('ออกจากระบบ'),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
        style: TextStyle(
          fontSize: 11,
          color: value ? Colors.green : Colors.grey,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}