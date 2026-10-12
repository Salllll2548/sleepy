import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart'
    show YOLOView, YOLOViewController, YOLOTask, YOLOResult, LensFacing;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/drive_session_model.dart';
import '../../../services/alert_service.dart';
import '../../../services/risk_score_manager.dart';

class DrivingDetectionScreen extends StatefulWidget {
  const DrivingDetectionScreen({super.key});

  @override
  State<DrivingDetectionScreen> createState() =>
      _DrivingDetectionScreenState();
}

class _DrivingDetectionScreenState extends State<DrivingDetectionScreen> {
  // path ของโมเดล YOLO
  static const String _yoloModelPath = 'assets/models/best.tflite';

  // เกณฑ์ความมั่นใจฝั่งแอป
  static const double _eyeClosedMinConf = 0.4;
  static const double _yawnMinConf = 0.5;

  // ---------- ตัวช่วยดีบั๊ก YOLO ----------
  static const bool _debugYolo = true;
  static const bool _yoloFullscreenTest = false;
  static const bool _yoloUseGpu = true;
  static const LensFacing _yoloLensFacing = LensFacing.front;
  static const bool _showYoloBoxes = false;

  // ---------- ตัวแปร YOLO & Watchdog ----------
  Timer? _yoloWatchdog;
  DateTime? _lastYoloResultAt;
  final YOLOViewController _yoloController = YOLOViewController();
  bool _overlayPrefApplied = false;

  // ---------- Services ----------
  final _riskManager = RiskScoreManager();
  final _alertService = AlertService();

  RiskLevelInfo _levelInfo = getRiskLevelInfo(0);
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _riskManager.resetForNewTrip();
    _riskManager.scoreNotifier.addListener(_onScoreChanged);
    _startYoloWatchdog();
  }

  // ============================================================
  // การประมวลผล YOLO
  // ============================================================

  /// รับผลตรวจจับของ YOLO ทุกเฟรม แล้วส่งเข้า RiskScoreManager แยกตามหมวด
  /// โมเดลมี 4 class: eye_closed, eye_opened, yawning, not yawn
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
      final isEyeClosed =
          closedConf > _eyeClosedMinConf && closedConf > openedConf;
      _riskManager.onEyeState(isEyeClosed);
    }

    // --- ปาก ---
    final yawnConf = bestConf('yawning');
    final notYawnConf = bestConf('not yawn');
    final isYawning = yawnConf > _yawnMinConf && yawnConf > notYawnConf;
    _riskManager.onMouthState(isYawning);
  }

  DateTime? _lastDebugLogAt;

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

  /// Watchdog ตรวจสอบว่ากล้องมืด/หน้าหายไปนานเกิน 1 วินาทีหรือไม่
  void _startYoloWatchdog() {
    _yoloWatchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final last = _lastYoloResultAt;
      if (last == null) return;

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
  // การจัดการสถานะและความเสี่ยง
  // ============================================================

  void _onScoreChanged() {
    final info = getRiskLevelInfo(_riskManager.score);
    if (!mounted) return;
    setState(() => _levelInfo = info);

    if (info.playSound) {
      _alertService.triggerAlert();
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

  // ============================================================
  // ส่วนแสดงผลกล้อง YOLO
  // ============================================================

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

  void _applyYoloOverlayPref() {
    if (_overlayPrefApplied || !_yoloController.isInitialized) return;
    _overlayPrefApplied = true;
    _yoloController.setShowOverlays(_showYoloBoxes).catchError((_) {
      _overlayPrefApplied = false;
    });
  }

  Widget _buildYoloView() {
    return YOLOView(
      key: const ValueKey('yolo_view'),
      modelPath: _yoloModelPath,
      task: YOLOTask.detect,
      controller: _yoloController,
      lensFacing: _yoloLensFacing,
      useGpu: _yoloUseGpu,
      onResult: _onYoloResult,
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
    _riskManager.scoreNotifier.removeListener(_onScoreChanged);
    _riskManager.dispose();
    _alertService.stopAlert();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _riskManager.score;
    final alertness = (100 - score).clamp(0, 100);
    final isAlert = _levelInfo.playSound;

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
                    // เว้นที่ว่างไว้ให้ YOLOView ที่ลอยอยู่ชั้นนอก
                    const SizedBox(width: 90, height: 120),
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