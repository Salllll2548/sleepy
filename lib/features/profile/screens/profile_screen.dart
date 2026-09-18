import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // TODO: โหลดจาก AuthService/backend จริงแทนค่า mock นี้
  UserProfile _profile = const UserProfile(
    name: 'นนท์ วรพงศ์',
    faceVerified: true,
    bluetoothConnected: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์ผู้ขับ')),
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
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _profile.faceVerified ? 'ยืนยันใบหน้าแล้ว' : 'ยังไม่ยืนยันใบหน้า',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        _profile.bluetoothConnected
                            ? 'BT เชื่อมต่อ'
                            : 'BT ยังไม่เชื่อมต่อ',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('การตั้งค่าการเตือน',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.volume_up_outlined,
                title: 'เสียงเตือนผ่านลำโพงรถ',
                subtitle: 'เปิด',
                value: _profile.alarmThroughCarSpeaker,
                onChanged: (v) => setState(
                  () => _profile = _profile.copyWith(alarmThroughCarSpeaker: v),
                ),
              ),
              const Divider(height: 1),
              _ToggleRow(
                icon: Icons.notifications_none,
                title: 'การแจ้งเตือนระบบ',
                subtitle: 'ทุกระดับ',
                value: _profile.systemNotificationsOn,
                onChanged: (v) => setState(
                  () => _profile = _profile.copyWith(systemNotificationsOn: v),
                ),
              ),
              const Divider(height: 1),
              _ToggleRow(
                icon: Icons.nights_stay_outlined,
                title: 'โหมดขับกลางคืน',
                subtitle: 'ปิดใช้งาน',
                value: _profile.nightDrivingMode,
                onChanged: (v) => setState(
                  () => _profile = _profile.copyWith(nightDrivingMode: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
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
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
