import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../services/voice_service.dart';
import 'package:camera/camera.dart'; 

class CameraProvider with ChangeNotifier {
  final CameraService _cameraService = CameraService();
  bool _isInitialized = false;
  bool _isDetecting = false; 

  Function(CameraImage)? _onImageAvailableCallback; // حفظ الكولباك لتسهيل تبديل الكاميرا

  // --- منطقة التحكم المشتركة للزميلات ---
  // يمكن لكل زميلة تغيير هذا الرقم في ملفها الخاص حسب سرعة الموديل:
  // - العملات: 500ms (نصف ثانية)
  // - الأشياء: 300ms (أسرع)
  // - القراءة: 1000ms (أبطأ لتفادي الأخطاء)
  static int processInterval = 500; 
  DateTime _lastProcessTime = DateTime.now();
  // -------------------------------------

  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  
  CameraController? get controller => _cameraService.controller;

  // دالة لتغيير السرعة ديناميكياً (يمكن استدعاؤها عند تغيير المهمة)
  void setTaskSpeed(int milliseconds) {
    processInterval = milliseconds;
  }

  void processResult(double x, double confidence, String taskType) {
    if (confidence < 0.5) return; 

    String message = "";
    bool isGuidance = false;

    if (taskType == 'COIN') {
      if (x < 150) { message = "تَحَرَّكْ لِلْيَسَارِ"; isGuidance = true; }
      else if (x > 250) { message = "تَحَرَّكْ لِلْيَمِينِ"; isGuidance = true; }
      else { message = "الْعُمُلَةُ فِي الْمُنْتَصَفِ"; isGuidance = false; }
    } 
    
    VoiceService.speak(text: message, isGuidance: isGuidance);
  }

  Future<void> setupCamera({CameraLensDirection? preferredDirection}) async {
    if (!_isInitialized) {
      await _cameraService.initialize(preferredDirection: preferredDirection);
      _isInitialized = true;
      notifyListeners(); 
    }
  }

  void startDetection(Function(CameraImage) onImageAvailable) {
    _onImageAvailableCallback = onImageAvailable;
    if (_isInitialized && !_isDetecting) {
      _isDetecting = true;
      _cameraService.controller?.startImageStream((CameraImage image) {
        
        // --- تطبيق التوقيت المشترك ---
        final now = DateTime.now();
        if (now.difference(_lastProcessTime).inMilliseconds < processInterval) {
          return; 
        }
        _lastProcessTime = now;
        // -----------------------------

        _onImageAvailableCallback?.call(image);
      });
      notifyListeners();
    }
  }

  Future<void> stopDetection() async {
    if (_isDetecting) {
      try {
        await _cameraService.controller?.stopImageStream();
      } catch (e) {
        print("❌ [CameraProvider] خطأ في إيقاف بث الكاميرا: $e");
      }
      _isDetecting = false;
      notifyListeners();
    }
  }

  Future<void> toggleCamera() async {
    if (!_isInitialized) return;
    
    bool wasDetecting = _isDetecting;
    if (wasDetecting) {
      await stopDetection();
    }

    // 1. تحويل حالة الجاهزية إلى false وتنبيه الواجهة لتدمير الـ CameraPreview وتحرير الـ Surface
    _isInitialized = false;
    notifyListeners();

    // 2. تأخير قصير جداً ليعيد نظام فلاتر بناء الواجهة وعرض مؤشر التحميل بدلاً من الكاميرا
    await Future.delayed(const Duration(milliseconds: 100));

    // 3. تبديل الكاميرا في الخدمة (التدمير والإنشاء الجديد)
    await _cameraService.toggleCamera();
    _isInitialized = true;
    
    if (wasDetecting && _onImageAvailableCallback != null) {
      startDetection(_onImageAvailableCallback!);
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}