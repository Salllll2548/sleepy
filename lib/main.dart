import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'features/driving/screens/driving_detection_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init(
    onNotificationTap: (NotificationResponse response) {
      if (response.payload == 'open_detection') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const DrivingDetectionScreen()),
        );
      }
    },
  );

  runApp(const DrowsinessApp());
}
