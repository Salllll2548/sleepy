import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../services/face_model_service.dart';
import '../../home/screens/home_screen.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({
    super.key,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _cameraController;

  final FaceModelService _modelService = FaceModelService();

  // ------------------------------------------------------------
  // State
  // ------------------------------------------------------------

  bool _isInitializing = true;
  bool _isScanning = false;
  bool _scanComplete = false;

  // ป้องกันการ process พร้อมกันหลาย frame
  bool _isProcessingFrame = false;

  // ป้องกัน complete stage ซ้ำ
  bool _isCompletingStage = false;

  // ประมวลผลล่าสุด
  DateTime? _lastProcessTime;

  String _statusText = 'กำลังเตรียมกล้อง...';

  String? _currentLabel;
  double _currentConfidence = 0.0;

  int _currentStage = 0;

  DateTime? _conditionStartTime;

  // ------------------------------------------------------------
  // Scan stages
  // ------------------------------------------------------------

  final List<ScanStage> _stages = [
    ScanStage(
      title: 'ขั้นตอนที่ 1',
      instruction: 'ลืมตาและมองกล้อง',
      requiredLabel: 'eye_opened',
      displayLabel: 'ลืมตา',
    ),
    ScanStage(
      title: 'ขั้นตอนที่ 2',
      instruction: 'หลับตา',
      requiredLabel: 'eye_closed',
      displayLabel: 'หลับตา',
    ),
    ScanStage(
      title: 'ขั้นตอนที่ 3',
      instruction: 'ทำท่าหาว',
      requiredLabel: 'yawning',
      displayLabel: 'หาว',
    ),
  ];

  ScanStage get _currentStageData => _stages[_currentStage];

  // ------------------------------------------------------------
  // Init
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (mounted) {
        setState(() {
          _isInitializing = true;
          _statusText = 'กำลังโหลด AI...';
        });
      }

      // โหลด TFLite
      await _modelService.loadModel();

      if (!mounted) return;

      setState(() {
        _statusText = 'กำลังเปิดกล้อง...';
      });

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('ไม่พบกล้องในอุปกรณ์');
      }

      // เลือกกล้องหน้า
      CameraDescription selectedCamera = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      _cameraController = CameraController(
        selectedCamera,

        // ใช้ LOW เพื่อลดภาระ CPU
        ResolutionPreset.low,

        enableAudio: false,

        // Android ใช้ NV21
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _statusText = 'กดปุ่มเริ่มสแกนเพื่อเริ่ม';
      });
    } catch (e) {
      debugPrint('Face scan initialization error: $e');

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _statusText = 'ไม่สามารถเปิดระบบสแกนได้';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // Start scan
  // ------------------------------------------------------------

  Future<void> _startScan() async {
    final controller = _cameraController;

    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (_isScanning) return;
    if (_scanComplete) return;

    setState(() {
      _isScanning = true;
      _currentStage = 0;
      _currentLabel = null;
      _currentConfidence = 0.0;
      _statusText = _currentStageData.instruction;
    });

    _conditionStartTime = null;
    _lastProcessTime = null;
    _isProcessingFrame = false;
    _isCompletingStage = false;

    try {
      await controller.startImageStream(
        _processCameraFrame,
      );
    } catch (e) {
      debugPrint('Could not start image stream: $e');

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _statusText = 'ไม่สามารถเริ่มกล้องได้';
      });
    }
  }

  // ------------------------------------------------------------
  // Process camera frame
  // ------------------------------------------------------------

  Future<void> _processCameraFrame(
    CameraImage cameraImage,
  ) async {
    if (!_isScanning) return;
    if (_isProcessingFrame) return;
    if (_isCompletingStage) return;

    // ==========================================================
    // IMPORTANT
    //
    // เดิม 400 ms
    // เปลี่ยนเป็น 800 ms เพื่อลดกล้องกระตุก
    // ==========================================================

    final now = DateTime.now();

    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!).inMilliseconds < 800) {
      return;
    }

    _lastProcessTime = now;
    _isProcessingFrame = true;

    try {
      // --------------------------------------------------------
      // Convert CameraImage
      // --------------------------------------------------------

      final image = _modelService.cameraImageToImage(
        cameraImage,
      );

      if (image == null) {
        return;
      }

      // --------------------------------------------------------
      // Prepare image
      // --------------------------------------------------------

      final preparedImage = _modelService.prepareImage(
        image,
        sensorOrientation: _cameraController!.description.sensorOrientation,
      );

      // --------------------------------------------------------
      // TFLite inference
      // --------------------------------------------------------

      final results = _modelService.detect(
        preparedImage,
      );

      final bestResult = _modelService.getBestResult(
        results,
      );

      if (bestResult == null) {
        _handleNoDetection();
        return;
      }

      if (!mounted) return;

      // --------------------------------------------------------
      // Update UI
      // --------------------------------------------------------

      setState(() {
        _currentLabel = bestResult.label;
        _currentConfidence = bestResult.confidence;
      });

      // --------------------------------------------------------
      // Check stage
      // --------------------------------------------------------

      _checkStageCondition(
        bestResult.label,
        bestResult.confidence,
      );
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ------------------------------------------------------------
  // No detection
  // ------------------------------------------------------------

  void _handleNoDetection() {
    if (!mounted) return;

    _conditionStartTime = null;

    setState(() {
      _currentLabel = null;
      _currentConfidence = 0.0;
      _statusText = 'ไม่พบใบหน้า กรุณามองกล้อง';
    });
  }

  // ------------------------------------------------------------
  // Check current stage
  // ------------------------------------------------------------

  void _checkStageCondition(
    String label,
    double confidence,
  ) {
    if (!_isScanning) return;
    if (_isCompletingStage) return;

    final requiredLabel = _currentStageData.requiredLabel;

    // ----------------------------------------------------------
    // ไม่ตรงกับสิ่งที่ต้องการ
    // ----------------------------------------------------------

    if (label != requiredLabel) {
      _conditionStartTime = null;

      if (!mounted) return;

      setState(() {
        _statusText = _currentStageData.instruction;
      });

      return;
    }

    // ----------------------------------------------------------
    // ตรงกับ condition
    // ----------------------------------------------------------

    _conditionStartTime ??= DateTime.now();

    final elapsed =
        DateTime.now().difference(_conditionStartTime!).inMilliseconds;

    final seconds = elapsed / 1000.0;

    if (!mounted) return;

    setState(() {
      _statusText = '${_currentStageData.displayLabel} '
          '${seconds.toStringAsFixed(1)} / 3.0 วินาที';
    });

    // ต้องตรวจเจอ condition ต่อเนื่อง 3 วินาที
    if (elapsed >= 3000) {
      _completeCurrentStage();
    }
  }

  // ------------------------------------------------------------
  // Complete current stage
  // ------------------------------------------------------------

  Future<void> _completeCurrentStage() async {
    if (_isCompletingStage) return;

    _isCompletingStage = true;
    _conditionStartTime = null;

    // ----------------------------------------------------------
    // ยังมี stage ต่อไป
    // ----------------------------------------------------------

    if (_currentStage < _stages.length - 1) {
      if (!mounted) return;

      setState(() {
        _currentStage++;

        _currentLabel = null;
        _currentConfidence = 0.0;

        _statusText = _currentStageData.instruction;
      });

      // หน่วงนิดหนึ่งเพื่อไม่ให้เปลี่ยน stage กระทันหัน
      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      _isCompletingStage = false;

      return;
    }

    // ----------------------------------------------------------
    // ครบทุก stage
    // ----------------------------------------------------------

    await _finishScan();
  }

  // ------------------------------------------------------------
  // Finish scan
  // ------------------------------------------------------------

  Future<void> _finishScan() async {
    if (!_isScanning && _scanComplete) {
      return;
    }

    // หยุดการรับ frame ก่อน
    _isScanning = false;

    // หยุด camera stream
    await _stopImageStream();

    if (!mounted) return;

    setState(() {
      _scanComplete = true;
      _statusText = 'สแกนใบหน้าสำเร็จ';
      _currentLabel = null;
      _currentConfidence = 0.0;
    });

    // ----------------------------------------------------------
    // ไป HomeScreen อัตโนมัติ
    // ----------------------------------------------------------

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
      (route) => false,
    );
  }

  // ------------------------------------------------------------
  // Stop image stream
  // ------------------------------------------------------------

  Future<void> _stopImageStream() async {
    try {
      final controller = _cameraController;

      if (controller != null &&
          controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('Stop image stream error: $e');
    }
  }

  // ------------------------------------------------------------
  // Dispose
  // ------------------------------------------------------------

  @override
  void dispose() {
    _stopImageStream();

    _cameraController?.dispose();

    _modelService.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F0),
      appBar: AppBar(
        title: const Text(
          'ยืนยันใบหน้า',
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0C897E),
        foregroundColor: Colors.white,
      ),
      body: _isInitializing ? _buildLoading() : _buildContent(),
    );
  }

  // ------------------------------------------------------------
  // Loading
  // ------------------------------------------------------------

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF0C897E),
          ),
          const SizedBox(height: 20),
          Text(
            _statusText,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Main content
  // ------------------------------------------------------------

  Widget _buildContent() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildProgress(),
          const SizedBox(height: 12),
          Expanded(
            child: _buildCamera(),
          ),
          _buildStatus(),
          const SizedBox(height: 12),
          _buildButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Progress
  // ------------------------------------------------------------

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Row(
        children: List.generate(
          _stages.length,
          (index) {
            final completed = index < _currentStage;
            final current = index == _currentStage;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    10,
                  ),
                  color: completed || current
                      ? const Color(0xFF0C897E)
                      : Colors.grey.shade300,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Camera
  // ------------------------------------------------------------

  Widget _buildCamera() {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'ไม่พบกล้อง',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(
              controller,
            ),

            // --------------------------------------------------
            // Face guide
            // --------------------------------------------------

            Center(
              child: Container(
                width: 220,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(
                    110,
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // AI label
            // --------------------------------------------------

            if (_currentLabel != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Text(
                    '${_currentLabel!} '
                    '${(_currentConfidence * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Status
  // ------------------------------------------------------------

  Widget _buildStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            _scanComplete ? '✓ สแกนเสร็จสมบูรณ์' : _currentStageData.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0C897E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
            ),
          ),
          if (!_scanComplete)
            Padding(
              padding: const EdgeInsets.only(
                top: 6,
              ),
              child: Text(
                'ตรวจพบ: ${_currentLabel ?? "-"}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Button
  // ------------------------------------------------------------

  Widget _buildButton() {
    // เมื่อ scan สำเร็จ
    // ปกติจะเปลี่ยนไป Home อัตโนมัติ
    if (_scanComplete) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Center(
            child: Text(
              'กำลังเข้าสู่หน้าหลัก...',
              style: TextStyle(
                color: Color(0xFF0C897E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isScanning ? null : _startScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0C897E),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
          ),
          child: Text(
            _isScanning ? 'กำลังสแกน...' : 'เริ่มสแกน',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ScanStage
// ============================================================

class ScanStage {
  final String title;
  final String instruction;
  final String requiredLabel;
  final String displayLabel;

  const ScanStage({
    required this.title,
    required this.instruction,
    required this.requiredLabel,
    required this.displayLabel,
  });
}
