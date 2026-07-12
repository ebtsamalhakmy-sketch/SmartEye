import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:isolate';

class DetectionResult {
  final String label;
  final double confidence;
  DetectionResult(this.label, this.confidence);
}

class CurrencyService {
  List<String> _labels = [];
  final CurrencyIsolateRunner _isolateRunner = CurrencyIsolateRunner();
  bool _isModelLoaded = false;

  Future<void> loadModel() async {
    try {
      await _loadLabels();
      
      // تحميل ملف الموديل كـ bytes من الـ assets على الـ Main Isolate لتفادي قيود الـ Isolate
      final ByteData byteData = await rootBundle.load('assets/models/best16.tflite');
      final Uint8List modelBytes = byteData.buffer.asUint8List();
      
      await _isolateRunner.start(_labels, modelBytes);
      _isModelLoaded = true;
      print("✅ [CurrencyService] تم بدء تشغيل الـ Isolate وتحميل الموديل بنجاح.");
    } catch (e) {
      print("❌ [CurrencyService] خطأ في تحميل الموديل: $e");
    }
  }

  Future<void> _loadLabels() async {
    try {
      final String response = await rootBundle.loadString('assets/labels/labelsn.txt');
      _labels = response.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      print("❌ [CurrencyService] خطأ تحميل الليبلات: $e");
    }
  }

  Future<DetectionResult> runInferenceOnFloat32List(Float32List inputBuffer) async {
    if (!_isModelLoaded) return DetectionResult("...", 0.0);
    return await _isolateRunner.infer(inputBuffer);
  }

  // نحتفظ بهذه الدالة للتوافق العام فقط
  DetectionResult runInference(img.Image image) {
    return DetectionResult("Random", 0.0);
  }
}

/// منفذ مستقل للذكاء الاصطناعي يعمل في الخلفية (Background Isolate) لمنع تجميد الشاشة والكاميرا
class CurrencyIsolateRunner {
  late Isolate _isolate;
  late SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isInitialized = false;

  Future<void> start(List<String> labels, Uint8List modelBytes) async {
    if (_isInitialized) return;
    _isolate = await Isolate.spawn(_isolateEntry, _receivePort.sendPort);
    
    final dynamic response = await _receivePort.first;
    if (response is SendPort) {
      _sendPort = response;
      _isInitialized = true;
      _sendPort.send({
        'command': 'init',
        'labels': labels,
        'modelBytes': modelBytes,
      });
    }
  }

  Future<DetectionResult> infer(Float32List inputBuffer) async {
    if (!_isInitialized) return DetectionResult("...", 0.0);
    
    final responsePort = ReceivePort();
    _sendPort.send({
      'command': 'infer',
      'inputBuffer': inputBuffer,
      'replyPort': responsePort.sendPort,
    });
    
    final result = await responsePort.first;
    responsePort.close();
    
    if (result is Map) {
      return DetectionResult(result['label'] as String, result['confidence'] as double);
    }
    return DetectionResult("Random", 0.0);
  }

  static void _isolateEntry(SendPort sendPort) async {
    final commandPort = ReceivePort();
    sendPort.send(commandPort.sendPort);

    Interpreter? interpreter;
    List<String> labels = [];

    await for (final message in commandPort) {
      if (message is Map) {
        final command = message['command'] as String;
        if (command == 'init') {
          labels = List<String>.from(message['labels'] as List);
          final modelBytes = message['modelBytes'] as Uint8List;
          try {
            // تشغيل المعالج باستخدام 4 خيوط معالجة (Threads) لسرعة قصوى
            final options = InterpreterOptions()..threads = 4;
            // إنشاء المعالج من الـ bytes المحملة مباشرة في الذاكرة لتفادي قيود قنوات المنصة
            interpreter = Interpreter.fromBuffer(modelBytes, options: options);
          } catch (e) {
            print("❌ [Isolate] خطأ في تحميل الموديل داخل الـ Isolate: $e");
          }
        } else if (command == 'infer') {
          final replyPort = message['replyPort'] as SendPort;
          final inputBuffer = message['inputBuffer'] as Float32List;

          if (interpreter == null) {
            replyPort.send({'label': 'Error', 'confidence': 0.0});
            continue;
          }

          try {
            var outputShape = interpreter.getOutputTensor(0).shape;
            var output = List.filled(outputShape[0] * outputShape[1] * outputShape[2], 0.0)
                             .reshape(outputShape);
            
            var input = inputBuffer.reshape([1, 640, 640, 3]);
            interpreter.run(input, output);
            
            final result = _parseResultStatic(output, labels);
            replyPort.send({'label': result.label, 'confidence': result.confidence});
          } catch (e) {
            print("🚨 [Isolate] خطأ أثناء التوقع: $e");
            replyPort.send({'label': 'Error', 'confidence': 0.0});
          }
        }
      }
    }
  }

  static DetectionResult _parseResultStatic(dynamic output, List<String> labels) {
    final data = output[0];
    double maxConf = 0.0;
    int bestClassIndex = -1;

    for (int i = 0; i < data[0].length; i++) {
      // الحصول على أبعاد الصندوق للتأكد من أنه ليس مجرد ضوضاء صغيرة في الخلفية
      double w = data[2][i];
      double h = data[3][i];
      
      // تحويل الأبعاد إلى نسبة مئوية (دعم التنسيق المنسق والبيكسل العادي)
      double normW = w > 1.0 ? w / 640.0 : w;
      double normH = h > 1.0 ? h / 640.0 : h;
      
      // يجب أن تكون أبعاد العملة معقولة (على الأقل 12% من حجم الشاشة لتفادي التشويش الخلفي)
      if (normW < 0.12 || normH < 0.12) continue;

      for (int c = 4; c < data.length; c++) {
        if (data[c][i] > maxConf) {
          maxConf = data[c][i];
          bestClassIndex = c - 4;
        }
      }
    }

    // رفع نسبة حد الثقة (Confidence Threshold) إلى 0.65 لتجنب التشخيص الخاطئ
    if (maxConf > 0.65 && bestClassIndex >= 0 && bestClassIndex < labels.length) {
      return DetectionResult(labels[bestClassIndex], maxConf);
    }
    
    return DetectionResult("Random", 0.0);
  }
}