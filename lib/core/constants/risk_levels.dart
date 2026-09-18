import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 4 ระดับตามที่ดีไซน์กำหนดไว้ (การ์ด "ระดับความเสี่ยง" ในหน้า Home)
enum RiskLevel { normal, caution, warning, danger }

class RiskLevelInfo {
  final RiskLevel level;
  final String rangeLabel; // เช่น "0-29"
  final String nameLabel; // เช่น "ปกติ"
  final Color color;

  const RiskLevelInfo({
    required this.level,
    required this.rangeLabel,
    required this.nameLabel,
    required this.color,
  });
}

class RiskLevels {
  RiskLevels._();

  static const all = <RiskLevelInfo>[
    RiskLevelInfo(
      level: RiskLevel.normal,
      rangeLabel: '0-29',
      nameLabel: 'ปกติ',
      color: AppColors.riskNormal,
    ),
    RiskLevelInfo(
      level: RiskLevel.caution,
      rangeLabel: '30-49',
      nameLabel: 'เริ่มเฝ้าระวัง',
      color: AppColors.riskCaution,
    ),
    RiskLevelInfo(
      level: RiskLevel.warning,
      rangeLabel: '50-69',
      nameLabel: 'เสี่ยง',
      color: AppColors.riskWarning,
    ),
    RiskLevelInfo(
      level: RiskLevel.danger,
      rangeLabel: '70-100',
      nameLabel: 'อันตรายมาก',
      color: AppColors.riskDanger,
    ),
  ];

  /// คืนข้อมูลระดับความเสี่ยงจากคะแนน 0-100
  static RiskLevelInfo fromScore(double score) {
    if (score >= 70) return all[3];
    if (score >= 50) return all[2];
    if (score >= 30) return all[1];
    return all[0];
  }
}
