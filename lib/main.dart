import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'features/driving/screens/driving_detection_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown, // ถ้าไม่อยากให้แอปกลับหัวได้ตอนชาร์จแบต ให้ลบบรรทัดนี้ออกครับ
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
