// วางไฟล์นี้ไว้ใน test/risk_score_manager_test.dart
// แก้บรรทัด import ด้านล่างให้ตรงกับชื่อโปรเจกต์จริงของคุณ (ดูชื่อ package ใน pubspec.yaml)
// รันด้วยคำสั่ง: flutter test test/risk_score_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sleepy/risk_score_manager.dart'; // <-- แก้ตรงนี้

void main() {
  group('RiskScoreManager - ตา', () {
    test('ตาปิด ~1.2 วิ ควรได้ +10', () async {
      final manager = RiskScoreManager();
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 1200));
      manager.onEyeState(true); // เรียกซ้ำตอนตายังปิดอยู่ ให้เช็ค elapsed time
      expect(manager.score, 10);
      manager.dispose();
    });

    test('ตาปิดเกิน 2 วิ ควรได้รวม +20 (10 + 10)', () async {
      final manager = RiskScoreManager();
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 1200));
      manager.onEyeState(true);
      await Future.delayed(const Duration(milliseconds: 1000));
      manager.onEyeState(true);
      expect(manager.score, 20);
      manager.dispose();
    });

    test('กระพริบตาสั้นๆ ปกติ ไม่ควรได้คะแนน', () async {
      final manager = RiskScoreManager();
      manager.onEyeState(true);
      await Future.delayed(
          const Duration(milliseconds: 200)); // ปิดสั้นมาก = กระพริบปกติ
      manager.onEyeState(false);
      expect(manager.score, 0);
      manager.dispose();
    });
  });

  group('RiskScoreManager - หาว', () {
    test('หาวครั้งแรก +10', () {
      final manager = RiskScoreManager();
      manager.onMouthState(true);
      manager.onMouthState(false); // ปากปิด = จบการหาว
      expect(manager.score, 10);
      manager.dispose();
    });

    test('หาวซ้ำในช่วงเวลาสั้นๆ ควรได้ +15 (ครั้งที่ 2)', () async {
      final manager = RiskScoreManager();
      manager.onMouthState(true);
      manager.onMouthState(false); // หาวครั้งที่ 1: +10
      expect(manager.score, 10);

      await Future.delayed(
          const Duration(seconds: 4)); // เกิน cooldown กันนับซ้ำ
      manager.onMouthState(true);
      manager.onMouthState(false); // หาวครั้งที่ 2: +15
      expect(manager.score, 25);
      manager.dispose();
    });
  });

  group('RiskScoreManager - ไม่พบตา', () {
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
