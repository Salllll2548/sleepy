import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/drive_session_model.dart';
import '../../../services/alert_service.dart';
import '../../../services/face_detection_service.dart';
import '../../../services/risk_score_manager.dart'; // เปลี่ยนจาก risk_score_service.dart

class DrivingDetectionScreen extends StatefulWidget {
  const DrivingDetectionScreen({super.key});

  @override
  State<DrivingDetectionScreen> createState() => _DrivingDetectionScreenState();
}

class _DrivingDetectionScreenState extends State<DrivingDetectionScreen> {
  CameraController? _cameraController;
  // สร้างแบบไม่มี threshold ตายตัวตรงนี้ — ไปตั้งค่าจากผลคาลิเบรตใน
  // Firestore ใน _loadCalibrationThenInitCamera() ก่อนเริ่มเปิดกล้อง
  final _faceDetectionService = FaceDetectionService();
  final _riskManager = RiskScoreManager();
  final _alertService = AlertService();

  bool _isProcessingFrame = false;

  // เก็บ RiskLevelInfo ปัจจุบันไว้ build UI (อัปเดตทุกครั้งที่ scoreNotifier เปลี่ยน)
  RiskLevelInfo _levelInfo = getRiskLevelInfo(0);

  // บันทึกเวลาที่เริ่มเปิดหน้านี้ขับขี่
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _loadCalibrationThenInitCamera();
    _riskManager.resetForNewTrip();
    _riskManager.scoreNotifier.addListener(_onScoreChanged);
  }

  /// ดึงค่าที่คาลิเบรตไว้ตอนหน้า Face Scan จาก Firestore (ถ้ามี) มาตั้งให้
  /// FaceDetectionService ก่อนเริ่มเปิดกล้อง — นี่คือจุดที่หายไปก่อนหน้านี้
  /// ทำให้ค่าที่คาลิเบรตไปแล้วไม่เคยถูกใช้งานจริงเลย ถ้าผู้ใช้ยังไม่เคย
  /// สแกน/ไม่ได้ login จะใช้ค่า default ที่ตั้งไว้ใน FaceDetectionService ต่อไป
  Future<void> _loadCalibrationThenInitCamera() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final eyeThreshold = data?['customEyeThreshold'];
        final mouthThreshold = data?['customMouthThreshold'];
        if (eyeThreshold is num) {
          _faceDetectionService.eyeClosedThreshold = eyeThreshold.toDouble();
        }
        if (mouthThreshold is num) {
          _faceDetectionService.mouthOpenRatioThreshold =
              mouthThreshold.toDouble();
        }
      } catch (e) {
        print('⚠️ โหลดค่าคาลิเบรตไม่สำเร็จ ใช้ค่า default แทน: $e');
      }
    }
    if (!mounted) return;
    await _initCamera();
  }

  void _onScoreChanged() {
    final info = getRiskLevelInfo(_riskManager.score);
    if (!mounted) return;
    setState(() => _levelInfo = info);

    // playSound/useTts มาจากสเปกที่กำหนดไว้ใน risk_score_manager.dart เอง
    // ระดับ moderate ขึ้นไปเริ่มมีเสียง, severe เท่านั้นที่พูดผ่านลำโพงรถ (TTS)
    if (info.playSound) {
      _alertService.triggerAlert();
      // TODO: ถ้า info.useTts == true ให้ส่งข้อความ info.message พูดผ่าน
      // Bluetooth Audio ของรถแทน/เพิ่มเติมจากเสียง alarm ธรรมดา
    } else {
      _alertService.stopAlert();
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
      if (result != null) {
        // ส่งเข้า RiskScoreManager แยกตามหมวด ตามที่ตัว manager ออกแบบไว้
        // เดิม RiskScoreService ตัวเก่าไม่เคยอ่านเรื่องปาก (หาว) เลย
        _riskManager.onEyeState(result.eyesClosed);
        _riskManager.onMouthState(result.isYawning);
        _riskManager.onHeadPitch(result.headEulerAngleX);
        _riskManager.onFaceVisibility(result.faceFound);
      }
      _isProcessingFrame = false;
    });
  }

  Future<void> _endDrive() async {
    final elapsed = DateTime.now().difference(_startedAt);

    final session = DriveSession(
      startedAt: _startedAt,
      elapsed: elapsed,
    );

    // บันทึกลง Firebase Firestore (คงของเดิมไว้ทั้งหมด)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .add({
          'startedAt': Timestamp.fromDate(_startedAt),
          'elapsedSeconds': elapsed.inSeconds,
          'finalScore': _riskManager.score,
          'eventCounts': _riskManager.tripSummaryCounts(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ บันทึกประวัติการขับลง Firestore สำเร็จ!');
      } catch (e) {
        print('❌ เกิดข้อผิดพลาดในการบันทึก: $e');
      }
    } else {
      print('⚠️ ไม่พบข้อมูลผู้ใช้ (ยังไม่ได้ Login ในระบบ FirebaseAuth)');
    }

    if (!mounted) return;
    Navigator.pop(context, session);
  }

  /// --------------------------------------------------
  /// Widget แสดงกรอบกล้องสี่เหลี่ยมเล็กๆ มุมบนขวา
  /// --------------------------------------------------
  Widget _buildCameraPreview() {
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

    return Container(
      width: 90,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white54, width: 2),
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
    _riskManager.scoreNotifier.removeListener(_onScoreChanged);
    _riskManager.dispose();
    _alertService.stopAlert();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _riskManager.score;
    final alertness = (100 - score).clamp(0, 100);
    final isAlert = _levelInfo.playSound; // moderate ขึ้นไปถือว่า alert

    return PipWidget(
      pipChild: Scaffold(
        backgroundColor: AppColors.darkCard,
        body: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Center(
                      child: SizedBox(
                        width: 85,
                        height: 85,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 85,
                              height: 85,
                              child: CircularProgressIndicator(
                                value: (alertness / 100).toDouble(),
                                strokeWidth: 5,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation(
                                  isAlert ? Colors.redAccent : AppColors.ringActive,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  alertness.toStringAsFixed(0),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _levelInfo.label,
                                  style: TextStyle(
                                    color: isAlert ? Colors.redAccent : Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.darkCard,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Pill(
                          icon: Icons.camera_alt_outlined,
                          label: 'AI กำลังตรวจจับ',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.picture_in_picture_alt,
                            color: Colors.white70,
                            size: 30,
                          ),
                          onPressed: () => SimplePip().enterPipMode(
                            aspectRatio: (1, 1),
                          ),
                        )
                      ],
                    ),
                    _buildCameraPreview(),
                  ],
                ),
                const Spacer(),
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
                          valueColor: AlwaysStoppedAnimation(_levelInfo.color),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_levelInfo.emoji, style: const TextStyle(fontSize: 22)),
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
                            _levelInfo.label,
                            style: TextStyle(color: _levelInfo.color),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _levelInfo.message,
                  style: TextStyle(color: _levelInfo.color, fontSize: 12),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'สิ้นสุดการขับ',
                  icon: Icons.stop_circle_outlined,
                  onPressed: _endDrive,
                ),
              ],
            ),
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
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}