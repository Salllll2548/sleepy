import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// ผลลัพธ์ของการตรวจจับใบหน้าในหนึ่งเฟรม
class FaceFrameResult {
  final bool faceFound;
  final double eyeOpenProbability; // เฉลี่ยตาซ้าย-ขวา, 0 = ปิดสนิท, 1 = เปิดเต็มที่
  final double headEulerAngleX; // ก้ม/เงยหน้า (องศา) ค่าลบ = ก้มลง
  final double headEulerAngleY; // หันซ้าย-ขวา

  const FaceFrameResult({
    required this.faceFound,
    required this.eyeOpenProbability,
    required this.headEulerAngleX,
    required this.headEulerAngleY,
  });

  factory FaceFrameResult.noFace() => const FaceFrameResult(
        faceFound: false,
        eyeOpenProbability: 1,
        headEulerAngleX: 0,
        headEulerAngleY: 0,
      );
}

/// ครอบการทำงานของ Google ML Kit Face Detection
/// เลือกใช้ ML Kit แทน Teachable Machine เพราะให้ eyeOpenProbability และ
/// มุมหัวมาโดยตรง ไม่ต้องเทรนโมเดลเอง และแม่นยำกว่าสำหรับงานนี้ (ดู README)
class FaceDetectionService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // จำเป็นสำหรับ eyeOpenProbability
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
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

      return FaceFrameResult(
        faceFound: true,
        eyeOpenProbability: avgOpen,
        headEulerAngleX: face.headEulerAngleX ?? 0,
        headEulerAngleY: face.headEulerAngleY ?? 0,
      );
    } catch (_) {
      return null;
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    // หมายเหตุ: การแปลง CameraImage -> InputImage รายละเอียด rotation/format
    // แตกต่างกันเล็กน้อยระหว่าง Android/iOS และเวอร์ชัน camera plugin
    // ควรอ้างอิง ตัวอย่างทางการของ google_mlkit_face_detection (ไฟล์ตัวอย่าง
    // "live_preview" ใน pub.dev) เพื่อ mapping ImageFormatGroup ให้ตรงกับ
    // NV21 (Android) หรือ bgra8888 (iOS) — ใส่ placeholder ไว้ให้ต่อยอด
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size.square(image.width.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void dispose() {
    _detector.close();
  }
}
