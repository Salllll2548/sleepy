import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'notification_service.dart';

/// เรียกเมื่อ risk score ถึงเกณฑ์ — เล่นเสียงเตือนดัง ๆ + สั่นค้าง + push notification
class AlertService {
  final AudioPlayer _player = AudioPlayer();
  bool _isAlerting = false;

  Future<void> triggerAlert() async {
    if (_isAlerting) return; // กันเตือนซ้ำถี่เกินไป
    _isAlerting = true;

    await NotificationService().showDrowsinessAlert();

    // เล่นเสียง alarm วนซ้ำ — วางไฟล์เสียงไว้ที่ assets/sounds/alarm.mp3
    // แล้วประกาศใน pubspec.yaml ใต้ flutter: assets:
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alarm.mp3'));

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500], repeat: 0);
    }
  }

  /// เรียกเมื่อผู้ใช้กดยืนยันว่าไหวแล้ว หรือคะแนนลดลงต่ำกว่าเกณฑ์
  Future<void> stopAlert() async {
    _isAlerting = false;
    await _player.stop();
    Vibration.cancel();
  }
}
