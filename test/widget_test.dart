import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sleepy/app.dart';

void main() {
  testWidgets('App เปิดมาแล้วเจอปุ่ม Log-in', (WidgetTester tester) async {
    await tester.pumpWidget(const DrowsinessApp());

    // หน้าแรกของแอปคือ LoginScreen ควรเจอข้อความ/ปุ่ม Log-in
    expect(find.text('Log-in'), findsOneWidget);
  });
}