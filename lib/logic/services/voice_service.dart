import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

class VoiceService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final FlutterTts _tts = FlutterTts();
  static bool _isSpeaking = false;
  static String _currentlySpeakingText = "";

  // القيم الافتراضية للتحكم في حالة النطق من شاشة الإعدادات
  static bool isTtsEnabled = true;
  static double defaultRate = 0.5;
  static String defaultGender = "female"; // "female" أو "male"
  static bool isVibrationEnabled = true;

  static Future<void> speak({
    required String text,
    bool isTts = true,        
    double? rate,       
    String? voiceGender, 
    String? mp3FileName,        
    bool isGuidance = false,
    bool isError = false,
    bool awaitCompletion = false,
  }) async {
    // 1. إذا كان النطق الصوتي معطلاً في الإعدادات، نتوقف فوراً
    if (!isTtsEnabled) return;
    
    // إذا كان النص فارغاً، نتجاهل الطلب
    if (text.trim().isEmpty) return;

    // إذا كان نفس النص ينطق حالياً، نمنع التكرار المزعج
    if (_isSpeaking && _currentlySpeakingText == text) return;

    // إذا كان هناك نص آخر ينطق حالياً، نوقفه فوراً لقراءة التعريف الجديد مباشرة
    if (_isSpeaking) {
      await stop();
    }

    _isSpeaking = true;
    _currentlySpeakingText = text;

    // 2. الاهتزاز (إذا كان تفعيل الاهتزاز معطلاً في الإعدادات، نتجاهله)
    if (isVibrationEnabled) {
      _triggerVibration(isGuidance, isError);
    }

    // 3. النطق الصوتي
    if (isTts) {
      String spokenText = text;
      if (text.toLowerCase() == "hello, smart eye is working") {
        spokenText = "مرحباً بك، تطبيق العين الذكيه يعمل بنجاح";
      }

      // الكشف التلقائي عن اللغة (عربي أو إنجليزي) بناءً على الحروف العربية
      bool isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(spokenText);
      await _tts.setLanguage(isArabic ? "ar" : "en-US");
      
      // استخدام سرعة الكلام الافتراضية المخزنة في الإعدادات
      double speechRate = rate ?? defaultRate;
      await _tts.setSpeechRate(speechRate);

      // ضبط جنس الصوت (رجل أم امرأة)
      String targetGender = voiceGender ?? defaultGender;
      bool matchedGenderVoice = false;

      // 1. محاولة ضبط الصوت الفعلي من محرك نظام التشغيل إذا كان متاحاً
      try {
        List<dynamic> voices = await _tts.getVoices;
        print("🔊🔊🔊 [VoiceService] إجمالي الأصوات المتاحة بالهاتف: ${voices.length}");
        
        String targetLocale = isArabic ? "ar" : "en";
        var localeVoices = voices.where((v) {
          final String loc = (v["locale"] ?? v["lang"] ?? "").toString().toLowerCase();
          return loc.startsWith(targetLocale);
        }).toList();

        for (var voice in localeVoices) {
          print("🇸🇦 [VoiceService] صوت متاح للغة المطلوبة: name=${voice["name"]}, locale=${voice["locale"]}");
        }

        if (localeVoices.isNotEmpty) {
          dynamic selectedVoice;
          for (var v in localeVoices) {
            final String name = v["name"].toString().toLowerCase();
            final String gender = (v["gender"] ?? "").toString().toLowerCase();
            bool isMatch = false;
            
            if (gender.isNotEmpty) {
              isMatch = (gender == targetGender);
            } else {
              isMatch = (targetGender == "male")
                  ? _isVoiceMale(name, targetLocale)
                  : _isVoiceFemale(name, targetLocale);
            }
            
            if (isMatch) {
              selectedVoice = v;
              break;
            }
          }

          if (selectedVoice != null) {
            print("🎯 [VoiceService] تم اختيار صوت مطابق للجنس: name=${selectedVoice["name"]}, locale=${selectedVoice["locale"]}");
            await _tts.setVoice({"name": selectedVoice["name"], "locale": selectedVoice["locale"]});
            matchedGenderVoice = true;
          } else {
            // اختيار صوت افتراضي من القائمة إذا لم نجد صوتاً مطابقاً تماماً للجنس
            var defaultVoice = localeVoices.first;
            print("⚠️ [VoiceService] لم نجد صوتاً مطابقاً للجنس، تم اختيار الصوت الافتراضي: name=${defaultVoice["name"]}");
            await _tts.setVoice({"name": defaultVoice["name"], "locale": defaultVoice["locale"]});
          }
        }
      } catch (e) {
        print("⚠️ [VoiceService] لم نتمكن من اختيار صوت مخصص للنوع. الخطأ: $e");
      }

      // 2. ضبط حدة الصوت (Pitch):
      // إذا نجحنا في تحديد صوت حقيقي للجنس المطلوب، نستخدم حدة الصوت الطبيعية (1.0)
      // أما إذا فشلنا في العثور على صوت مطابق للجنس، فنستخدم تغيير حدة الصوت كحل بديل (0.75 للرجل لتخشين الصوت، 1.25 للمرأة)
      double pitch = 1.0;
      if (!matchedGenderVoice) {
        pitch = (targetGender == "male") ? 0.75 : 1.25;
      }
      await _tts.setPitch(pitch);
      
      final completer = Completer<void>();
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _currentlySpeakingText = "";
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _currentlySpeakingText = "";
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await _tts.speak(spokenText);
      if (awaitCompletion) {
        await completer.future.timeout(const Duration(seconds: 15), onTimeout: () => null);
      }
    } else if (mp3FileName != null) {
      await _audioPlayer.play(AssetSource(mp3FileName));
    }
  }

  static bool _isVoiceMale(String name, String locale) {
    name = name.toLowerCase();
    locale = locale.toLowerCase();
    if (name.contains("male") && !name.contains("female")) return true;
    if (name.contains("female")) return false;
    
    if (locale.startsWith("ar")) {
      // أصوات الرجال في جوجل تيتيس للغة العربية: are, ard
      return name.contains("are") || name.contains("ard");
    }
    if (locale.startsWith("en")) {
      // أصوات الرجال في جوجل تيتيس للغة الإنجليزية: iol, iom
      return name.contains("iol") || name.contains("iom");
    }
    return false;
  }

  static bool _isVoiceFemale(String name, String locale) {
    name = name.toLowerCase();
    locale = locale.toLowerCase();
    if (name.contains("female")) return true;
    if (name.contains("male")) return false;
    
    if (locale.startsWith("ar")) {
      // أصوات النساء في جوجل تيتيس للغة العربية: arb, arc, arz
      return name.contains("arb") || name.contains("arc") || name.contains("arz") || name.contains("language");
    }
    if (locale.startsWith("en")) {
      // أصوات النساء في جوجل تيتيس للغة الإنجليزية: sfg, iuf
      return name.contains("sfg") || name.contains("iuf");
    }
    return true; // Heuristic fallback
  }

  static void _triggerVibration(bool isGuidance, bool isError) async {
    if (await Vibration.hasVibrator() ?? false) {
      if (isError) {
        Vibration.vibrate(duration: 500); 
      } else if (isGuidance) {
        Vibration.vibrate(pattern: [0, 100, 100, 100]); 
      } else {
        Vibration.vibrate(duration: 200); 
      }
    }
  }

  static Future<void> stop() async {
    _isSpeaking = false;
    _currentlySpeakingText = "";
    await _audioPlayer.stop();
    await _tts.stop();
  }

  static Future<void> playBeep() async {
    try {
      await _audioPlayer.play(AssetSource("audio/beep.wav"));
    } catch (e) {
      print("⚠️ [VoiceService] Error playing beep: $e");
    }
  }

  static const MethodChannel _settingsChannel = MethodChannel('com.example.smarteye_v2/settings');

  static Future<void> openVoiceInputSettings() async {
    try {
      await _settingsChannel.invokeMethod('openVoiceInputSettings');
    } on PlatformException catch (e) {
      print("⚠️ [VoiceService] Failed to open settings: ${e.message}");
    }
  }

  static Future<void> openDefaultAppsSettings() async {
    try {
      await _settingsChannel.invokeMethod('openDefaultAppsSettings');
    } on PlatformException catch (e) {
      print("⚠️ [VoiceService] Failed to open default apps settings: ${e.message}");
    }
  }

  static Future<void> openInputMethodSettings() async {
    try {
      await _settingsChannel.invokeMethod('openInputMethodSettings');
    } on PlatformException catch (e) {
      print("⚠️ [VoiceService] Failed to open input method settings: ${e.message}");
    }
  }
}