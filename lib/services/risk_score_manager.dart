import 'dart:async';
import 'package:flutter/material.dart';

enum RiskLevel { normal, mild, moderate, severe }

class RiskLevelInfo {
  final RiskLevel level;
  final Color color;
  final String emoji;
  final String label;
  final String message;
  final bool playSound; // เริ่มมีเสียงเตือนตั้งแต่ระดับนี้
  final bool useTts; // ระดับนี้ต้องพูดเตือนผ่านลำโพงรถ

  const RiskLevelInfo({
    required this.level,
    required this.color,
    required this.emoji,
    required this.label,
    required this.message,
    required this.playSound,
    required this.useTts,
  });
}

RiskLevelInfo getRiskLevelInfo(double score) {
  if (score < 30) {
    return const RiskLevelInfo(
      level: RiskLevel.normal,
      color: Color(0xFF2ECC71),
      emoji: '🟢',
      label: 'ปกติ',
      message: 'สถานะ: ปกติ',
      playSound: false,
      useTts: false,
    );
  } else if (score < 50) {
    return const RiskLevelInfo(
      level: RiskLevel.mild,
      color: Color(0xFFF1C40F),
      emoji: '🟡',
      label: 'เริ่มง่วง',
      message: '⚠️ เริ่มมีสัญญาณความง่วง',
      playSound: false,
      useTts: false,
    );
  } else if (score < 70) {
    return const RiskLevelInfo(
      level: RiskLevel.moderate,
      color: Color(0xFFE67E22),
      emoji: '🟠',
      label: 'ง่วง',
      message: '⚠️ กรุณาระมัดระวัง',
      playSound: true,
      useTts: false,
    );
  } else {
    return const RiskLevelInfo(
      level: RiskLevel.severe,
      color: Color(0xFFE74C3C),
      emoji: '🔴',
      label: 'เสี่ยงหลับใน',
      message: '🚨 ตรวจพบความเสี่ยงสูง กรุณาจอดรถในที่ปลอดภัยและพักผ่อน',
      playSound: true,
      useTts: true,
    );
  }
}

class RiskEvent {
  final DateTime time;
  final String category; // 'eye' | 'mouth' | 'head' | 'face' | 'combo'
  final String type;
  final int points;
  const RiskEvent(this.time, this.category, this.type, this.points);
}

class RiskScoreManager {
  // ---------- ค่าที่ปรับได้ (tune ตอนทดสอบจริง) ----------
  static const double decayPerTick = 1.0;
  static const Duration decayInterval = Duration(seconds: 8);

  // ปรับจาก 1.0 วิ เป็น 1.3 วิ เพราะฟีดแบ็กพบว่าการกระพริบตาปกติบางครั้ง
  // (โดยเฉพาะตอนเหนื่อยแต่ไม่ง่วง) ก็ยาวใกล้ 1 วิได้ ขยับ margin กันไม่ให้ false positive
  static const Duration eyeShortThreshold = Duration(milliseconds: 1300);
  static const Duration eyeLongThreshold = Duration(seconds: 2);

  static const Duration blinkWindow = Duration(seconds: 30);
  static const int blinkCountThreshold = 8;
  static const Duration droopyCooldown = Duration(seconds: 15);

  // ต้องอ้าปากต่อเนื่องอย่างน้อยเท่านี้ถึงจะนับเป็นหาว
  // กันกรณีพูดคุย/หัวเราะที่ปากขยับเร็วๆ ถูกเข้าใจผิดว่าเป็นหาว
  static const Duration minYawnDuration = Duration(milliseconds: 2500);
  static const Duration yawnWindow = Duration(minutes: 5);
  static const Duration yawnCooldown = Duration(seconds: 3);

  static const double headNodAngleThreshold = 20.0;
  static const Duration headNodSustain = Duration(milliseconds: 600);
  static const Duration headNodCooldown = Duration(seconds: 4);

