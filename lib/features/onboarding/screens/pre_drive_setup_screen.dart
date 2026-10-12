import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../shared/navigation/main_shell.dart';

class PreDriveSetupScreen extends StatefulWidget {
  const PreDriveSetupScreen({super.key});

  @override
  State<PreDriveSetupScreen> createState() => _PreDriveSetupScreenState();
}

class _PreDriveSetupScreenState extends State<PreDriveSetupScreen> {
  bool _cameraAiEnabled = true;
  bool _alertsEnabled = true;

  Future<void> _onContinue() async {
    if (_cameraAiEnabled) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        await openAppSettings();
        return;
      }

      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ต้องอนุญาตให้ใช้กล้องก่อนเริ่มใช้งาน')),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.background,
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(height: 16),
              const Text(
                'ขออนุญาตใช้สิทธิ์',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'เปิดกล้อง → AI ตรวจจับความง่วง → แจ้งเตือนผ่านลำโพงหรือหูฟัง',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _SettingToggleCard(
                icon: Icons.face_retouching_natural,
                title: 'กล้อง + AI ตรวจจับใบหน้า',
                subtitle: 'วิเคราะห์ดวงตา คิ้ว ริมฝีปาก และเอียงศีรษะ',
                value: _cameraAiEnabled,
                onChanged: (v) => setState(() => _cameraAiEnabled = v),
              ),
              const SizedBox(height: 12),
              _SettingToggleCard(
                icon: Icons.notifications_active_outlined,
                title: 'การแจ้งเตือน',
                subtitle: 'แจ้งเตือนทันทีเมื่อตรวจพบความง่วง',
                value: _alertsEnabled,
                onChanged: (v) => setState(() => _alertsEnabled = v),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'ตรวจสอบใบหน้าและเริ่มใช้งาน',
                icon: Icons.face,
                onPressed: _onContinue,
              ),
              const SizedBox(height: 8),
              const Text(
                'ข้อมูลใบหน้าประมวลผลบนอุปกรณ์เท่านั้น ไม่มีการส่งออก',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
