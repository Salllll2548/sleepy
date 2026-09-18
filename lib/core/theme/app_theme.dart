import 'package:flutter/material.dart';

/// สีทั้งหมดอ้างอิงจากดีไซน์ Figma โดยตรง รวมไว้ที่เดียวกันไม่ hardcode
/// กระจายตามไฟล์ เพื่อแก้ทีเดียวถ้า designer ปรับสีทีหลัง
class AppColors {
  AppColors._();

  // โทนหลัก (ปุ่ม, header, active state) — เขียวเทียลเข้ม
  static const primary = Color(0xFF1E7A6F);
  static const primaryDark = Color(0xFF10302B);

  // พื้นหลังการ์ดเข้ม (หน้า Home / Driving detection)
  static const darkCard = Color(0xFF0D2B28);

  // วงแหวนสถานะปกติ / active (เขียวอ่อนสด)
  static const ringActive = Color(0xFFA8E063);

  // พื้นหลังแอปโทนอ่อน
  static const background = Color(0xFFF3F6F4);
  static const surface = Colors.white;

  // ปุ่มครีม (พักสติเมื่อรู้สึกล้า / สิ้นสุดการขับ)
  static const creamButton = Color(0xFFFCE8C8);
  static const creamButtonText = Color(0xFF7A5B2E);

  // ระดับความเสี่ยง (Drowsiness Risk) — ใช้คู่กับ RiskLevel ใน risk_levels.dart
  static const riskNormal = Color(0xFF4CAF50); // 0-29 ปกติ
  static const riskCaution = Color(0xFFFFC107); // 30-49 เริ่มเฝ้าระวัง
  static const riskWarning = Color(0xFFFF9800); // 50-69 เสี่ยง
  static const riskDanger = Color(0xFFF44336); // 70-100 อันตราย

  static const textMuted = Color(0xFF7C8B87);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
      );
}
