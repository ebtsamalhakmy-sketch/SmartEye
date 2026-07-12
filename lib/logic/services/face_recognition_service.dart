import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;
  Map<String, List<double>> _registeredFaces = {};
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  /// تحميل نموذج MobileFaceNet وقاعدة البيانات المحلية
  Future<void> loadModel() async {
    try {
      if (_isModelLoaded) return;
      final options = InterpreterOptions()..threads = 2; // استخدام خيطين للمعالجة السريعة
      
      // تحميل الملف من الـ assets
      final ByteData byteData = await rootBundle.load('assets/models/mobilefacenet.tflite');
      final Uint8List modelBytes = byteData.buffer.asUint8List();
      
      _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
      _isModelLoaded = true;
      print("✅ [FaceRecognitionService] تم تحميل نموذج MobileFaceNet بنجاح.");
      
      await loadRegisteredFaces();
    } catch (e) {
      print("❌ [FaceRecognitionService] خطأ في تحميل النموذج: $e");
    }
  }

  /// تحميل الأشخاص المسجلين من الذاكرة المحلية (الملف JSON)
  Future<void> loadRegisteredFaces() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/registered_faces.json');
      if (await file.exists()) {
        final String content = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        _registeredFaces = jsonMap.map((key, value) {
          return MapEntry(key, List<double>.from(value.map((x) => (x as num).toDouble())));
        });
        print("👥 [FaceRecognitionService] تم تحميل ${_registeredFaces.length} شخص من قاعدة البيانات المحلية.");
      }
    } catch (e) {
      print("❌ [FaceRecognitionService] خطأ في تحميل قاعدة بيانات الوجوه: $e");
    }
  }

  /// حفظ الأشخاص المسجلين في الذاكرة المحلية (الملف JSON)
  Future<void> _saveRegisteredFaces() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/registered_faces.json');
      final String jsonStr = jsonEncode(_registeredFaces);
      await file.writeAsString(jsonStr);
    } catch (e) {
      print("❌ [FaceRecognitionService] خطأ في حفظ قاعدة بيانات الوجوه: $e");
    }
  }

  /// تسجيل وجه شخص جديد وحفظه (يدعم تسجيل صور متعددة لنفس الشخص لزيادة الدقة)
  Future<bool> registerFace(String name, img.Image faceImage) async {
    final embedding = predict(faceImage);
    if (embedding != null) {
      // البحث عن أول رقم تعريفي متاح للتسجيل المتعدد (مثل Mohammed_1, Mohammed_2)
      int suffix = 1;
      while (_registeredFaces.containsKey("${name}_$suffix")) {
        suffix++;
      }
      _registeredFaces["${name}_$suffix"] = embedding;
      await _saveRegisteredFaces();
      print("✅ [FaceRecognitionService] تم تسجيل الوجه للاسم: ${name}_$suffix");
      return true;
    }
    return false;
  }

  /// الحصول على قائمة بكل الأشخاص المسجلين بدون تكرار
  List<String> getRegisteredNames() {
    final Set<String> baseNames = {};
    for (String key in _registeredFaces.keys) {
      if (key.contains('_')) {
        final parts = key.split('_');
        parts.removeLast();
        baseNames.add(parts.join('_'));
      } else {
        baseNames.add(key); // للتوافق مع البيانات القديمة
      }
    }
    return baseNames.toList();
  }

  /// حذف شخص مسجل من قاعدة البيانات (يحذف كل النسخ المسجلة له)
  Future<void> deleteFace(String name) async {
    final keysToRemove = <String>[];
    for (String key in _registeredFaces.keys) {
      String baseName = key;
      if (key.contains('_')) {
        final parts = key.split('_');
        parts.removeLast();
        baseName = parts.join('_');
      }
      if (baseName == name) {
        keysToRemove.add(key);
      }
    }
    for (String key in keysToRemove) {
      _registeredFaces.remove(key);
    }
    await _saveRegisteredFaces();
    print("🗑️ [FaceRecognitionService] تم حذف كل الوجوه للاسم: $name");
  }

  /// استخراج البصمة الرقمية للوجه (192D Embedding) من الصورة المقصوصة
  List<double>? predict(img.Image faceImage) {
    if (_interpreter == null) return null;

    try {
      // 1. تحجيم الوجه لأبعاد 112x112 (الحجم الافتراضي لـ MobileFaceNet)
      final img.Image resized = img.copyResize(
        faceImage,
        width: 112,
        height: 112,
        interpolation: img.Interpolation.cubic,
      );

      // 2. إعداد مصفوفة المدخلات وتطبيع البكسلات (Normalization)
      // المعادلة: (pixel - 127.5) / 128.0
      final Float32List input = Float32List(112 * 112 * 3);
      int index = 0;
      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          final pixel = resized.getPixel(x, y);
          
          input[index++] = (pixel.r.toDouble() - 127.5) / 128.0;
          input[index++] = (pixel.g.toDouble() - 127.5) / 128.0;
          input[index++] = (pixel.b.toDouble() - 127.5) / 128.0;
        }
      }

      final inputBuffer = input.reshape([1, 112, 112, 3]);

      // 3. تحديد حجم مخرجات النموذج (عدد البصمات - عادة 192 أو 128)
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final int embeddingSize = outputShape[1];
      var output = List.filled(embeddingSize, 0.0).reshape([1, embeddingSize]);

      // 4. تشغيل التوقع
      _interpreter!.run(inputBuffer, output);

      // 5. استخراج المتجه وتطبيقه وفق معيار L2 (L2 Normalization) لزيادة دقة مقارنة الزوايا
      final List<double> embedding = List<double>.from(output[0]);
      double sumSquares = 0.0;
      for (double val in embedding) {
        sumSquares += val * val;
      }
      double norm = sqrt(sumSquares);
      if (norm > 0) {
        for (int i = 0; i < embedding.length; i++) {
          embedding[i] /= norm;
        }
      }

      return embedding;
    } catch (e) {
      print("❌ [FaceRecognitionService] خطأ أثناء استخراج البصمة: $e");
      return null;
    }
  }

  /// التعرف على الوجه ومطابقته بقاعدة البيانات المحلية
  String recognizeFace(img.Image faceImage, {double threshold = 0.78}) {
    if (_registeredFaces.isEmpty) return "Unknown";
    
    final embedding = predict(faceImage);
    if (embedding == null) return "Unknown";

    String bestMatchKey = "Unknown";
    double minDistance = double.infinity;

    // مقارنة الوجه بكل المسجلين للعثور على أقرب بصمة مسافة إقليدية
    _registeredFaces.forEach((key, regEmbedding) {
      double distance = _euclideanDistance(embedding, regEmbedding);
      if (distance < minDistance) {
        minDistance = distance;
        bestMatchKey = key;
      }
    });

    // إذا كانت المسافة الإقليدية أصغر من الحد المسموح، نعتبر التطابق صحيحاً
    if (minDistance < threshold) {
      String baseName = bestMatchKey;
      if (bestMatchKey.contains('_')) {
        final parts = bestMatchKey.split('_');
        parts.removeLast();
        baseName = parts.join('_');
      }
      print("🎯 تم التطابق بنجاح: $baseName (المسافة: $minDistance, المفتاح: $bestMatchKey)");
      return baseName;
    }

    return "Unknown";
  }

  /// حساب المسافة الإقليدية بين متجهين
  double _euclideanDistance(List<double> v1, List<double> v2) {
    double sum = 0.0;
    for (int i = 0; i < v1.length; i++) {
      double diff = v1[i] - v2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}
