import 'package:flutter/material.dart';
import '../../../core/constants/risk_levels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/drive_session_model.dart';
import '../../driving/screens/driving_detection_screen.dart';

/// หน้า 4 (ยังไม่เริ่มขับ — วงกลม "เริ่มต้น") และหน้า 5 (กำลังขับ — วงกลม "92")
/// เป็นจอเดียวกัน ต่างกันแค่ state ภายใน จึงไม่แยกไฟล์
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DriveSession? _activeSession; // null = ยังไม่เริ่ม (หน้า 4), มีค่า = กำลังขับ (หน้า 5)

  Future<void> _startDriving() async {
    // ไปหน้าตรวจจับระหว่างขับ (หน้า 7) แล้วรอผลทริปกลับมาแสดงผลที่นี่
    final result = await Navigator.push<DriveSession>(
      context,
      MaterialPageRoute(builder: (_) => const DrivingDetectionScreen()),
    );
    if (result != null) {
      setState(() => _activeSession = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _activeSession;
    final isActive = session != null;
    final alertnessScore = session?.alertnessScore ?? 0;
    final riskScore = session?.currentRiskScore ?? 15; // ค่าเริ่มต้นตามดีไซน์

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สวัสดี คุณแนท',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const Text('การเดินทางของคุณ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MainStatusCard(
            isActive: isActive,
            alertnessScore: alertnessScore,
            riskScore: riskScore,
            onTap: isActive ? null : _startDriving,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.speed,
                  value: isActive ? session.speedKmh.toStringAsFixed(0) : '--',
                  unit: 'กม./ชม.',
                  label: 'ความเร็วเฉลี่ย',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.route,
                  value: isActive ? session.distanceKm.toStringAsFixed(1) : '--',
                  unit: 'กม.',
                  label: 'ระยะทาง',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.access_time,
                  value: isActive ? '${session.elapsed.inMinutes}' : '--',
                  unit: 'นาที',
                  label: 'เวลาขับขี่',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('ระดับความเสี่ยง (Drowsiness Risk)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final info in RiskLevels.all)
                Expanded(child: _RiskLevelChip(info: info)),
            ],
          ),
          const SizedBox(height: 20),
          if (!isActive)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.creamButton,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.self_improvement, color: AppColors.creamButtonText),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'พักสติเมื่อรู้สึกล้า',
                      style: TextStyle(
                        color: AppColors.creamButtonText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MainStatusCard extends StatelessWidget {
  final bool isActive;
  final double alertnessScore;
  final double riskScore;
  final VoidCallback? onTap;

  const _MainStatusCard({
    required this.isActive,
    required this.alertnessScore,
    required this.riskScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusPill(
                    icon: Icons.camera_alt_outlined, label: 'AI ตรวจจับ'),
                _StatusPill(
                    icon: Icons.bluetooth, label: 'BT เชื่อมต่อแล้ว'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: isActive ? (alertnessScore / 100).clamp(0, 1) : 0.15,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.ringActive),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Text(
                          alertnessScore.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        const Text(
                          'เริ่มต้น',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const Text('ความตื่นตัว',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Drowsiness Risk',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${riskScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (riskScore / 100).clamp(0, 1),
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(AppColors.ringActive),
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('● ปกติ • ขับได้อย่างปลอดภัย',
                  style: TextStyle(color: AppColors.ringActive, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text('$value $unit',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _RiskLevelChip extends StatelessWidget {
  final RiskLevelInfo info;

  const _RiskLevelChip({required this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: info.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            CircleAvatar(radius: 4, backgroundColor: info.color),
            const SizedBox(height: 4),
            Text(info.rangeLabel,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: info.color)),
            Text(info.nameLabel, style: const TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
