import 'dart:async';
import 'package:flutter/material.dart';
 
/// ระดับความเสี่ยง 4 ระดับ พร้อมสี/ข้อความ/พฤติกรรมของแอปในแต่ละระดับ
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
      playSound: false, // ตามสเปก: ระดับนี้แค่โชว์บนจอ ยังไม่ต้องมีเสียง
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
      useTts: true, // ระดับนี้เท่านั้นที่พูดผ่าน Bluetooth ไปลำโพงรถ
    );
  }
}
 
/// event ที่เกิดขึ้น ใช้ track "อะไรเกิดขึ้นตอนไหน" สำหรับ history/trip summary
/// category ใช้แยกว่าเป็นพฤติกรรม "หมวด" ไหน (eye/mouth/head/face) สำหรับเช็ค combo
/// type ใช้เป็นชื่อเฉพาะของ event นั้นๆ สำหรับ log/สรุปท้ายทริป
class RiskEvent {
  final DateTime time;
  final String category; // 'eye' | 'mouth' | 'head' | 'face' | 'combo'
  final String type; // 'eye_closed_short' / 'eye_closed_long' / 'droopy' / 'yawn' / 'yawn_repeat' / 'head_nod' / 'face_lost' / 'combo'
  final int points;
  const RiskEvent(this.time, this.category, this.type, this.points);
}
 
class RiskScoreManager {
  // ---------- ค่าที่ปรับได้ (tune ตอนทดสอบจริง) ----------
  static const double decayPerTick = 2.0; // ลดคะแนนกี่แต้มต่อ tick
  static const Duration decayInterval = Duration(seconds: 5);
 
  static const Duration eyeShortThreshold = Duration(milliseconds: 500);
  static const Duration eyeLongThreshold = Duration(seconds: 8);
 
  static const Duration blinkWindow = Duration(seconds: 30);
  static const int blinkCountThreshold = 8; // กระพริบเกินกี่ครั้งใน blinkWindow ถือว่า "ตาปรือ"
  static const Duration droopyCooldown = Duration(seconds: 30);
 
  static const Duration yawnWindow = Duration(minutes: 3);
  static const Duration yawnCooldown = Duration(seconds: 6); // กันนับหาวครั้งเดียวซ้ำ
 
  static const double headNodAngleThreshold = 20.0; // องศา ก้มเกินนี้ถือว่า nod
  static const Duration headNodSustain = Duration(milliseconds: 600);
  static const Duration headNodCooldown = Duration(seconds: 6);
 
  static const Duration faceLostThreshold = Duration(seconds: 10);
  static const Duration faceLostCooldown = Duration(seconds: 10);
 
  static const Duration comboWindow = Duration(seconds: 6);
  static const Duration comboCooldown = Duration(seconds: 8);
 
  // ---------- state ----------
  final ValueNotifier<double> scoreNotifier = ValueNotifier<double>(0);
  final List<RiskEvent> _recentEvents = []; // เก็บไว้เช็ค combo (ไม่รวม combo event เอง)
  final List<RiskEvent> tripLog = []; // ทั้งหมดตั้งแต่เริ่มทริป ไว้ทำกราฟ/สรุปท้ายทริป
 
  double get score => scoreNotifier.value;
 
  Timer? _decayTimer;
 
  // eye tracking
  DateTime? _eyeClosedStart;
  bool _eyeTier1Fired = false;
  bool _eyeTier2Fired = false;
  final List<DateTime> _blinkTimestamps = [];
  DateTime? _lastDroopyFire;
 
  // yawn tracking
  DateTime? _yawnStart;
  final List<DateTime> _yawnTimestamps = [];
  DateTime? _lastYawnCounted;
 
  // head pose tracking
  DateTime? _headNodStart;
  DateTime? _lastHeadNodFire;
 
  // face visibility tracking
  DateTime? _faceLostStart;
  DateTime? _lastFaceLostFire;
 
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
 
