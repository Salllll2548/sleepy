import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// ผลลัพธ์ของการตรวจจับใบหน้าในหนึ่งเฟรม
/// ฟิลด์ดิบเดิม (eyeOpenProbability, headEulerAngleX/Y) ยังอยู่ครบเหมือนเดิม
/// เพื่อไม่ให้ face_scan_screen.dart ที่อ่าน eyeOpenProbability ตรงๆ พัง —
/// เพิ่มฟิลด์ boolean ใหม่ (eyesClosed, isYawning) ที่คำนวณพร้อมส่งเข้า
/// RiskScoreManager ได้ทันที และ mouthOpenRatio (ดิบ) ไว้ใช้คาลิเบรต
class FaceFrameResult {
  final bool faceFound;
  final double eyeOpenProbability;
  final double headEulerAngleX;
  final double headEulerAngleY;
  final bool eyesClosed;
  final bool isYawning;
  final double? mouthOpenRatio; // null ถ้าหาจุด contour ปากไม่เจอ

  const FaceFrameResult({
    required this.faceFound,
    required this.eyeOpenProbability,
    required this.headEulerAngleX,
    required this.headEulerAngleY,
    required this.eyesClosed,
    required this.isYawning,
    this.mouthOpenRatio,
  });

  factory FaceFrameResult.noFace() => const FaceFrameResult(
        faceFound: false,
        eyeOpenProbability: 1,
        headEulerAngleX: 0,
        headEulerAngleY: 0,
        eyesClosed: false,
        isYawning: false,
      );
}

/// ครอบการทำงานของ Google ML Kit Face Detection
/// threshold ปรับได้จากภายนอก (ไม่ const) เพื่อให้หน้า Face Scan ตั้งค่า
/// เฉพาะคนทับได้หลังคาลิเบรตเสร็จ — ไม่งั้นทุกคนต้องใช้ค่าเดียวกันตายตัว
class FaceDetectionService {
  /// ต่ำกว่านี้ถือว่าตาปิด — default 0.4 ใช้ตอนยังไม่มีผลคาลิเบรต
  double eyeClosedThreshold;

  /// สัดส่วนปากเปิด (เทียบความสูงใบหน้า) ที่เกินถือว่ากำลังหาว
  /// default 0.10 เป็นค่าคร่าวๆ แนะนำให้คาลิเบรตเฉพาะคนแทนเสมอ
  double mouthOpenRatioThreshold;

  FaceDetectionService({
    this.eyeClosedThreshold = 0.4,
    this.mouthOpenRatioThreshold = 0.10,
  });

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // จำเป็นสำหรับ eyeOpenProbability
      enableContours: true, // ใหม่ — จำเป็นสำหรับคำนวณปากเปิด (yawn)
      enableTracking: false,
      // accurate แม่นกว่า fast สำหรับ contour แลกกับช้าลงนิดหน่อย
      // ถ้าเฟรมเรตบนเครื่องจริงหน่วงมาก ลองเปลี่ยนกลับเป็น .fast ดูได้
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  bool _isBusy = false;

  /// เรียกทุกเฟรมจากกล้อง จะข้ามเฟรมถ้ายังประมวลผลเฟรมก่อนหน้าไม่เสร็จ
  Future<FaceFrameResult?> processCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isBusy) return null;
    _isBusy = true;
    try {
      final inputImage = _toInputImage(image, camera);
      if (inputImage == null) return FaceFrameResult.noFace();

      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return FaceFrameResult.noFace();

      final face = faces.first;
      final leftOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightOpen = face.rightEyeOpenProbability ?? 1.0;
      final avgOpen = (leftOpen + rightOpen) / 2;
      final pitch = face.headEulerAngleX ?? 0;
      final yaw = face.headEulerAngleY ?? 0;
      final mouthRatio = _computeMouthOpenRatio(face);

      return FaceFrameResult(
        faceFound: true,
        eyeOpenProbability: avgOpen,
        headEulerAngleX: pitch,
        headEulerAngleY: yaw,
        eyesClosed: avgOpen < eyeClosedThreshold,
        isYawning: mouthRatio != null && mouthRatio > mouthOpenRatioThreshold,
        mouthOpenRatio: mouthRatio,
      );
    } catch (_) {
      return null;
    } finally {
      _isBusy = false;
    }
  }

  /// ระยะห่างแนวตั้งระหว่างริมฝีปากบน-ล่าง หารด้วยความสูงใบหน้า (normalize
  /// ตามระยะห่างจากกล้อง) ยิ่งค่าสูง = อ้าปากกว้าง = น่าจะกำลังหาว
  /// คืน null ถ้าหาจุด contour ปากไม่เจอ (เช่น หน้าหันข้างมากไป)
  double? _computeMouthOpenRatio(Face face) {
    final upperLip = face.contours[FaceContourType.upperLipBottom]?.points;
    final lowerLip = face.contours[FaceContourType.lowerLipTop]?.points;
    final box = face.boundingBox;
    if (upperLip == null || lowerLip == null) return null;
    if (upperLip.isEmpty || lowerLip.isEmpty) return null;
    if (box.height <= 0) return null;

    final upperY =
        upperLip.map((p) => p.y).reduce((a, b) => a + b) / upperLip.length;
    final lowerY =
        lowerLip.map((p) => p.y).reduce((a, b) => a + b) / lowerLip.length;
    final mouthOpenPx = (lowerY - upperY).abs();
    return mouthOpenPx / box.height;
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // รวมข้อมูล bytes จากทุก plane (รองรับทั้ง Android YUV420 และ iOS
    // BGRA8888) — คงวิธีแก้เดิมที่มีอยู่แล้วไว้ ไม่เปลี่ยนส่วนนี้
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void dispose() {
    _detector.close();
  }
}