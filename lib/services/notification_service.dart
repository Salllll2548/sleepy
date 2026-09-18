import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// จัดการแจ้งเตือนสองแบบ:
/// 1) "ต้องการเปิดแอปตรวจจับอาการหลับในไหม" ตอนบลูทูธรถเชื่อมต่อ
/// 2) แจ้งเตือนฉุกเฉินตอนคะแนนความเสี่ยงถึงเกณฑ์ (ใช้คู่กับ AlertService)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init({
    required void Function(NotificationResponse) onNotificationTap,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );
  }

  /// เรียกตอนตรวจพบว่าเชื่อมต่อบลูทูธรถยนต์แล้ว
  Future<void> showOpenAppPrompt() async {
    const details = AndroidNotificationDetails(
      'bluetooth_prompt_channel',
      'เชื่อมต่อรถยนต์',
      channelDescription: 'แจ้งเตือนเมื่อเชื่อมต่อบลูทูธรถยนต์',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      1,
      'เชื่อมต่อบลูทูธรถยนต์แล้ว',
      'ต้องการเปิดแอปตรวจจับอาการหลับในหรือไม่?',
      const NotificationDetails(android: details),
      payload: 'open_detection',
    );
  }

  /// แจ้งเตือนฉุกเฉินตอนคะแนนความเสี่ยงถึงเกณฑ์
  Future<void> showDrowsinessAlert() async {
    const details = AndroidNotificationDetails(
      'drowsiness_alert_channel',
      'แจ้งเตือนอาการหลับใน',
      channelDescription: 'แจ้งเตือนเมื่อตรวจพบความเสี่ยงหลับใน',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
    );
    await _plugin.show(
      2,
      'ตรวจพบความเสี่ยงหลับใน!',
      'กรุณาหยุดพักรถทันที',
      const NotificationDetails(android: details),
    );
  }
}
