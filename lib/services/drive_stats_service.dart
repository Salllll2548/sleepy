import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/drive_session_model.dart';

class DriveStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // -------------------------------------------------------------
  // 🟢 ส่วนที่เพิ่มใหม่: ดึงข้อมูลแบบ Real-time Stream
  // -------------------------------------------------------------

  /// Stream สถิติรายสัปดาห์ (อัปเดตอัตโนมัติทันทีที่บันทึกทริปใหม่)
  Stream<List<DailyAlertnessStat>> getWeeklyStatsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(_defaultEmptyStats());

    final now = DateTime.now();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day - 7);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .snapshots()
        .map((querySnapshot) {
      final Map<int, double> minutesPerDay = {
        1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0
      };

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = data['startedAt'] as Timestamp?;
        final seconds = data['elapsedSeconds'] as int? ?? 0;

        if (timestamp != null) {
          final date = timestamp.toDate();
          final dayOfWeek = date.weekday;
          final minutes = seconds / 60.0;

          minutesPerDay[dayOfWeek] = (minutesPerDay[dayOfWeek] ?? 0) + minutes;
        }
      }

      final dayNames = {1: 'จ.', 2: 'อ.', 3: 'พ.', 4: 'พฤ.', 5: 'ศ.', 6: 'ส.', 7: 'อา.'};

      return List.generate(7, (index) {
        final dayNum = index + 1;
        final totalMinutes = minutesPerDay[dayNum] ?? 0;

        return DailyAlertnessStat(
          dayLabel: dayNames[dayNum]!,
          alertnessPercent: totalMinutes.clamp(0, 100),
        );
      });
    });
  }

  /// Stream ประวัติทริปล่าสุด (อัปเดตอัตโนมัติ)
  Stream<List<DriveEvent>> getRecentEventsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .orderBy('startedAt', descending: true)
        .limit(5)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final seconds = data['elapsedSeconds'] as int? ?? 0;
        final minutes = (seconds / 60).round();
        final timestamp = data['startedAt'] as Timestamp?;

        String dateStr = 'ไม่ระบุวัน';
        if (timestamp != null) {
          final date = timestamp.toDate();
          dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        }

        return DriveEvent(
          title: 'ขับขี่เป็นเวลา $minutes นาที',
          subtitle: dateStr,
          badgeLabel: '$minutes นาที',
          isWarning: false,
        );
      }).toList();
    });
  }

  // -------------------------------------------------------------
  // 🔵 ส่วนเดิมของคุณ (ยังคงไว้เหมือนเดิม)
  // -------------------------------------------------------------

  /// 1. ดึงสถิติเวลารวมการขับขี่แยกตามวัน (จ.-อา.) จาก Firestore
  Future<List<DailyAlertnessStat>> getWeeklyStats() async {
    final user = _auth.currentUser;
    if (user == null) return _defaultEmptyStats();

    final now = DateTime.now();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day - 7);

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();

      final Map<int, double> minutesPerDay = {
        1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0
      };

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = data['startedAt'] as Timestamp?;
        final seconds = data['elapsedSeconds'] as int? ?? 0;

        if (timestamp != null) {
          final date = timestamp.toDate();
          final dayOfWeek = date.weekday;
          final minutes = seconds / 60.0;

          minutesPerDay[dayOfWeek] = (minutesPerDay[dayOfWeek] ?? 0) + minutes;
        }
      }

      final dayNames = {1: 'จ.', 2: 'อ.', 3: 'พ.', 4: 'พฤ.', 5: 'ศ.', 6: 'ส.', 7: 'อา.'};

      return List.generate(7, (index) {
        final dayNum = index + 1;
        final totalMinutes = minutesPerDay[dayNum] ?? 0;

        return DailyAlertnessStat(
          dayLabel: dayNames[dayNum]!,
          alertnessPercent: totalMinutes.clamp(0, 100),
        );
      });
    } catch (e) {
      return _defaultEmptyStats();
    }
  }

  /// 2. ดึงประวัติทริปล่าสุดจาก Firestore
  Future<List<DriveEvent>> getRecentEvents() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .orderBy('startedAt', descending: true)
          .limit(5)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final seconds = data['elapsedSeconds'] as int? ?? 0;
        final minutes = (seconds / 60).round();
        final timestamp = data['startedAt'] as Timestamp?;

        String dateStr = 'ไม่ระบุวัน';
        if (timestamp != null) {
          final date = timestamp.toDate();
          dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        }

        return DriveEvent(
          title: 'ขับขี่เป็นเวลา $minutes นาที',
          subtitle: dateStr,
          badgeLabel: '$minutes นาที',
          isWarning: false,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 3. คำนวณเวลาขับขี่เฉลี่ยรายวัน
  Future<double> getAverageAlertnessPercent() async {
    final weekly = await getWeeklyStats();
    if (weekly.isEmpty) return 0;

    final total = weekly.fold<double>(0, (sum, item) => sum + item.alertnessPercent);
    return total / weekly.length;
  }

  List<DailyAlertnessStat> _defaultEmptyStats() {
    return const [
      DailyAlertnessStat(dayLabel: 'จ.', alertnessPercent: 0),
      DailyAlertnessStat(dayLabel: 'อ.', alertnessPercent: 0),
      DailyAlertnessStat(dayLabel: 'พ.', alertnessPercent: 0),
      DailyAlertnessStat(dayLabel: 'พฤ.', alertnessPercent: 0),
      DailyAlertnessStat(dayLabel: 'ศ.', alertnessPercent: 0),
      DailyAlertnessStat(dayLabel: 'ส.', alertnessPercent: 0),
      DailyAlertnessStat(dayLabel: 'อา.', alertnessPercent: 0),
    ];
  }
}