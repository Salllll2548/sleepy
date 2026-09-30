import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../shared/navigation/main_shell.dart';
import 'package:sleepy/services/face_detection_service.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _cameraController;
  final FaceDetectionService _faceService = FaceDetectionService();

  // สถานะการทำ Checklist (0 = ลืมตา, 1 = หลับตา, 2 = หาว, 3 = เสร็จสิ้น)
  int _activeStep = -1; // -1 คือยังไม่เริ่มกดสแกน
  final List<bool> _stepCompleted = [false, false, false];

  String _statusText = 'กดปุ่มด้านล่างเพื่อเริ่มการสแกนปรับเกณฑ์';
  bool _isSaving = false;

  final List<double> _openEyeSamples = [];
  final List<double> _closedEyeSamples = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCam,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  // --- กระบวนการสแกนตาม Checklist ---
  Future<void> _startCalibrationProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    // ------------------------------------
    // ข้อที่ 1: มองตรงลืมตาปกติ (3 วินาที)
    // ------------------------------------
    setState(() {
      _activeStep = 0;
      _statusText = '1/3 กรุณามองตรงและ "ลืมตาปกติ"';
      _openEyeSamples.clear();
    });

    await _cameraController!.startImageStream((image) async {
      final result = await _faceService.processCameraImage(
        image,
        _cameraController!.description,
      );
      if (result != null && result.faceFound) {
        _openEyeSamples.add(result.eyeOpenProbability);
      }
    });

    await Future.delayed(const Duration(seconds: 3));
    await _cameraController!.stopImageStream();

    setState(() {
      _stepCompleted[0] = true;
    });

    // ------------------------------------
    // ข้อที่ 2: หลับตาค้างไว้ 3 วินาที
    // ------------------------------------
    setState(() {
      _activeStep = 1;
      _statusText = '2/3 กรุณา "หลับตาค้างไว้" 3 วินาที';
      _closedEyeSamples.clear();
    });

    await _cameraController!.startImageStream((image) async {
      final result = await _faceService.processCameraImage(
        image,
        _cameraController!.description,
      );
      if (result != null && result.faceFound) {
        _closedEyeSamples.add(result.eyeOpenProbability);
      }
    });

    await Future.delayed(const Duration(seconds: 3));
    await _cameraController!.stopImageStream();

    setState(() {
      _stepCompleted[1] = true;
    });

    // ------------------------------------
    // ข้อที่ 3: ทดสอบการอ้าปาก / หาว
    // ------------------------------------
    setState(() {
      _activeStep = 2;
      _statusText = '3/3 กรุณาลอง "อ้าปาก/หาว" ช้าๆ';
    });

    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _stepCompleted[2] = true;
      _activeStep = 3; // ทำครบหมดแล้ว
    });

    // คำนวณและบันทึกลง Firestore
    await _saveCalibrationResult();
  }

  Future<void> _saveCalibrationResult() async {
    setState(() => _isSaving = true);

    final avgOpen = _openEyeSamples.isNotEmpty
        ? _openEyeSamples.reduce((a, b) => a + b) / _openEyeSamples.length
        : 0.8;

    final avgClosed = _closedEyeSamples.isNotEmpty
        ? _closedEyeSamples.reduce((a, b) => a + b) / _closedEyeSamples.length
        : 0.1;

    // คำนวณจุดกึ่งกลางระหว่างลืมตากับหลับตาเพื่อเป็น Threshold เฉพาะตัว
    final calculatedThreshold = (avgOpen + avgClosed) / 2;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isCalibrated': true,
          'customEyeThreshold': calculatedThreshold,
          'calibratedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error saving calibration: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _statusText = 'สแกนตั้งค่าเรียบร้อยแล้ว!';
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _stepCompleted.every((completed) => completed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าใบหน้าเฉพาะบุคคล'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // 1. กล้องถ่ายภาพสด (Camera Preview)
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: allDone ? AppColors.ringActive : AppColors.primary,
                      width: 4,
                    ),
                  ),
                  child: ClipOval(
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        if (_cameraController != null &&
                            _cameraController!.value.isInitialized)
                          CameraPreview(_cameraController!)
                        else
                          const Center(child: CircularProgressIndicator()),

                        // แสดงไอคอนติ๊กถูกตัวใหญ่ทับเมื่อสแกนเสร็จสมบูรณ์
                        if (allDone)
                          Container(
                            color: Colors.black38,
                            child: const Icon(
                              Icons.check_circle,
                              color: AppColors.ringActive,
                              size: 80,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: allDone ? AppColors.ringActive : AppColors.textMuted,
                ),
              ),

              const SizedBox(height: 24),

              // 2. รายการ Checklist คำสั่งให้ผู้ใช้ทำตาม
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildChecklistItem(
                      index: 0,
                      title: '1. มองตรงและลืมตาปกติ',
                      isCurrent: _activeStep == 0,
                      isDone: _stepCompleted[0],
                    ),
                    const Divider(),
                    _buildChecklistItem(
                      index: 1,
                      title: '2. หลับตาค้างไว้ 3 วินาที',
                      isCurrent: _activeStep == 1,
                      isDone: _stepCompleted[1],
                    ),
                    const Divider(),
                    _buildChecklistItem(
                      index: 2,
                      title: '3. ทดสอบการอ้าปาก / หาว',
                      isCurrent: _activeStep == 2,
                      isDone: _stepCompleted[2],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 3. ปุ่มกดเริ่มต้นสแกน / เข้าใช้งาน
              if (_isSaving)
                const CircularProgressIndicator()
              else if (allDone)
                PrimaryButton(
                  label: 'เริ่มใช้งาน',
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (route) => false,
                    );
                  },
                )
              else
                PrimaryButton(
                  label: _activeStep == -1 ? 'เริ่มสแกนใบหน้า' : 'กำลังสแกน...',
                  onPressed: _activeStep == -1 ? _startCalibrationProcess : null,
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Widget สำหรับวาดรายการแต่ละข้อใน Checklist
  Widget _buildChecklistItem({
    required int index,
    required String title,
    required bool isCurrent,
    required bool isDone,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (isDone)
            const Icon(Icons.check_circle, color: Colors.green, size: 24)
          else if (isCurrent)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isDone
                  ? Colors.black
                  : isCurrent
                      ? AppColors.primary
                      : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}