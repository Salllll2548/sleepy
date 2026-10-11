import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart'
    show YOLOView, YOLOViewController, YOLOTask, YOLOResult, LensFacing;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/drive_session_model.dart';
import '../../../services/alert_service.dart';
import '../../../services/face_detection_service.dart';
import '../../../services/risk_score_manager.dart';

class DrivingDetectionScreen extends StatefulWidget {
  const DrivingDetectionScreen({super.key});

  @override
  State<DrivingDetectionScreen> createState() => _DrivingDetectionScreenState();
}

class _DrivingDetectionScreenState extends State<DrivingDetectionScreen> {
  // ============================================================
  // ตั้งค่าเอนจินตรวจจับ
  //   true  = ใช้โมเดล YOLO (best.tflite) ผ่าน YOLOView
  //   false = ใช้ ML Kit แบบเดิม (มีมุมหัว + คาลิเบรตเฉพาะคนจาก Firestore)
  // YOLOView เปิดกล้องเอง จึงใช้ร่วมกับ CameraController ของ ML Kit
  // พร้อมกันไม่ได้ — เลือกได้ทีละแบบเท่านั้น
  // ============================================================
  static const bool _useYolo = true;

  // path ของโมเดล (ต้องเขียนให้ตรงกับที่วางไฟล์จริง):
  //  - Flutter asset (ประกาศใน pubspec.yaml) → ใส่ path เต็ม 'assets/models/best.tflite'
  //  - native asset (วางไฟล์ใน android/app/src/main/assets/) → ใช้ชื่อไฟล์เฉยๆ 'best.tflite'
  // log เดิม "Could not open 'best.tflite'" เกิดจากใช้ชื่อเปล่าๆ ทั้งที่ไฟล์
  // ถูกประกาศเป็น Flutter asset ใน pubspec.yaml ปลั๊กอินเลยหาไฟล์ไม่เจอ
  static const String _yoloModelPath = 'assets/models/best.tflite';

  // เกณฑ์ความมั่นใจฝั่งแอป (ชั้นบนของค่า confidenceThreshold ในปลั๊กอิน)
  static const double _eyeClosedMinConf = 0.4;
  static const double _yawnMinConf = 0.5;

  // ---------- ตัวช่วยดีบั๊ก YOLO (ปิด/ตั้งกลับเมื่อใช้งานจริง) ----------
  // พิมพ์ผลตรวจจับและค่าประสิทธิภาพลงคอนโซลของ flutter run
  static const bool _debugYolo = true;
  // true = แสดงกล้อง YOLO เต็มจอแบบไม่ย่อ/ไม่ตัดขอบ (ใช้แยกว่ากล้องดำเพราะ
  // กรอบเล็กที่ลอยอยู่ หรือเพราะกล้อง/โมเดลไม่ทำงาน) — ค่าปกติ false
  static const bool _yoloFullscreenTest = false;
  // ลอง false ถ้ากล้องดำ/โมเดลไม่ทำงานบนเครื่องนี้ (ปิด GPU delegate)
  static const bool _yoloUseGpu = true;
  // ลอง LensFacing.back เพื่อเทียบว่ากล้องหน้าเป็นต้นเหตุหรือไม่
  static const LensFacing _yoloLensFacing = LensFacing.front;
  // true = วาดกรอบ bounding box + ป้ายชื่อ class ทับบนภาพกล้อง (ใช้ตอนดีบั๊ก)
  // false = แสดงแต่ภาพกล้อง ไม่วาดกรอบ (การตรวจจับยังทำงานตามปกติ)
  // ปลั๊กอินรุ่นใหม่ไม่มีพารามิเตอร์ showOverlays ใน YOLOView แล้ว
  // ต้องสั่งผ่าน YOLOViewController.setShowOverlays() (ดู _applyYoloOverlayPref)
  static const bool _showYoloBoxes = false;

  // ---------- ใช้เฉพาะโหมด ML Kit ----------
  CameraController? _cameraController;
  FaceDetectionService? _faceDetectionService;
  bool _isProcessingFrame = false;

  // ---------- ใช้เฉพาะโหมด YOLO ----------
  Timer? _yoloWatchdog;
  DateTime? _lastYoloResultAt;
  final YOLOViewController _yoloController = YOLOViewController();
  bool _overlayPrefApplied = false;

  // ---------- ใช้ร่วมกัน ----------
  final _riskManager = RiskScoreManager();
  final _alertService = AlertService();

  // เก็บ RiskLevelInfo ปัจจุบันไว้ build UI (อัปเดตทุกครั้งที่ scoreNotifier เปลี่ยน)
  RiskLevelInfo _levelInfo = getRiskLevelInfo(0);

  // บันทึกเวลาที่เริ่มเปิดหน้านี้ขับขี่
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _riskManager.resetForNewTrip();
    _riskManager.scoreNotifier.addListener(_onScoreChanged);

