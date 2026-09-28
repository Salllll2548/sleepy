/// ข้อมูลทริปการขับขี่หนึ่งครั้ง ใช้เก็บเวลาที่เริ่มขับและเวลารวมในการขับขี่
class DriveSession {
  final Duration elapsed;   // เวลารวมที่ใช้ขับขี่ (เช่น 15 นาที 30 วินาที)
  final DateTime startedAt; // เวลาที่เริ่มขับขี่

  DriveSession({
    required this.elapsed,
    required this.startedAt,
  });

  /// สถานะเริ่มต้น (ยังไม่ได้เริ่มขับ)
  factory DriveSession.notStarted() => DriveSession(
        startedAt: DateTime.now(),
        elapsed: Duration.zero,
      );

  /// ดึงข้อความแสดงจำนวนนาทีสำหรับนำไปโชว์ใน UI
  String get elapsedLabel {
    final minutes = elapsed.inMinutes;
    return '$minutes นาที';
  }
}

/// เหตุการณ์ที่เกิดระหว่างขับ (การ์ด "เหตุการณ์ล่าสุด" ในหน้าสถิติ)
class DriveEvent {
  final String title;
  final String subtitle;
  final String badgeLabel; // เช่น "2 ครั้ง" หรือ "88%"
  final bool isWarning;

  const DriveEvent({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    this.isWarning = false,
  });
}

/// สรุปสถิติรายวันหนึ่งแท่งในกราฟ
class DailyAlertnessStat {
  final String dayLabel; // จ., อ., พ., ...
  final double alertnessPercent; // 0-100

  const DailyAlertnessStat({
    required this.dayLabel,
    required this.alertnessPercent,
  });
}