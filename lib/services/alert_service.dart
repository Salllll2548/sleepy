import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';

/// เรียกเมื่อ risk score ถึงเกณฑ์ — เล่นเสียงเตือน + สั่นซ้ำ + push notification
class AlertService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _vibrateTimer;
  bool _isAlerting = false;

  Future<void> triggerAlert() async {
    if (_isAlerting) return; // กันเตือนซ้ำถี่เกินไป
    _isAlerting = true;

    await NotificationService().showDrowsinessAlert();

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/hrk.mp3'));

    // สั่นซ้ำทุก 700 ms จนกว่าจะเรียก stopAlert()
    HapticFeedback.vibrate();
    _vibrateTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => HapticFeedback.vibrate(),
    );
  }

  Future<void> stopAlert() async {
    _isAlerting = false;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    await _player.stop();
  }
}