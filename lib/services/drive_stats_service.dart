import '../models/drive_session_model.dart';

/// เก็บ/สรุปสถิติของแต่ละทริป — ตอนนี้คืน mock data ไว้ก่อนให้ UI ต่อได้
/// จริง ๆ ควรบันทึกทุกทริปลง local db (เช่น sqflite) หรือ backend แล้ว
/// สรุปผลในนี้แทนการ mock
class DriveStatsService {
  Future<List<DailyAlertnessStat>> getWeeklyStats() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      DailyAlertnessStat(dayLabel: 'จ.', alertnessPercent: 80),
      DailyAlertnessStat(dayLabel: 'อ.', alertnessPercent: 72),
      DailyAlertnessStat(dayLabel: 'พ.', alertnessPercent: 45),
      DailyAlertnessStat(dayLabel: 'พฤ.', alertnessPercent: 65),
      DailyAlertnessStat(dayLabel: 'ศ.', alertnessPercent: 88),
      DailyAlertnessStat(dayLabel: 'ส.', alertnessPercent: 90),
      DailyAlertnessStat(dayLabel: 'อา.', alertnessPercent: 76),
    ];
  }

  Future<double> getAverageAlertnessPercent() async {
    final stats = await getWeeklyStats();
    if (stats.isEmpty) return 0;
    final sum = stats.fold<double>(0, (acc, s) => acc + s.alertnessPercent);
    return sum / stats.length;
  }

  Future<List<DriveEvent>> getRecentEvents() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      DriveEvent(
        title: 'ตรวจพบอาการเริ่มใกล้หลับ',
        subtitle: 'Risk: 68/100 • เมื่อวาน',
        badgeLabel: '2 ครั้ง',
        isWarning: true,
      ),
      DriveEvent(
        title: 'เดินทางปลอดภัย',
        subtitle: 'Risk: 15/100 • เมื่อวันอาทิตย์ • 54.6 กม.',
        badgeLabel: '88%',
      ),
    ];
  }
}
