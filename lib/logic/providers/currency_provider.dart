import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:isolate';
import '../services/currency_service.dart';
import '../services/voice_service.dart'; 
import '../utils/image_converter.dart';
import 'camera_provider.dart';

class CurrencyProvider with ChangeNotifier {
  final CurrencyService _currencyService = CurrencyService();
  
  String _result = "جاري التجهيز...";
  String _lastSpokenText = ""; 
  bool _isProcessing = false;
  bool isModelLoaded = false; 
  DateTime _lastProcessedTime = DateTime.now();

  String get result => _result;

  Future<void> loadModel() async {
    if (isModelLoaded) return;
    await _currencyService.loadModel();
    isModelLoaded = true;
    notifyListeners();
  }

  Future<void> onFrameAvailable(CameraImage cameraImage, CameraProvider cameraProvider) async {
    if (_isProcessing || !isModelLoaded) return;

    final currentTime = DateTime.now();
    if (currentTime.difference(_lastProcessedTime).inMilliseconds < 1000) return;

    _isProcessing = true;
    _lastProcessedTime = currentTime; 

    try {
      // تحضير البيانات بشكل مسطح لإرسالها للـ Isolate
      final inputData = ConversionInput(
        cameraImage.planes.map((p) => p.bytes).toList(),
        cameraImage.width,
        cameraImage.height,
        cameraImage.planes.map((p) => p.bytesPerRow).toList(),
        cameraImage.planes.map((p) => p.bytesPerPixel ?? 1).toList(),
      );

      // تشغيل عملية التحويل في الخلفية (Isolate) تماماً لعدم تجميد الكاميرا
      final inputBuffer = await Isolate.run(() => ImageConverter.convertYUV420ToFloat32List(inputData, 640, 640));
      
      final detection = await _currencyService.runInferenceOnFloat32List(inputBuffer);

      // منطق "التطبيق الذكي"
      if (detection.label == "none" || detection.label == "Random" || detection.label == "Error") {
        // حالة: الموديل لا يرى عملة
        if (_lastSpokenText != "ابحث") {
          _lastSpokenText = "ابحث";
          _result = "الرجاء تقريب العملة";
          VoiceService.speak(text: "الرَّجَاءُ تَقْرِيبُ الْعُمُلَةِ مِنَ الْكَامِيرَا", isGuidance: true);
        }
      } else {
        // حالة: تم العثور على عملة
        if (detection.label != _lastSpokenText) {
          _lastSpokenText = detection.label;
          final String arabicLabel = _translateLabel(detection.label);
          _result = arabicLabel;
          VoiceService.speak(text: "تَمَّ الْعُثُورُ عَلَى $arabicLabel", isGuidance: false);
          cameraProvider.processResult(0.0, 0.9, detection.label);
        }
      }
      notifyListeners();
    } catch (e) {
      print("❌ خطأ: $e");
    } finally {
      _isProcessing = false;
    }
  }

  String _translateLabel(String label) {
    switch (label) {
      case '1000_YR': return 'أَلْفُ رِيَالٍ يَمَنِيٍّ';
      case '500_YR': return 'خَمْسُمِائَةِ رِيَالٍ يَمَنِيٍّ';
      case '250_YR': return 'مِائَتَانِ وَخَمْسُونَ رِيَالًا يَمَنِيًّا';
      case '200_YR': return 'مِائَتَا رِيَالٍ يَمَنِيٍّ';
      case '100_YR': return 'مِائَةُ رِيَالٍ يَمَنِيٍّ';
      case '50_YR': return 'خَمْسُونَ رِيَالًا يَمَنِيًّا';
      case '20_YR': return 'عِشْرُونَ رِيَالًا يَمَنِيًّا';
      case '10_YR': return 'عَشَرَةُ رِيَالَاتٍ يَمَنِيَّةٍ';
      case '5_YR': return 'خَمْسَةُ رِيَالَاتٍ يَمَنِيَّةٍ';
      case '1_YR': return 'رِيَالٌ يَمَنِيٌّ وَاحِدٌ';
      default: return label;
    }
  }
}