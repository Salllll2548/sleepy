import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/drive_session_model.dart';
import '../../../models/risk_score_model.dart';
import '../../../services/alert_service.dart';
import '../../../services/face_detection_service.dart';
import '../../../services/risk_score_service.dart';

class DrivingDetectionScreen extends StatefulWidget {
  const DrivingDetectionScreen({super.key});

  @override
  State<DrivingDetectionScreen> createState() => _DrivingDetectionScreenState();
}

class _DrivingDetectionScreenState extends State<DrivingDetectionScreen> {
  CameraController? _cameraController;
  final _faceDetectionService = FaceDetectionService();
  final _riskScoreService = RiskScoreService();
  final _alertService = AlertService();

  RiskScoreState _state = RiskScoreState.initial();
  bool _isProcessingFrame = false;

  // บันทึกเวลาที่เริ่มเปิดหน้านี้ขับขี่
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _initCamera();
    _riskScoreService.stream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (state.isAlert) {
        _alertService.triggerAlert();
      } else {
        _alertService.stopAlert();
      }
    });
  }

  Future<void> saveDriveSession({
    required DateTime startTime,
    required int elapsedSeconds,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. เช็กว่าล็อกอินอยู่หรือไม่
    if (user == null) {
      print('⚠️ บันทึกไม่ได้: ผู้ใช้ยังไม่ได้ Login ในระบบ FirebaseAuth');
      return;
    }

    try {
      // 2. สร้าง/เพิ่มข้อมูลลงใน collection: users/{uid}/sessions
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .add({
        'startedAt': Timestamp.fromDate(startTime),
        'elapsedSeconds': elapsedSeconds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ บันทึกประวัติการขับลง Firebase สำเร็จแล้ว!');
    } catch (e) {
      print('❌ เกิดข้อผิดพลาดในการบันทึก: $e');
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() => _cameraController = controller);

    controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      final result =
          await _faceDetectionService.processCameraImage(image, frontCamera);
      if (result != null) _riskScoreService.addFrame(result);
      _isProcessingFrame = false;
    });
  }

Future<void> _endDrive() async {
    // 1. คำนวณระยะเวลารวม (โค้ดเดิมของคุณ)
    final elapsed = DateTime.now().difference(_startedAt);

    final session = DriveSession(
      startedAt: _startedAt,
      elapsed: elapsed,
    );

    // 2. บันทึกลง Firebase Firestore (ส่วนที่เพิ่มใหม่)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .add({
          'startedAt': Timestamp.fromDate(_startedAt),
          'elapsedSeconds': elapsed.inSeconds, // ดึงจำนวนวินาทีจาก elapsed เดิมของคุณ
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ บันทึกประวัติการขับลง Firestore สำเร็จ!');
      } catch (e) {
        print('❌ เกิดข้อผิดพลาดในการบันทึก: $e');
      }
    } else {
      print('⚠️ ไม่พบข้อมูลผู้ใช้ (ยังไม่ได้ Login ในระบบ FirebaseAuth)');
    }

    // 3. ปิดหน้าจอและส่งค่า session กลับไป (โค้ดเดิมของคุณ)
    if (!mounted) return;
    Navigator.pop(context, session);
  }

  /// --------------------------------------------------
  /// Widget แสดงกรอบกล้องสี่เหลี่ยมเล็กๆ มุมบนขวา
  /// --------------------------------------------------
  Widget _buildCameraPreview() {
    // ถ้ากล้องยังโหลดไม่เสร็จ ให้โชว์กล่องดำ/ตัวโหลดหมุนๆ
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        width: 120,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      );
    }

    // ถ้ากล้องพร้อมแล้ว แสดงวิดีโอสดในกรอบสี่เหลี่ยมมุมมน
    return Container(
      width: 90, // ความกว้างกรอบกล้อง
      height: 120, // ความสูงกรอบกล้อง
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white54, width: 2), // ขอบกรอบสีขาว
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: _cameraController!.value.aspectRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectionService.dispose();
    _riskScoreService.dispose();
    _alertService.stopAlert();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertness = (100 - _state.score).clamp(0, 100);
    return Scaffold(
      backgroundColor: AppColors.darkCard,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ==========================================
              // แถบบนสุด: ป้ายสถานะ (ซ้าย) + กรอบกล้อง (ขวา)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Pill(icon: Icons.bluetooth, label: 'BT เชื่อมต่อแล้ว'),
                      SizedBox(height: 6),
                      _Pill(
                          icon: Icons.camera_alt_outlined,
                          label: 'AI กำลังตรวจจับ'),
                    ],
                  ),
                  // กรอบกล้องมุมบนขวา
                  _buildCameraPreview(),
                ],
              ),

              const Spacer(),

              // ==========================================
              // วงแหวนแสดงคะแนนความตื่นตัว
              // ==========================================
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: (alertness / 100).toDouble(),
                        strokeWidth: 10,
                        backgroundColor: Colors.white12,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.ringActive),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            color: Colors.white70, size: 20),
                        const SizedBox(height: 6),
                        Text(
                          alertness.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _state.isAlert ? 'ระวัง!' : 'okay',
                          style: TextStyle(
                            color: _state.isAlert
                                ? Colors.redAccent
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Text(
                _state.isAlert
                    ? '● เสี่ยง • กรุณาหยุดพักรถ'
                    : '● ปกติ • ขับได้อย่างปลอดภัย',
                style: TextStyle(
                  color:
                      _state.isAlert ? Colors.redAccent : AppColors.ringActive,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // ปุ่มสิ้นสุดการขับ
              // ==========================================
              PrimaryButton(
                label: 'สิ้นสุดการขับ',
                icon: Icons.stop_circle_outlined,
                onPressed: _endDrive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Pill({required this.icon, required this.label});

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
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
