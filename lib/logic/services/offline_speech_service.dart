import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:record/record.dart';

/// خدمة التعرف على الصوت بدون إنترنت – تعمل باستخدام Vosk
/// النموذج مضمّن داخل الـ APK مباشرة ولا يحتاج أي اتصال بالإنترنت أبداً
class OfflineSpeechService {
  static final OfflineSpeechService _instance = OfflineSpeechService._internal();
  factory OfflineSpeechService() => _instance;
  OfflineSpeechService._internal();

  static const String _modelAssetPath = 'assets/models/vosk-model-small-ar-0.3.zip';
  static const String _modelDirName = 'vosk-model-small-ar-0.3';

  VoskFlutterPlugin? _vosk;
  Model? _model;
  Recognizer? _recognizer;
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSub;
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Future<String> _getModelDirPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    return "${docDir.path}/$_modelDirName";
  }

  /// يتحقق إن كان النموذج قد سبق استخراجه على الجهاز
  Future<bool> isModelExtracted() async {
    final dirPath = await _getModelDirPath();
    final hasModelFile = await File("$dirPath/am/final.mdl").exists();
    return hasModelFile;
  }

  /// يستخرج النموذج من الـ assets إلى التخزين الداخلي للتطبيق
  /// يُستدعى مرة واحدة فقط عند أول تشغيل
  Stream<double> extractModelFromAssets() async* {
    final dirPath = await _getModelDirPath();

    // تنظيف أي استخراج سابق غير مكتمل
    final modelDir = Directory(dirPath);
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }

    yield 0.05; // بدأنا

    // قراءة ملف الـ ZIP من assets
    final zipBytes = await rootBundle.load(_modelAssetPath);
    final bytes = zipBytes.buffer.asUint8List();

    yield 0.30; // تم تحميل الـ ZIP من الذاكرة

    // فك الضغط
    final archive = ZipDecoder().decodeBytes(bytes);
    final destDir = await getApplicationDocumentsDirectory();

    int total = archive.length;
    int done = 0;

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File("${destDir.path}/$filename");
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      } else {
        final outDir = Directory("${destDir.path}/$filename");
        await outDir.create(recursive: true);
      }
      done++;
      // من 30% إلى 95% أثناء الاستخراج
      yield 0.30 + (done / total) * 0.65;
    }

    yield 1.0; // اكتمل
  }

  /// تهيئة المعرِّف بعد استخراج النموذج
  Future<void> initRecognizer() async {
    if (_isInitialized) return;

    final dirPath = await _getModelDirPath();
    final extracted = await isModelExtracted();
    if (!extracted) {
      throw Exception("النموذج لم يُستخرج بعد.");
    }

    _vosk = VoskFlutterPlugin.instance();
    _model = await _vosk!.createModel(dirPath);
    _recognizer = await _vosk!.createRecognizer(model: _model!, sampleRate: 16000);
    _audioRecorder = AudioRecorder();
    _isInitialized = true;
  }

  /// إعادة إنشاء المعرِّف من الصفر لضمان buffer نظيف تمامًا
  /// يُستدعى قبل كل جلسة تسجيل بصمة جديدة
  Future<void> resetRecognizer() async {
    try {
      await stopListening();

      // نسجل الكلمة النهائية الموجودة في الـ buffer (لإفراغه)
      try { await _recognizer?.getResult(); } catch (_) {}
      try { await _recognizer?.getPartialResult(); } catch (_) {}

      // نتخلص من الـ recognizer القديم ونصنع واحدًا جديدًا نظيفًا
      _recognizer?.dispose();
      _recognizer = null;

      if (_model != null) {
        _recognizer = await _vosk!.createRecognizer(
          model: _model!,
          sampleRate: 16000,
        );
      }

      // تأخير إضافي لضمان جاهزية الـ recognizer الجديد
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {}
  }

  /// بدء الاستماع وتحليل الصوت
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    required Function(String error) onError,
  }) async {
    if (!_isInitialized) {
      onError("المعرِّف الصوتي غير جاهز.");
      return;
    }
    if (_isListening) return;

    try {
      if (!await _audioRecorder!.hasPermission()) {
        onError("لا توجد صلاحية الوصول للميكروفون.");
        return;
      }

      _isListening = true;

      final recordStream = await _audioRecorder!.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      _audioSub = recordStream.listen((data) async {
        if (!_isListening) return;
        try {
          final resultReady = await _recognizer!.acceptWaveformBytes(data);
          if (resultReady) {
            final resJson = await _recognizer!.getResult();
            final text = _parseVoskField(resJson, "text");
            if (text.isNotEmpty) onResult(text, true);
          } else {
            final partialJson = await _recognizer!.getPartialResult();
            final text = _parseVoskField(partialJson, "partial");
            if (text.isNotEmpty) onResult(text, false);
          }
        } catch (e) {
          // تجاهل أخطاء المعالجة المؤقتة
        }
      });
    } catch (e) {
      _isListening = false;
      onError("خطأ في تشغيل الميكروفون: $e");
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _audioRecorder?.stop();
    } catch (_) {}
  }

  String _parseVoskField(String jsonStr, String field) {
    try {
      final regex = RegExp('"$field"\\s*:\\s*"([^"]*)"');
      final match = regex.firstMatch(jsonStr);
      return match?.group(1) ?? "";
    } catch (_) {
      return "";
    }
  }

  Future<void> dispose() async {
    await stopListening();
    await _audioRecorder?.dispose();
    _model?.dispose();
    _recognizer?.dispose();
    _isInitialized = false;
  }
}