    if (_useYolo) {
      _startYoloWatchdog();
    } else {
      _loadCalibrationThenInitCamera();
    }
  }

  // ============================================================
  // โหมด YOLO
  // ============================================================

  /// รับผลตรวจจับของ YOLO ทุกเฟรม แล้วส่งเข้า RiskScoreManager แยกตามหมวด
  /// โมเดลมี 4 class: eye_closed, eye_opened, yawning, not yawn
  /// (ไม่มี class ท่าทางหัว จึงไม่มี onHeadPitch ในโหมดนี้)
  void _onYoloResult(List<YOLOResult> results) {
    _lastYoloResultAt = DateTime.now();
    _applyYoloOverlayPref();
    if (_debugYolo) _debugLogResults(results);

    double bestConf(String name) => results
        .where((r) => r.className == name)
        .fold<double>(0, (m, r) => r.confidence > m ? r.confidence : m);

    // --- ตา ---
    final closedConf = bestConf('eye_closed');
    final openedConf = bestConf('eye_opened');
    final eyesVisible = closedConf > 0 || openedConf > 0;
    _riskManager.onFaceVisibility(eyesVisible);

    if (eyesVisible) {
      // นับว่าตาปิดก็ต่อเมื่อ eye_closed มั่นใจกว่า eye_opened ด้วย
      // (กัน false positive ตอนคนตาเล็กลืมตาแล้วโมเดลเดาว่าปิดแบบไม่มั่นใจ)
      // ถ้าอยากใช้กติกาเดิม ให้ตัดเงื่อนไข `&& closedConf > openedConf` ออก
      final isEyeClosed =
          closedConf > _eyeClosedMinConf && closedConf > openedConf;
      _riskManager.onEyeState(isEyeClosed);
    }

    // --- ปาก ---
    // ต้องส่งค่าทุกเฟรม (รวมเฟรมที่ไม่เจอ yawning) ไม่งั้นการหาวไม่มีวันปิด
    // ปากเดียวกันอาจได้ทั้ง yawning และ not yawn ในเฟรมเดียว (NMS แยกตาม class)
    // จึงนับว่าหาวเมื่อ yawning มั่นใจกว่า not yawn เท่านั้น
    final yawnConf = bestConf('yawning');
    final notYawnConf = bestConf('not yawn');
    final isYawning = yawnConf > _yawnMinConf && yawnConf > notYawnConf;
    _riskManager.onMouthState(isYawning);
  }

  DateTime? _lastDebugLogAt;

  /// พิมพ์ class + ความมั่นใจที่โมเดลเห็นในเฟรมนั้น (ไม่เกิน 1 ครั้ง/วินาที)
  /// ใช้ตรวจว่าชื่อ class ตรงกับที่โค้ดเทียบอยู่ไหม และโมเดลเห็นอะไรบ้าง
  void _debugLogResults(List<YOLOResult> results) {
    final now = DateTime.now();
    final last = _lastDebugLogAt;
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }
    _lastDebugLogAt = now;
    final summary = results.isEmpty
        ? '(ไม่เจออะไร)'
        : results
            .map((r) => '${r.className}:${r.confidence.toStringAsFixed(2)}')
            .join(', ');
    debugPrint('YOLO results: $summary');
  }

  /// กันกรณี onResult ไม่ถูกเรียกเลยเมื่อไม่เจออะไรในเฟรม (หันหน้าหนี/มืดมาก)
  /// ถ้าเงียบเกิน 1 วินาทีหลังเคยได้ผลแล้ว ให้ถือว่าไม่เห็นตาและปากปิด
  /// ไม่ทำงานตอนแอปอยู่เบื้องหลัง (กล้องหยุดเอง ไม่ควรนับว่าหน้าหาย)
  void _startYoloWatchdog() {
    _yoloWatchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final last = _lastYoloResultAt;
      if (last == null) return; // โมเดลยังโหลดอยู่ ไม่ถือว่าหน้าหาย

      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == AppLifecycleState.paused ||
          lifecycle == AppLifecycleState.hidden ||
          lifecycle == AppLifecycleState.detached) {
        return;
      }

      if (DateTime.now().difference(last) > const Duration(seconds: 1)) {
        _riskManager.onFaceVisibility(false);
        _riskManager.onMouthState(false);
      }
    });
  }

  // ============================================================
  // โหมด ML Kit (ของเดิม ไม่เปลี่ยน)
  // ============================================================

  /// ดึงค่าที่คาลิเบรตไว้ตอนหน้า Face Scan จาก Firestore (ถ้ามี) มาตั้งให้
  /// FaceDetectionService ก่อนเริ่มเปิดกล้อง — ถ้าผู้ใช้ยังไม่เคยสแกน/ไม่ได้
  /// login จะใช้ค่า default ที่ตั้งไว้ใน FaceDetectionService
  Future<void> _loadCalibrationThenInitCamera() async {
    final service = FaceDetectionService();
    _faceDetectionService = service;

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
          service.eyeClosedThreshold = eyeThreshold.toDouble();
        }
        if (mouthThreshold is num) {
          service.mouthOpenRatioThreshold = mouthThreshold.toDouble();
        }
      } catch (e) {
        print('⚠️ โหลดค่าคาลิเบรตไม่สำเร็จ ใช้ค่า default แทน: $e');
      }
    }
    if (!mounted) return;
    await _initCamera(service);
  }

  Future<void> _initCamera(FaceDetectionService service) async {
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
      final result = await service.processCameraImage(image, frontCamera);
      if (result != null) {
        _riskManager.onEyeState(result.eyesClosed);
        _riskManager.onMouthState(result.isYawning);
        _riskManager.onHeadPitch(result.headEulerAngleX);
        _riskManager.onFaceVisibility(result.faceFound);
      }
      _isProcessingFrame = false;
    });
  }

  // ============================================================
  // ส่วนที่ใช้ร่วมกันทั้งสองโหมด
  // ============================================================

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

  Future<void> _endDrive() async {
    final elapsed = DateTime.now().difference(_startedAt);

    final session = DriveSession(
      startedAt: _startedAt,
      elapsed: elapsed,
    );

    // บันทึกลง Firebase Firestore
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
  /// กรอบกล้องเล็กมุมบนขวา (โหมด ML Kit)
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

  /// --------------------------------------------------
  /// กรอบกล้องของ YOLOView (โหมด YOLO)
  /// วางไว้ใน Stack ชั้นนอกสุด *นอก* PipWidget เพื่อให้ YOLOView ไม่ถูกทำลาย
  /// ตอนเข้าโหมด PiP (PipWidget สลับไปแสดง pipChild ทำให้ child เดิมหายไป
  /// ถ้า YOLOView อยู่ข้างในกล้องจะหยุดและการตรวจจับจะหยุดตาม)
  /// ตอนเข้า PiP หน้าต่างจะเล็กลง จึงย่อกรอบลงตามความกว้างหน้าจอ
  /// --------------------------------------------------
  Widget _buildYoloOverlay(BuildContext context) {
    if (_yoloFullscreenTest) {
      return Positioned.fill(child: _buildYoloView());
    }

    final media = MediaQuery.of(context);
    final isPipSized = media.size.width < 300;

    final double w = isPipSized ? 40 : 90;
    final double h = isPipSized ? 53 : 120;
    final double top = isPipSized ? 4 : media.padding.top + 20;
    final double right = isPipSized ? 4 : 20;

    return Positioned(
      top: top,
      right: right,
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isPipSized ? 8 : 12),
          border: Border.all(color: Colors.white54, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isPipSized ? 6 : 10),
          child: _buildYoloView(),
        ),
      ),
    );
  }

  /// สั่งซ่อน/แสดงกรอบตรวจจับของ YOLOView ผ่าน controller
  /// controller จะผูกกับ view ได้หลัง view ถูกสร้างแล้วเท่านั้น (isInitialized)
  /// จึงลองเรียกซ้ำจาก callback ของ view จนกว่าจะสำเร็จหนึ่งครั้ง
  void _applyYoloOverlayPref() {
    if (_overlayPrefApplied || !_yoloController.isInitialized) return;
    _overlayPrefApplied = true;
    _yoloController.setShowOverlays(_showYoloBoxes).catchError((_) {
      _overlayPrefApplied = false; // ล้มเหลว ให้ลองใหม่รอบถัดไป
    });
  }

  Widget _buildYoloView() {
    return YOLOView(
      key: const ValueKey('yolo_view'),
      modelPath: _yoloModelPath,
      task: YOLOTask.detect,
      controller: _yoloController,
      // ค่าเริ่มต้นของปลั๊กอินคือกล้องหลัง ต้องระบุกล้องหน้าให้ตรงคนขับ
      lensFacing: _yoloLensFacing,
      useGpu: _yoloUseGpu,
      onResult: _onYoloResult,
      // ถ้ามีบรรทัด "YOLO metrics" ขึ้นในคอนโซล แปลว่ากล้องและโมเดลกำลังรันอยู่
      // callback นี้ถูกเรียกประมาณวินาทีละครั้งแม้ยังไม่เจออะไร จึงใช้เป็นจุด
      // ลองสั่งซ่อนกรอบด้วย
      onPerformanceMetrics: (m) {
        if (_debugYolo) debugPrint('YOLO metrics: $m');
        _applyYoloOverlayPref();
      },
    );
  }

  @override
  void dispose() {
    _yoloWatchdog?.cancel();
    _yoloController.dispose();
    _cameraController?.dispose();
    _faceDetectionService?.dispose();
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

    final content = PipWidget(
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
                                  isAlert
                                      ? Colors.redAccent
                                      : AppColors.ringActive,
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
                                    color: isAlert
                                        ? Colors.redAccent
                                        : Colors.white70,
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
                    // โหมด YOLO: เว้นที่ว่างไว้ให้ YOLOView ที่ลอยอยู่ชั้นนอก
                    _useYolo
                        ? const SizedBox(width: 90, height: 120)
                        : _buildCameraPreview(),
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
                          Text(_levelInfo.emoji,
                              style: const TextStyle(fontSize: 22)),
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

    if (!_useYolo) return content;

    return Stack(
      children: [
        Positioned.fill(child: content),
        _buildYoloOverlay(context),
      ],
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