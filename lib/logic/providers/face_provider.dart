import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import '../services/face_detector_service.dart';
import '../services/face_recognition_service.dart';
import '../services/voice_service.dart';
import '../Utils/image_converter.dart';
import 'camera_provider.dart';

class FaceProvider with ChangeNotifier {
  final FaceDetectorService _faceDetectorService = FaceDetectorService();
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();

  String _result = "جاري التجهيز...";
  String _lastSpokenText = "";
  bool _isProcessing = false;
  bool isModelLoaded = false;
  DateTime _lastProcessedTime = DateTime.now();

  // الوجه الأخير المكتشف (مفيد لحفظ الوجه وتسميته عند الضغط على تسجيل)
  CameraImage? _lastCameraImage;
  dynamic _lastDetectedFace; // يحتفظ بـ Face من ML Kit
  CameraDescription? _cameraDescription; // اتجاه الكاميرا الحالي

  String get result => _result;
  CameraImage? get lastCameraImage => _lastCameraImage;
  dynamic get lastDetectedFace => _lastDetectedFace;

  /// تحميل النموذج والبيانات عند تشغيل الشاشة
  Future<void> loadModel() async {
    if (isModelLoaded) return;
    await _faceRecognitionService.loadModel();
    isModelLoaded = true;
    _result = "وجه الكاميرا نحو الوجه";
    notifyListeners();
  }

  /// قص وتدوير الوجه المكتشف ليصبح معتدلاً ومطابقاً لإحداثيات ML Kit
  img.Image _cropFace(CameraImage cameraImage, dynamic face, CameraDescription cameraDescription) {
    final rawImage = ImageConverter.convertCameraImage(cameraImage);
    if (rawImage.width <= 1 || rawImage.height <= 1) {
      return rawImage;
    }

    // 1. تدوير الصورة الكاملة لتطابق اتجاه وحجم إحداثيات ML Kit (Portrait)
    img.Image fullImage = rawImage;
    int rotationAngle = cameraDescription.sensorOrientation;
    if (rotationAngle == 90) {
      fullImage = img.copyRotate(rawImage, angle: 90);
    } else if (rotationAngle == 270) {
      fullImage = img.copyRotate(rawImage, angle: 270);
    } else if (rotationAngle == 180) {
      fullImage = img.copyRotate(rawImage, angle: 180);
    }

    // 2. قص مستطيل الوجه باستخدام الإحداثيات المتطابقة الآن
    final rect = face.boundingBox;
    return img.copyCrop(
      fullImage,
      x: rect.left.toInt().clamp(0, fullImage.width),
      y: rect.top.toInt().clamp(0, fullImage.height),
      width: rect.width.toInt().clamp(1, fullImage.width),
      height: rect.height.toInt().clamp(1, fullImage.height),
    );
  }

  /// معالجة إطار الكاميرا البث الحي للتعرف على الوجوه
  Future<void> onFrameAvailable(CameraImage cameraImage, CameraDescription cameraDescription) async {
    if (_isProcessing || !isModelLoaded) return;

    final currentTime = DateTime.now();
    // تقليل معدل المعالجة لتفادي الضغط (إطار كل 1200 مللي ثانية)
    if (currentTime.difference(_lastProcessedTime).inMilliseconds < 1200) return;

    _isProcessing = true;
    _lastProcessedTime = currentTime;
    _lastCameraImage = cameraImage;
    _cameraDescription = cameraDescription;

    try {
      // 1. تشغيل اكتشاف الوجوه (Face Detection) باستخدام ML Kit
      final faces = await _faceDetectorService.detectFromCameraImage(cameraImage, cameraDescription);

      if (faces.isEmpty) {
        _lastDetectedFace = null;
        if (_lastSpokenText != "ابحث") {
          _lastSpokenText = "ابحث";
          _result = "وجه الكاميرا نحو الوجه";
          VoiceService.speak(text: "وَجِّهْ الْكَامِيرَا نَحْوَ الْوَجْهِ لِلتَّعَرُّفِ عَلَيْهِ", isGuidance: true);
        }
      } else {
        print("👤 [FaceProvider] تم كشف ${faces.length} وجه!");
        // نأخذ الوجه الأول المكتشف
        final face = faces.first;
        _lastDetectedFace = face;

        // 2. تحويل وقص الوجه المكتشف بعد تدوير الصورة الكاملة لتطابق الإحداثيات
        final croppedFace = _cropFace(cameraImage, face, cameraDescription);
        if (croppedFace.width > 1 && croppedFace.height > 1) {
          // 3. التعرف على الوجه ومطابقته محلياً
          final String matchName = _faceRecognitionService.recognizeFace(croppedFace);

          if (matchName == "Unknown") {
            if (_lastSpokenText != "غير معروف") {
              _lastSpokenText = "غير معروف";
              _result = "شخص غير معروف";
              VoiceService.speak(text: "شَخْصٌ غَيْرُ مَعْرُوفٍ أَمَامَكَ، اِضْغَطْ مَرَّتَيْنِ لِلتَّسْجِيلِ", isGuidance: false);
            }
          } else {
            if (_lastSpokenText != matchName) {
              _lastSpokenText = matchName;
              _result = matchName;
              VoiceService.speak(text: "$matchName أَمَامَكَ الْآنَ", isGuidance: false);
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      print("❌ [FaceProvider] خطأ أثناء معالجة الإطار: $e");
    } finally {
      _isProcessing = false;
    }
  }

  /// تسجيل وجه جديد محلياً
  Future<bool> registerNewFace(String name) async {
    if (_lastCameraImage == null || _lastDetectedFace == null || _cameraDescription == null) {
      VoiceService.speak(text: "عُذْرًا، لَمْ يَتِمَّ اِكْتِشَافُ وَجْهٍ بِوُضُوحٍ لِلتَّسْجِيلِ، حَاوِلْ مُجَدَّدًا", isGuidance: true);
      return false;
    }

    try {
      final croppedFace = _cropFace(_lastCameraImage!, _lastDetectedFace!, _cameraDescription!);
      final success = await _faceRecognitionService.registerFace(name, croppedFace);
      if (success) {
        _lastSpokenText = name;
        _result = name;
        VoiceService.speak(text: "تَمَّ تَسْجِيلُ $name بِنَجَاحٍ فِي الْهَاتِفِ", isGuidance: false);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print("❌ [FaceProvider] خطأ في تسجيل الوجه: $e");
    }
    return false;
  }

  /// قائمة بأسماء الأشخاص المسجلين
  List<String> getRegisteredNames() {
    return _faceRecognitionService.getRegisteredNames();
  }

  /// حذف شخص مسجل
  Future<void> deletePerson(String name) async {
    await _faceRecognitionService.deleteFace(name);
    VoiceService.speak(text: "تَمَّ حَذْفُ $name مِنَ الْقَائِمَةِ", isGuidance: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _faceDetectorService.close();
    super.dispose();
  }
}
