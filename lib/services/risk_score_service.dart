import 'dart:async';
import 'dart:collection';
import '../models/risk_score_model.dart';
import 'face_detection_service.dart';

/// รับผลตรวจจับใบหน้าทีละเฟรม แล้วคำนวณ PERCLOS + risk score สะสม
/// แนวคิด PERCLOS เป็นมาตรฐานที่งานวิจัยเรื่อง drowsiness detection ใช้จริง
/// (สัดส่วน % เวลาที่ตาปิดในช่วงเวลาหนึ่ง)
class RiskScoreService {
  // ---- ปรับค่าพวกนี้ได้ตามการทดสอบจริง ----
  final double eyeClosedThreshold; // ต่ำกว่านี้ถือว่าตาปิด
  final int windowSize; // จำนวนเฟรมใน sliding window (~ วินาที ขึ้นกับ fps)
  final double perclosAlertRatio; // PERCLOS % ที่เริ่มถือว่าเสี่ยงมาก
  final double headDroopDegrees; // มุมก้มหน้าที่ถือว่าผิดปกติ (สัปหงก)
  final double scoreIncreaseStep;
  final double scoreDecayStep;
  final double alertThreshold; // risk score ที่ถึงแล้วให้แจ้งเตือน

  RiskScoreService({
    this.eyeClosedThreshold = 0.4,
    this.windowSize = 30,
    this.perclosAlertRatio = 40,
    this.headDroopDegrees = 25,
    this.scoreIncreaseStep = 4,
    this.scoreDecayStep = 1.5,
    this.alertThreshold = 70,
  });

  final Queue<bool> _eyeClosedWindow = Queue<bool>();
  double _score = 0;

  final _controller = StreamController<RiskScoreState>.broadcast();
  Stream<RiskScoreState> get stream => _controller.stream;

  /// เรียกทุกครั้งที่มีผลตรวจจับใบหน้าใหม่จากเฟรมกล้อง
  void addFrame(FaceFrameResult result) {
    if (!result.faceFound) {
      // ไม่เจอหน้า (เช่น หันไปทางอื่นนาน ๆ) ก็ถือเป็นสัญญาณเสี่ยงเล็กน้อย
      _pushEyeState(true);
    } else {
      final eyesClosed = result.eyeOpenProbability < eyeClosedThreshold;
      _pushEyeState(eyesClosed);
    }

    final perclos = _calcPerclos();
    final headDroop =
        result.faceFound && result.headEulerAngleX.abs() > headDroopDegrees;

    _updateScore(perclos: perclos, headDroop: headDroop);

    _controller.add(RiskScoreState(
      score: _score,
      perclos: perclos,
      headDroop: headDroop,
      isAlert: _score >= alertThreshold,
    ));
  }

  void _pushEyeState(bool closed) {
    _eyeClosedWindow.addLast(closed);
    if (_eyeClosedWindow.length > windowSize) {
      _eyeClosedWindow.removeFirst();
    }
  }

  double _calcPerclos() {
    if (_eyeClosedWindow.isEmpty) return 0;
    final closedCount = _eyeClosedWindow.where((c) => c).length;
    return (closedCount / _eyeClosedWindow.length) * 100;
  }

  void _updateScore({required double perclos, required bool headDroop}) {
    if (perclos >= perclosAlertRatio) {
      _score += scoreIncreaseStep;
    } else {
      _score -= scoreDecayStep;
    }

    if (headDroop) {
      _score += scoreIncreaseStep;
    }

    _score = _score.clamp(0, 100);
  }

  /// รีเซ็ตคะแนน เช่น หลังจากแจ้งเตือนแล้วผู้ใช้ยืนยันว่าไหวแล้ว
  void reset() {
    _eyeClosedWindow.clear();
    _score = 0;
  }

  void dispose() {
    _controller.close();
  }
}
