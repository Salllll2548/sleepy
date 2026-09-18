/// ข้อมูลทริปการขับขี่หนึ่งครั้ง ใช้แสดงในหน้า Home (ความเร็ว/ระยะทาง/เวลา)
/// และหน้าสถิติ (กราฟรายวัน + เหตุการณ์ล่าสุด)
class DriveSession {
  final DateTime startedAt;
  final double speedKmh;
  final double distanceKm;
  final Duration elapsed;
  final double currentRiskScore; // 0-100
  final double alertnessScore; // 100 - risk โดยประมาณ แสดงในวงแหวน

  const DriveSession({
    required this.startedAt,
    required this.speedKmh,
    required this.distanceKm,
    required this.elapsed,
    required this.currentRiskScore,
    required this.alertnessScore,
  });

  factory DriveSession.notStarted() => DriveSession(
        startedAt: DateTime.now(),
        speedKmh: 0,
        distanceKm: 0,
        elapsed: Duration.zero,
        currentRiskScore: 0,
        alertnessScore: 0,
      );

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
