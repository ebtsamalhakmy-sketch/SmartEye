import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  Future<void> initialize({CameraLensDirection? preferredDirection}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // البحث عن الكاميرا المفضلة
      if (preferredDirection != null) {
        final index = _cameras.indexWhere((cam) => cam.lensDirection == preferredDirection);
        if (index != -1) {
          _currentCameraIndex = index;
        } else {
          _currentCameraIndex = 0;
        }
      } else {
        _currentCameraIndex = 0;
      }

      await _initController();
    } catch (e) {
      print("❌ [CameraService] خطأ في تهيئة الكاميرا: $e");
    }
  }

  Future<void> _initController() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    if (_cameras.isEmpty) return;
    _controller = CameraController(
      _cameras[_currentCameraIndex],
      ResolutionPreset.high, // رفع دقة الكاميرا لضمان تفاصيل واضحة للنصوص البعيدة
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  Future<void> toggleCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initController();
  }

  void dispose() {
    _controller?.dispose();
  }
}