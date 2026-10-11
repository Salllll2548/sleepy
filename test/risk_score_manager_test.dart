import 'package:flutter_test/flutter_test.dart';
import 'package:sleepy/services/risk_score_manager.dart'; // <-- แก้ตรงนี้

void main() {
  group('RiskScoreManager - ตา', () {
    test('ตาปิด ~1.4 วิ (เกิน threshold ใหม่ 1.3 วิ) ควรได้ +10', () async {
      final manager = RiskScoreManager();
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 1400));
      manager.onEyeState(true);
      expect(manager.score, 10);
      manager.dispose();
    });

    test('ตาปิดเกิน 2 วิ ควรได้รวม +20 (10 + 10)', () async {
      final manager = RiskScoreManager();
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 1400));
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 700));
      manager.onEyeState(true);
      expect(manager.score, 20);
      manager.dispose();
    });

    test('กระพริบตาสั้นมาก (200ms) ไม่ควรได้คะแนน', () async {
      final manager = RiskScoreManager();
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 200));
      manager.onEyeState(false);
      expect(manager.score, 0);
      manager.dispose();
    });

    test('กระพริบตาปกติแบบนานหน่อย (1.1 วิ ไม่ถึง threshold ใหม่) ไม่ควรได้คะแนน', () async {
      final manager = RiskScoreManager();
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 1100));
      manager.onEyeState(true);
      expect(manager.score, 0); // ยังไม่ถึง 1.3 วิ จึงไม่นับ
      manager.dispose();
    });
  });

  group('RiskScoreManager - หาว', () {
    test('อ้าปากสั้นๆ แบบพูดคุย (300ms) ไม่ควรนับเป็นหาว', () async {
      final manager = RiskScoreManager();
      manager.onMouthState(true);
      await Future.delayed(const Duration(milliseconds: 300));
      manager.onMouthState(false);
      expect(manager.score, 0);
      manager.dispose();
    });

    test('อ้าปากค้างนาน 1.5 วิ (หาวจริง) ควรได้ +10', () async {
      final manager = RiskScoreManager();
      manager.onMouthState(true);
      await Future.delayed(const Duration(milliseconds: 1500));
      manager.onMouthState(false);
      expect(manager.score, 10);
      manager.dispose();
    });

    test('หาวจริงซ้ำในช่วงเวลาสั้นๆ ควรได้ +15 (ครั้งที่ 2)', () async {
      final manager = RiskScoreManager();
      manager.onMouthState(true);
      await Future.delayed(const Duration(milliseconds: 1500));
      manager.onMouthState(false); // หาวครั้งที่ 1: +10
      expect(manager.score, 10);

      await Future.delayed(const Duration(seconds: 4));
      manager.onMouthState(true);
      await Future.delayed(const Duration(milliseconds: 1500));
      manager.onMouthState(false); // หาวครั้งที่ 2: +15
      expect(manager.score, 25);
      manager.dispose();
    });
  });

  group('RiskScoreManager - ไม่พบตา/หน้า', () {
    test('ไม่เจอตาเลย 1.6 วิ ควรได้ +10', () async {
      final manager = RiskScoreManager();
      manager.onFaceVisibility(false);
      await Future.delayed(const Duration(milliseconds: 1600));
      manager.onFaceVisibility(false);
      expect(manager.score, 10);
      manager.dispose();
    });

    test('เจอตาปกติ ไม่ควรได้คะแนน', () {
      final manager = RiskScoreManager();
      manager.onFaceVisibility(true);
      expect(manager.score, 0);
      manager.dispose();
    });

    test('หน้าหายต่อเนื่องเกิน 4 วิ ควรบังคับคะแนนเป็น 100 ทันที (เคสฉุกเฉิน)', () async {
      final manager = RiskScoreManager();
      manager.onFaceVisibility(false);
      await Future.delayed(const Duration(milliseconds: 4100));
      manager.onFaceVisibility(false);
      expect(manager.score, 100);
      manager.dispose();
    });
  });

  group('RiskScoreManager - ระดับความเสี่ยง', () {
    test('คะแนน 15 ควรเป็นระดับปกติ (เขียว)', () {
      final info = getRiskLevelInfo(15);
      expect(info.level, RiskLevel.normal);
    });

    test('คะแนน 62 ควรเป็นระดับง่วง (ส้ม) และมีเสียง', () {
      final info = getRiskLevelInfo(62);
      expect(info.level, RiskLevel.moderate);
      expect(info.playSound, true);
      expect(info.useTts, false);
    });

    test('คะแนน 87 ควรเป็นระดับเสี่ยงหลับใน (แดง) และพูด TTS', () {
      final info = getRiskLevelInfo(87);
      expect(info.level, RiskLevel.severe);
      expect(info.useTts, true);
    });
  });
}