  static const Duration faceLostThreshold = Duration(milliseconds: 1500);
  static const Duration faceLostCooldown = Duration(seconds: 5);
  // ไม่พบหน้าต่อเนื่องนานผิดปกติ (เช่น มือถือหล่น, คนขับทรุดจนหลุดกรอบกล้อง)
  // ถือเป็นเหตุฉุกเฉิน ต้องบังคับเข้าสถานะแดงทันที ไม่ปล่อยให้เป็นแค่คะแนนสะสมที่ decay หายได้
  static const Duration criticalFaceLostThreshold = Duration(seconds: 4);

  static const Duration comboWindow = Duration(seconds: 6);
  static const Duration comboCooldown = Duration(seconds: 8);

  // ---------- state ----------
  final ValueNotifier<double> scoreNotifier = ValueNotifier<double>(0);
  final List<RiskEvent> _recentEvents = [];
  final List<RiskEvent> tripLog = [];

  double get score => scoreNotifier.value;

  Timer? _decayTimer;

  DateTime? _eyeClosedStart;
  bool _eyeTier1Fired = false;
  bool _eyeTier2Fired = false;
  final List<DateTime> _blinkTimestamps = [];
  DateTime? _lastDroopyFire;

  DateTime? _yawnStart;
  final List<DateTime> _yawnTimestamps = [];
  DateTime? _lastYawnCounted;

  DateTime? _headNodStart;
  DateTime? _lastHeadNodFire;

  DateTime? _faceLostStart;
  DateTime? _lastFaceLostFire;
  bool _criticalFaceLostFired = false;

  DateTime? _lastComboFire;

  RiskScoreManager() {
    _decayTimer = Timer.periodic(decayInterval, (_) => _decay());
  }

  void dispose() {
    _decayTimer?.cancel();
    scoreNotifier.dispose();
  }

  void _decay() {
    if (scoreNotifier.value > 0) {
      scoreNotifier.value = (scoreNotifier.value - decayPerTick).clamp(0, 100);
    }
  }

  void _addScore(String category, String type, int points) {
    final now = DateTime.now();
    scoreNotifier.value = (scoreNotifier.value + points).clamp(0, 100);
    final event = RiskEvent(now, category, type, points);
    _recentEvents.add(event);
    tripLog.add(event);
    _recentEvents.removeWhere((e) => now.difference(e.time) > comboWindow);
    _checkCombo(now);
  }

  void _checkCombo(DateTime now) {
    if (_lastComboFire != null && now.difference(_lastComboFire!) < comboCooldown) {
      return;
    }
    final distinctCategories = _recentEvents
        .where((e) => e.category != 'combo')
        .map((e) => e.category)
        .toSet();

    if (distinctCategories.length >= 3) {
      _lastComboFire = now;
      scoreNotifier.value = (scoreNotifier.value + 20).clamp(0, 100);
      tripLog.add(RiskEvent(now, 'combo', 'combo', 20));
    } else if (distinctCategories.length == 2) {
      _lastComboFire = now;
      scoreNotifier.value = (scoreNotifier.value + 10).clamp(0, 100);
      tripLog.add(RiskEvent(now, 'combo', 'combo', 10));
    }
  }

  // ============ 1) ตา ============
  void onEyeState(bool isClosed) {
    final now = DateTime.now();

    if (isClosed) {
      _eyeClosedStart ??= now;
      final elapsed = now.difference(_eyeClosedStart!);

      if (elapsed >= eyeShortThreshold && !_eyeTier1Fired) {
        _eyeTier1Fired = true;
        _addScore('eye', 'eye_closed_short', 10);
      }
      if (elapsed >= eyeLongThreshold && !_eyeTier2Fired) {
        _eyeTier2Fired = true;
        _addScore('eye', 'eye_closed_long', 10);
      }
    } else {
      if (_eyeClosedStart != null) {
        final elapsed = now.difference(_eyeClosedStart!);
        if (elapsed < eyeShortThreshold) {
          _recordBlink(now);
        }
      }
      _eyeClosedStart = null;
      _eyeTier1Fired = false;
      _eyeTier2Fired = false;
    }
  }

