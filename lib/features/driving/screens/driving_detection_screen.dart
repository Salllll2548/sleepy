import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/drive_session_model.dart';
import '../../../models/risk_score_model.dart';
import '../../../services/alert_service.dart';
import '../../../services/face_detection_service.dart';
import '../../../services/risk_score_service.dart';

/// หน้า 7: จอเต็มพื้นหลังเข้ม วงแหวนแสดงคะแนนความตื่นตัว real-time
/// ต่อกล้อง + FaceDetectionService + RiskScoreService ตัวจริงที่ทำไว้ก่อนหน้านี้
class DrivingDetectionScreen extends StatefulWidget {
  const DrivingDetectionScreen({super.key});

  @override
  State<DrivingDetectionScreen> createState() =>
      _DrivingDetectionScreenState();
}

class _DrivingDetectionScreenState extends State<DrivingDetectionScreen> {
  CameraController? _cameraController;
  final _faceDetectionService = FaceDetectionService();
  final _riskScoreService = RiskScoreService();
  final _alertService = AlertService();

  RiskScoreState _state = RiskScoreState.initial();
  bool _isProcessingFrame = false;
  final DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initCamera();
    _riskScoreService.stream.listen((state) {
      setState(() => _state = state);
      if (state.isAlert) {
        _alertService.triggerAlert();
      } else {
        _alertService.stopAlert();
      }
    });
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

  void _endDrive() {
    final session = DriveSession(
      startedAt: _startedAt,
      speedKmh: 0, // TODO: ต่อ GPS speed sensor จริง
      distanceKm: 0, // TODO: ต่อ GPS จริง
      elapsed: DateTime.now().difference(_startedAt),
      currentRiskScore: _state.score,
      alertnessScore: 100 - _state.score,
    );
    Navigator.pop(context, session);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _Pill(icon: Icons.camera_alt_outlined, label: 'AI ตรวจจับ'),
                  _Pill(icon: Icons.bluetooth, label: 'BT เชื่อมต่อแล้ว'),
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
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.ringActive),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Drowsiness Risk',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${_state.score.toStringAsFixed(0)}/100',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_state.score / 100).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(
                    _state.isAlert ? Colors.redAccent : AppColors.ringActive,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _state.isAlert
                    ? '● เสี่ยง • กรุณาหยุดพักรถ'
                    : '● ปกติ • ขับได้อย่างปลอดภัย',
                style: TextStyle(
                  color: _state.isAlert ? Colors.redAccent : AppColors.ringActive,
                  fontSize: 12,
                ),
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
