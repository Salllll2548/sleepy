import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../shared/navigation/main_shell.dart';

/// หน้า 3: สแกนหน้าเพื่อยืนยันตัวตน + โชว์เกณฑ์ AI ที่เปิดใช้งานอยู่
/// (ตรงตามชิปคำในดีไซน์: หาว, หลับตา >2 วิ, หลับตาถี่, พยักหน้า,
/// มองออกนอกทาง, ถอน/ถอด, ไม่พบใบหน้า)
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  static const _aiCriteria = [
    'หาว',
    'หลับตา >2 วิ',
    'หลับตาถี่',
    'พยักหน้า',
    'มองออกนอกทาง',
    'ถอน / ถอด',
    'ไม่พบใบหน้า',
  ];

  bool _isScanning = false;
  bool _scanComplete = false;

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    // TODO: แทนด้วยการเรียก FaceDetectionService จริงเพื่อยืนยันใบหน้า
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _scanComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _isScanning || _scanComplete ? null : _startScan,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _scanComplete
                          ? AppColors.ringActive
                          : AppColors.primary,
                      width: 3,
                    ),
                  ),
                  child: _isScanning
                      ? const Padding(
                          padding: EdgeInsets.all(50),
                          child: CircularProgressIndicator(),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.person, size: 100, color: AppColors.primary),
                            if (_scanComplete)
                              const Positioned(
                                bottom: 30,
                                child: Icon(Icons.check_circle,
                                    color: AppColors.ringActive, size: 32),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _scanComplete
                    ? 'ยืนยันใบหน้าสำเร็จ'
                    : _isScanning
                        ? 'กำลังสแกนใบหน้า...'
                        : 'แตะวงกลมเพื่อเริ่มสแกนใบหน้า',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'เกณฑ์ AI ที่เปิดใช้งาน',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in _aiCriteria)
                    Chip(
                      label: Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                ],
              ),
              const Spacer(),
              if (_scanComplete)
                PrimaryButton(
                  label: 'เริ่มใช้งาน',
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