  void _recordBlink(DateTime now) {
    _blinkTimestamps.add(now);
    _blinkTimestamps.removeWhere((t) => now.difference(t) > blinkWindow);

    if (_blinkTimestamps.length >= blinkCountThreshold) {
      final cooldownOk = _lastDroopyFire == null || now.difference(_lastDroopyFire!) > droopyCooldown;
      if (cooldownOk) {
        _lastDroopyFire = now;
        _addScore('eye', 'droopy', 5);
      }
    }
  }

  // ============ 2) ปาก ============
  /// isYawning = true เมื่อเฟรมนี้ตรวจว่า yawning (ต้องเรียกทุกเฟรม ทั้ง true/false)
  void onMouthState(bool isYawning) {
    final now = DateTime.now();
    if (isYawning) {
      _yawnStart ??= now;
      return;
    }

    if (_yawnStart == null) return; // ปากปิดอยู่แล้ว ไม่มีอะไรต้องทำ

    final openDuration = now.difference(_yawnStart!);
    _yawnStart = null;

    // อ้าปากสั้นเกินไป (เช่น พูดคุย หัวเราะ) ไม่นับเป็นหาว
    if (openDuration < minYawnDuration) return;

    final cooldownOk = _lastYawnCounted == null || now.difference(_lastYawnCounted!) > yawnCooldown;
    if (!cooldownOk) return;

    _lastYawnCounted = now;
    _yawnTimestamps.add(now);
    _yawnTimestamps.removeWhere((t) => now.difference(t) > yawnWindow);

    if (_yawnTimestamps.length >= 2) {
      _addScore('mouth', 'yawn_repeat', 15);
    } else {
      _addScore('mouth', 'yawn', 10);
    }
  }

  // ============ 3) หัว ============
  void onHeadPitch(double pitchAngle) {
    final now = DateTime.now();
    final isNodding = pitchAngle.abs() > headNodAngleThreshold;

    if (isNodding) {
      _headNodStart ??= now;
      final elapsed = now.difference(_headNodStart!);
      if (elapsed >= headNodSustain) {
        final cooldownOk = _lastHeadNodFire == null || now.difference(_lastHeadNodFire!) > headNodCooldown;
        if (cooldownOk) {
          _lastHeadNodFire = now;
          _addScore('head', 'head_nod', 15);
        }
      }
    } else {
      _headNodStart = null;
    }
  }

  // ============ 4) ไม่พบตาทั้งสองข้าง ============
  void onFaceVisibility(bool eyesVisible) {
    final now = DateTime.now();
    if (!eyesVisible) {
      _faceLostStart ??= now;
      final elapsed = now.difference(_faceLostStart!);

      if (elapsed >= faceLostThreshold) {
        final cooldownOk = _lastFaceLostFire == null || now.difference(_lastFaceLostFire!) > faceLostCooldown;
        if (cooldownOk) {
          _lastFaceLostFire = now;
          _addScore('face', 'face_lost', 10);
        }
      }

      // กรณีร้ายแรง: หน้าหายต่อเนื่องนานผิดปกติ บังคับเข้าสถานะแดงทันที
      // ไม่รอให้คะแนนสะสมถึง เพราะ decay อาจทำให้คะแนนไม่ถึงเกณฑ์ทันเวลา
      if (elapsed >= criticalFaceLostThreshold && !_criticalFaceLostFired) {
        _criticalFaceLostFired = true;
        scoreNotifier.value = 100;
        tripLog.add(RiskEvent(now, 'face', 'face_lost_critical', 0));
      }
    } else {
      _faceLostStart = null;
      _criticalFaceLostFired = false;
    }
  }

  // ============ เริ่ม/จบทริป ============
  void resetForNewTrip() {
    scoreNotifier.value = 0;
    tripLog.clear();
    _recentEvents.clear();
    _eyeClosedStart = null;
    _eyeTier1Fired = false;
    _eyeTier2Fired = false;
    _blinkTimestamps.clear();
    _yawnStart = null;
    _yawnTimestamps.clear();
    _headNodStart = null;
    _faceLostStart = null;
    _criticalFaceLostFired = false;
  }

  Map<String, int> tripSummaryCounts() {
    final counts = <String, int>{};
    for (final e in tripLog) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }
    return counts;
  }
}