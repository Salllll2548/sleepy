import 'package:flutter/services.dart';

enum CarBluetoothEvent { connected, disconnected }

/// รับ event จาก native Android BroadcastReceiver (ดู
/// android/.../BluetoothConnectionReceiver.kt) ผ่าน EventChannel
/// เหตุผลที่ใช้ native receiver แทน plugin สำเร็จรูป: ต้องดักจับ
/// android.bluetooth.device.action.ACL_CONNECTED ซึ่งเป็น system broadcast
/// ที่ทำงานได้แม้แอปไม่ได้เปิดอยู่ — ไม่มี Flutter plugin ที่ทำสิ่งนี้ได้ตรง ๆ
class BluetoothService {
  static const _eventChannel =
      EventChannel('drowsiness_app/bluetooth_events');
  static const _methodChannel =
      MethodChannel('drowsiness_app/bluetooth_methods');

  Stream<CarBluetoothEvent>? _stream;

  Stream<CarBluetoothEvent> get onCarConnectionChanged {
    _stream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return event == 'connected'
          ? CarBluetoothEvent.connected
          : CarBluetoothEvent.disconnected;
    });
    return _stream!;
  }

  /// ตั้งค่าว่าอุปกรณ์ (ชื่อ/MAC) ไหนคือ "รถ" ที่จะดัก event ด้วย
  /// เรียกจากหน้า Settings หลังผู้ใช้เลือกอุปกรณ์ที่เคยจับคู่ไว้แล้ว
  Future<void> setTargetCarDevice({
    required String deviceName,
    String? macAddress,
  }) async {
    await _methodChannel.invokeMethod('setTargetDevice', {
      'name': deviceName,
      'mac': macAddress,
    });
  }

  /// ดึงรายชื่ออุปกรณ์บลูทูธที่เคยจับคู่ (paired) ไว้แล้วในเครื่อง
  Future<List<Map<String, String>>> getPairedDevices() async {
    final result =
        await _methodChannel.invokeMethod<List<dynamic>>('getPairedDevices');
    if (result == null) return [];
    return result
        .map((e) => Map<String, String>.from(e as Map))
        .toList(growable: false);
  }
}
