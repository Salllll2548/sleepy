/// สถานะคะแนนความเสี่ยง ณ ขณะหนึ่ง ๆ ใช้ส่งออกไปแสดงผลบน UI
class RiskScoreState {
  /// คะแนนความเสี่ยง 0-100
  final double score;

  /// PERCLOS ปัจจุบัน (0-100) = % เฟรมที่ตาปิดใน window ล่าสุด
  final double perclos;

  /// กำลังก้มหน้า/เอียงหัวผิดปกติอยู่หรือไม่
  final bool headDroop;

  /// ถึงเกณฑ์เตือนแล้วหรือยัง
  final bool isAlert;

  const RiskScoreState({
    required this.score,
    required this.perclos,
    required this.headDroop,
    required this.isAlert,
  });

  factory RiskScoreState.initial() => const RiskScoreState(
        score: 0,
        perclos: 0,
        headDroop: false,
        isAlert: false,
      );
}