  /// ยิง bonus ก็ต่อเมื่อมี "หมวดพฤติกรรมต่างกัน" เกิดใกล้ๆ กัน
  /// (ตา+ปาก, ตา+หัว, ฯลฯ) ไม่ใช่แค่ event ชื่อต่างกันในหมวดเดียวกัน
  /// เช่น eye_closed_short กับ eye_closed_long ทั้งคู่คือหมวด 'eye' เหมือนกัน ไม่ควรนับเป็น combo
  void _checkCombo(DateTime now) {
    if (_lastComboFire != null && now.difference(_lastComboFire!) < comboCooldown) {
      return; // ยังอยู่ใน cooldown ของ combo เอง กันยิงรัว
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
 
  // ============ 1) ตา: เรียกทุกเฟรมที่โมเดลตรวจจับตาได้ ============
  /// isClosed = true เมื่อเฟรมนี้ตรวจว่า eye_closed, false เมื่อ eye_opened
  void onEyeState(bool isClosed) {
    final now = DateTime.now();
 
    if (isClosed) {
      _eyeClosedStart ??= now;
      final elapsed = now.difference(_eyeClosedStart!);
 
      // ยิงทันทีระหว่างที่ตายังปิดต่อเนื่อง ไม่ต้องรอให้ลืมตาก่อน
      // เผื่อกรณีหลับสนิทแล้วไม่ลืมตาอีกเลย (สำคัญกว่าการรอ debounce)
      if (elapsed >= eyeShortThreshold && !_eyeTier1Fired) {
        _eyeTier1Fired = true;
        _addScore('eye', 'eye_closed_short', 10);
      }
      if (elapsed >= eyeLongThreshold && !_eyeTier2Fired) {
        _eyeTier2Fired = true;
        _addScore('eye', 'eye_closed_long', 10); // รวมกับ tier1 แล้ว = 20 ตามสเปก
      }
    } else {
      // ตาลืมแล้ว: ถ้าเพิ่งปิดสั้นๆ (ไม่ถึง eyeShortThreshold) นับเป็น "กระพริบ" ปกติ
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
 
  // ============ 2) ปาก: เรียกทุกเฟรมที่โมเดลตรวจจับปากได้ ============
  /// isYawning = true เมื่อเฟรมนี้ตรวจว่า yawning
  void onMouthState(bool isYawning) {
    final now = DateTime.now();
    if (isYawning) {
      _yawnStart ??= now;
    } else if (_yawnStart != null) {
      // ปากปิดแล้ว = จบการหาวครั้งนี้ นับคะแนนตอนนี้
      final cooldownOk = _lastYawnCounted == null || now.difference(_lastYawnCounted!) > yawnCooldown;
      if (cooldownOk) {
        _lastYawnCounted = now;
        _yawnTimestamps.add(now);
        _yawnTimestamps.removeWhere((t) => now.difference(t) > yawnWindow);
 
        if (_yawnTimestamps.length >= 2) {
          _addScore('mouth', 'yawn_repeat', 15); // หาวซ้ำในช่วง yawnWindow
        } else {
          _addScore('mouth', 'yawn', 10); // หาวครั้งแรกในช่วง window
        }
      }
      _yawnStart = null;
    }
  }
 

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
 
  // ============ 4) ไม่พบตาทั้งสองข้าง (เหม่อ/หันมองข้างทาง) ============
  /// เรียกทุกเฟรม: eyesVisible = false เมื่อเฟรมนั้นไม่มี eye_open หรือ eye_closed เลยแม้แต่ข้างเดียว
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
    } else {
      _faceLostStart = null;
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
  }
 
  /// สรุปท้ายทริป: จำนวนครั้งของแต่ละพฤติกรรม
  Map<String, int> tripSummaryCounts() {
    final counts = <String, int>{};
    for (final e in tripLog) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }
    return counts;
  }
}
 
