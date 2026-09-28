import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceDetectionResult {
  final String label;
  final double confidence;

  FaceDetectionResult({
    required this.label,
    required this.confidence,
  });

  @override
  String toString() {
    return '$label (${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

class FaceModelService {
  Interpreter? _interpreter;

  // ============================================================
  // MODEL CONFIGURATION
  // ============================================================

  static const int inputSize = 640;

  static const List<String> labels = [
    'eye_closed',
    'eye_opened',
    'yawning',
  ];

  // เริ่มต้นที่ 0.40
  // ถ้า detect ไม่เจอเลย สามารถลดเป็น 0.25 เพื่อทดสอบได้
  static const double confidenceThreshold = 0.40;

  // ============================================================
  // LOAD MODEL
  // ============================================================

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best.tflite',
      );

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      debugPrint('======================================');
      debugPrint('TFLite model loaded successfully');
      debugPrint('Input shape: ${inputTensor.shape}');
      debugPrint('Input type: ${inputTensor.type}');
      debugPrint('Input params: ${inputTensor.params}');
      debugPrint('Output shape: ${outputTensor.shape}');
      debugPrint('Output type: ${outputTensor.type}');
      debugPrint('Output params: ${outputTensor.params}');
      debugPrint('======================================');

      final inputShape = inputTensor.shape;

      if (inputShape.length != 4) {
        throw Exception(
          'Unsupported input shape: $inputShape',
        );
      }

      debugPrint(
        'Expected input: '
        '${inputShape[0]} x '
        '${inputShape[1]} x '
        '${inputShape[2]} x '
        '${inputShape[3]}',
      );
    } catch (e) {
      debugPrint('Failed to load model: $e');
      rethrow;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  bool get isLoaded => _interpreter != null;

  // ============================================================
  // CAMERA IMAGE -> RGB IMAGE
  // ============================================================

  img.Image? cameraImageToImage(
    CameraImage cameraImage,
  ) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYuv420ToImage(cameraImage);
      }

      if (cameraImage.format.group == ImageFormatGroup.nv21) {
        return _convertNv21ToImage(cameraImage);
      }

      if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBgra8888ToImage(cameraImage);
      }

      debugPrint(
        'Unsupported image format: ${cameraImage.format.group}',
      );

      return null;
    } catch (e, stackTrace) {
      debugPrint(
        'Camera image conversion error: $e',
      );
      debugPrint('$stackTrace');

      return null;
    }
  }

  // ============================================================
  // YUV420 -> RGB
  // ============================================================

  img.Image _convertYuv420ToImage(
    CameraImage image,
  ) {
    final int width = image.width;
    final int height = image.height;

    final result = img.Image(
      width: width,
      height: height,
    );

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;

    final int uPixelStride = uPlane.bytesPerPixel ?? 1;

    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;

        final int uvX = x ~/ 2;
        final int uvY = y ~/ 2;

        final int uIndex = uvY * uRowStride + uvX * uPixelStride;

        final int vIndex = uvY * vRowStride + uvX * vPixelStride;

        if (yIndex >= yPlane.bytes.length ||
            uIndex >= uPlane.bytes.length ||
            vIndex >= vPlane.bytes.length) {
          continue;
        }

        final int yValue = yPlane.bytes[yIndex];

        final int uValue = uPlane.bytes[uIndex];

        final int vValue = vPlane.bytes[vIndex];

        final double r = yValue + 1.402 * (vValue - 128);

        final double g =
            yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);

        final double b = yValue + 1.772 * (uValue - 128);

        result.setPixelRgb(
          x,
          y,
          _clamp(r).toInt(),
          _clamp(g).toInt(),
          _clamp(b).toInt(),
        );
      }
    }

    return result;
  }

  // ============================================================
  // NV21 -> RGB
  // ============================================================

  img.Image _convertNv21ToImage(
    CameraImage image,
  ) {
    final int width = image.width;
    final int height = image.height;

    final result = img.Image(
      width: width,
      height: height,
    );

    final Plane yPlane = image.planes[0];

    final Uint8List bytes = yPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;

    /*
     * NV21:
     *
     * Y plane
     * VU VU VU...
     *
     * บาง Android device มี row stride
     * ที่มากกว่า width
     */

    final int uvRowStride =
        image.planes.length > 1 ? image.planes[1].bytesPerRow : width;

    final int uvPixelStride =
        image.planes.length > 1 ? (image.planes[1].bytesPerPixel ?? 2) : 2;

    /*
     * กรณี Camera plugin ส่ง NV21 มาเป็น
     * plane เดียว
     */
    final int frameSize = yRowStride * height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;

        if (yIndex >= bytes.length) {
          continue;
        }

        /*
         * NV21 VU plane
         */
        final int uvRow = y ~/ 2;

        final int uvCol = x ~/ 2;

        final int uvIndex =
            frameSize + uvRow * uvRowStride + uvCol * uvPixelStride;

        if (uvIndex + 1 >= bytes.length) {
          continue;
        }

        final int yValue = bytes[yIndex] & 0xff;

        final int vValue = bytes[uvIndex] & 0xff;

        final int uValue = bytes[uvIndex + 1] & 0xff;

        final double r = yValue + 1.402 * (vValue - 128);

        final double g =
            yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);

        final double b = yValue + 1.772 * (uValue - 128);

        result.setPixelRgb(
          x,
          y,
          _clamp(r).toInt(),
          _clamp(g).toInt(),
          _clamp(b).toInt(),
        );
      }
    }

    return result;
  }

  // ============================================================
  // BGRA8888 -> RGB
  // ============================================================

  img.Image _convertBgra8888ToImage(
    CameraImage image,
  ) {
    final int width = image.width;
    final int height = image.height;

    final result = img.Image(
      width: width,
      height: height,
    );

    final Plane plane = image.planes[0];

    final Uint8List bytes = plane.bytes;

    final int bytesPerRow = plane.bytesPerRow;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * bytesPerRow + x * 4;

        if (index + 3 >= bytes.length) {
          continue;
        }

        final int b = bytes[index];
        final int g = bytes[index + 1];
        final int r = bytes[index + 2];

        result.setPixelRgb(
          x,
          y,
          r,
          g,
          b,
        );
      }
    }

    return result;
  }

  // ============================================================
  // CLAMP
  // ============================================================

  double _clamp(double value) {
    return math
        .max(
          0,
          math.min(
            255,
            value,
          ),
        )
        .toDouble();
  }

  // ============================================================
  // PREPARE IMAGE
  // ============================================================

  img.Image prepareImage(
    img.Image original, {
    int sensorOrientation = 0,
  }) {
    img.Image image = original;

    if (sensorOrientation == 90) {
      image = img.copyRotate(
        image,
        angle: 90,
      );
    } else if (sensorOrientation == 180) {
      image = img.copyRotate(
        image,
        angle: 180,
      );
    } else if (sensorOrientation == 270) {
      image = img.copyRotate(
        image,
        angle: 270,
      );
    }

    /*
     * Resize ครั้งเดียวตรงนี้
     */
    image = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    return image;
  }

  // ============================================================
  // RUN MODEL
  // ============================================================

  List<FaceDetectionResult> detect(
    img.Image image,
  ) {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw Exception(
        'FaceModelService: model has not been loaded.',
      );
    }

    final inputTensor = interpreter.getInputTensor(0);

    final outputTensor = interpreter.getOutputTensor(0);

    final inputShape = inputTensor.shape;

    final outputShape = outputTensor.shape;

    debugPrint(
      'TFLite input shape: $inputShape',
    );

    debugPrint(
      'TFLite input type: ${inputTensor.type}',
    );

    debugPrint(
      'TFLite output shape: $outputShape',
    );

    debugPrint(
      'TFLite output type: ${outputTensor.type}',
    );

    // ==========================================================
    // ตรวจสอบ INPUT
    // ==========================================================

    if (inputShape.length != 4) {
      debugPrint(
        'Unsupported input tensor shape: '
        '$inputShape',
      );

      return [];
    }

    /*
     * Model ของเรา:
     *
     * [1, 3, 640, 640]
     *
     * NCHW
     */

    final int batch = inputShape[0];

    final int channels = inputShape[1];

    final int height = inputShape[2];

    final int width = inputShape[3];

    if (batch != 1 || channels != 3) {
      debugPrint(
        'Unsupported input format: '
        '$inputShape',
      );

      return [];
    }

    // ==========================================================
    // RESIZE
    // ==========================================================

    final img.Image resized = image.width == width && image.height == height
        ? image
        : img.copyResize(
            image,
            width: width,
            height: height,
          );

    // ==========================================================
    // CREATE NCHW INPUT
    //
    // [1][3][640][640]
    //
    // channel 0 = R
    // channel 1 = G
    // channel 2 = B
    // ==========================================================

    final input = List.generate(
      1,
      (_) => List.generate(
        3,
        (channel) => List.generate(
          height,
          (y) => List.generate(
            width,
            (x) {
              final pixel = resized.getPixel(
                x,
                y,
              );

              if (channel == 0) {
                return pixel.r / 255.0;
              }

              if (channel == 1) {
                return pixel.g / 255.0;
              }

              return pixel.b / 255.0;
            },
          ),
        ),
      ),
    );

    // ==========================================================
    // CREATE OUTPUT
    // ==========================================================

    final output = _createOutputBuffer(
      outputShape,
      outputTensor.type,
    );

    // ==========================================================
    // INFERENCE
    // ==========================================================

    try {
      debugPrint(
        'Starting TFLite inference...',
      );

      interpreter.run(
        input,
        output,
      );

      debugPrint(
        'TFLite inference SUCCESS',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '======================================',
      );

      debugPrint(
        'TFLite inference error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      debugPrint(
        '======================================',
      );

      return [];
    }

    // ==========================================================
    // DECODE
    // ==========================================================

    return _decodeOutput(
      output,
      outputShape,
    );
  }

  // ============================================================
  // CREATE OUTPUT BUFFER
  // ============================================================

  dynamic _createOutputBuffer(
    List<int> shape,
    TensorType type,
  ) {
    if (shape.isEmpty) {
      throw Exception(
        'Invalid output shape',
      );
    }

    if (type == TensorType.float32) {
      return _createNestedDoubleList(
        shape,
      );
    }

    if (type == TensorType.uint8) {
      return _createNestedIntList(
        shape,
      );
    }

    if (type == TensorType.int8) {
      return _createNestedIntList(
        shape,
      );
    }

    throw Exception(
      'Unsupported output type: $type',
    );
  }

  dynamic _createNestedDoubleList(
    List<int> shape, [
    int index = 0,
  ]) {
    if (index == shape.length - 1) {
      return List<double>.filled(
        shape[index],
        0.0,
      );
    }

    return List.generate(
      shape[index],
      (_) => _createNestedDoubleList(
        shape,
        index + 1,
      ),
    );
  }

  dynamic _createNestedIntList(
    List<int> shape, [
    int index = 0,
  ]) {
    if (index == shape.length - 1) {
      return List<int>.filled(
        shape[index],
        0,
      );
    }

    return List.generate(
      shape[index],
      (_) => _createNestedIntList(
        shape,
        index + 1,
      ),
    );
  }

  // ============================================================
  // DECODE OUTPUT
  // ============================================================

  List<FaceDetectionResult> _decodeOutput(
    dynamic output,
    List<int> shape,
  ) {
    final results = <FaceDetectionResult>[];

    debugPrint(
      'Decoding output shape: $shape',
    );

    if (shape.length != 3) {
      debugPrint(
        'Unexpected model output shape: '
        '$shape',
      );

      return results;
    }

    // ==========================================================
    // RAW OUTPUT DEBUG
    // ==========================================================

    debugPrint(
      '========== RAW OUTPUT DEBUG ==========',
    );

    if (shape[1] == 7) {
      final int count = math.min(
        10,
        shape[2],
      );

      for (int i = 0; i < count; i++) {
        final double x = _toDouble(
          output[0][0][i],
        );

        final double y = _toDouble(
          output[0][1][i],
        );

        final double w = _toDouble(
          output[0][2][i],
        );

        final double h = _toDouble(
          output[0][3][i],
        );

        final double eyeClosed = _toDouble(
          output[0][4][i],
        );

        final double eyeOpened = _toDouble(
          output[0][5][i],
        );

        final double yawning = _toDouble(
          output[0][6][i],
        );

        debugPrint(
          '[$i] '
          'box=($x,$y,$w,$h) '
          'closed=$eyeClosed '
          'opened=$eyeOpened '
          'yawning=$yawning',
        );
      }
    }

    debugPrint(
      '======================================',
    );

    // ==========================================================
    // [1, 7, N]
    // ==========================================================

    if (shape[1] == 7) {
      final int detections = shape[2];

      for (int i = 0; i < detections; i++) {
        final double rawClosed = _toDouble(
          output[0][4][i],
        );

        final double rawOpened = _toDouble(
          output[0][5][i],
        );

        final double rawYawning = _toDouble(
          output[0][6][i],
        );

        final scores = <double>[
          _normalizeScore(
            rawClosed,
          ),
          _normalizeScore(
            rawOpened,
          ),
          _normalizeScore(
            rawYawning,
          ),
        ];

        final int classIndex = _maxIndex(scores);

        final double confidence = scores[classIndex];

        if (confidence < confidenceThreshold) {
          continue;
        }

        if (classIndex >= labels.length) {
          continue;
        }

        results.add(
          FaceDetectionResult(
            label: labels[classIndex],
            confidence: confidence,
          ),
        );
      }
    }

    // ==========================================================
    // [1, N, 7]
    // ==========================================================

    else if (shape[2] == 7) {
      final int detections = shape[1];

      for (int i = 0; i < detections; i++) {
        final double rawClosed = _toDouble(
          output[0][i][4],
        );

        final double rawOpened = _toDouble(
          output[0][i][5],
        );

        final double rawYawning = _toDouble(
          output[0][i][6],
        );

        final scores = <double>[
          _normalizeScore(
            rawClosed,
          ),
          _normalizeScore(
            rawOpened,
          ),
          _normalizeScore(
            rawYawning,
          ),
        ];

        final int classIndex = _maxIndex(scores);

        final double confidence = scores[classIndex];

        if (confidence < confidenceThreshold) {
          continue;
        }

        if (classIndex >= labels.length) {
          continue;
        }

        results.add(
          FaceDetectionResult(
            label: labels[classIndex],
            confidence: confidence,
          ),
        );
      }
    } else {
      debugPrint(
        'Unknown YOLO output format: '
        '$shape',
      );
    }

    // ==========================================================
    // RESULT DEBUG
    // ==========================================================

    debugPrint(
      'Detection results: $results',
    );

    return results;
  }

  // ============================================================
  // NORMALIZE SCORE
  // ============================================================

  double _normalizeScore(
    double value,
  ) {
    /*
     * ถ้าเป็น probability อยู่แล้ว
     * เช่น 0.95 -> ใช้ค่าเดิม
     */
    if (value >= 0.0 && value <= 1.0) {
      return value;
    }

    /*
     * ถ้าเป็น logits
     * แปลงด้วย sigmoid
     */
    return 1.0 / (1.0 + math.exp(-value));
  }

  // ============================================================
  // TO DOUBLE
  // ============================================================

  double _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  // ============================================================
  // MAX INDEX
  // ============================================================

  int _maxIndex(
    List<double> values,
  ) {
    int index = 0;

    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[index]) {
        index = i;
      }
    }

    return index;
  }

  // ============================================================
  // CONVENIENCE
  // ============================================================

  bool hasClosedEyes(
    List<FaceDetectionResult> results,
  ) {
    return results.any(
      (result) => result.label == 'eye_closed',
    );
  }

  bool hasOpenedEyes(
    List<FaceDetectionResult> results,
  ) {
    return results.any(
      (result) => result.label == 'eye_opened',
    );
  }

  bool isYawning(
    List<FaceDetectionResult> results,
  ) {
    return results.any(
      (result) => result.label == 'yawning',
    );
  }

  // ============================================================
  // GET BEST LABEL
  // ============================================================

  String? getBestLabel(
    List<FaceDetectionResult> results,
  ) {
    final best = getBestResult(results);

    return best?.label;
  }

  // ============================================================
  // GET BEST RESULT
  // ============================================================

  FaceDetectionResult? getBestResult(
    List<FaceDetectionResult> results,
  ) {
    if (results.isEmpty) {
      return null;
    }

    results.sort(
      (a, b) => b.confidence.compareTo(
        a.confidence,
      ),
    );

    return results.first;
  }
}
