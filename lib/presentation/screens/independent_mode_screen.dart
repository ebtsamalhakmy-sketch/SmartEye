import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'currency_detection_screen.dart';
import 'face_detection_screen.dart';

import 'settings_screen.dart';
import '../../logic/services/voice_service.dart';
import '../../logic/services/offline_speech_service.dart';

// ─────────────────────────────────────────────────────────────
// الشاشة الرئيسية للوضع المستقل – تعرف على الصوت بدون إنترنت
// ─────────────────────────────────────────────────────────────
class IndependentModeScreen extends StatefulWidget {
  const IndependentModeScreen({super.key});

  @override
  State<IndependentModeScreen> createState() => _IndependentModeScreenState();
}

class _IndependentModeScreenState extends State<IndependentModeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final OfflineSpeechService _offlineSpeech = OfflineSpeechService();

  bool _isListening = false;
  String _statusText = "اضغط على زر التحدث بالأسفل ونادِ باسم الخدمة";
  String _lastSpokenText = "";

  // حالة النموذج
  bool _modelReady = false;
  bool _modelChecking = true;
  bool _modelDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = "";

  final List<Map<String, dynamic>> _widgets = [
    {
      "id": "currency",
      "title": "العملات",
      "speech_title": "الْعُمُلَاتِ",
      "description": "التعرف على فئات العملات الورقية",
      "icon": Icons.money,
      "color": const Color.fromARGB(255, 145, 154, 145),
      "screen": const CurrencyDetectionScreen(),
      "keyword": "",
    },
    {
      "id": "face",
      "title": "الأشخاص",
      "speech_title": "الْأَشْخَاصِ",
      "description": "التعرف على الأشخاص والوجوه",
      "icon": Icons.person,
      "color": Colors.blue,
      "screen": const FaceDetectionScreen(),
      "keyword": "",
    },
    {
      "id": "settings",
      "title": "الإعدادات",
      "speech_title": "الْإِعْدَادَاتِ",
      "description": "تعديل خيارات الصوت والاهتزاز",
      "icon": Icons.settings,
      "color": Colors.blueGrey,
      "screen": const SettingsScreen(),
      "keyword": "",
    },
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVoiceprints();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitModel();
      VoiceService.speak(
        text:
            "الْوَضْعُ الْمُسْتَقِلُّ مُفَعَّلٌ. سَيَعْمَلُ التَّعَرُّفُ عَلَى الصَّوْتِ بِكَفَاءَةٍ.",
        isGuidance: true,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _offlineSpeech.stopListening();
    super.dispose();
  }

  // لما يرجع المستخدم من أي شاشة فرعية – يوقف الصوت ويعيد الـ recognizer
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      VoiceService.stop();
      if (_modelReady) {
        _offlineSpeech.stopListening();
        setState(() {
          _isListening = false;
          _statusText = "اضغط على زر التحدث بالأسفل ونادِ باسم الخدمة";
        });
      }
    }
  }

  // ── فحص النموذج وتهيئته ──────────────────────────────────
  Future<void> _checkAndInitModel() async {
    setState(() {
      _modelChecking = true;
      _modelReady = false;
    });

    final extracted = await _offlineSpeech.isModelExtracted();
    if (extracted) {
      await _initRecognizer();
    } else {
      setState(() {
        _modelChecking = false;
        _modelReady = false;
      });
    }
  }

  Future<void> _initRecognizer() async {
    setState(() {
      _modelChecking = true;
      _downloadStatus = "جاري تحميل النموذج في الذاكرة...";
    });
    try {
      await _offlineSpeech.initRecognizer();
      setState(() {
        _modelReady = true;
        _modelChecking = false;
        _statusText = "اضغط على زر التحدث بالأسفل ونادِ باسم الخدمة";
      });
    } catch (e) {
      setState(() {
        _modelChecking = false;
        _modelReady = false;
        _downloadStatus = "خطأ في تهيئة النموذج: $e";
      });
    }
  }

  // ── تحميل النموذج من الإنترنت (مرة واحدة فقط) ────────────
  void _startModelDownload() {
    setState(() {
      _modelDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = "جاري تجهيز النموذج الصوتي العربي...";
    });

    _offlineSpeech.extractModelFromAssets().listen(
      (progress) {
        setState(() {
          _downloadProgress = progress < 0 ? -1.0 : progress;
          if (progress < 0) {
            _downloadStatus = "جاري التحميل...";
          } else if (progress >= 0.99 && progress < 1.0) {
            _downloadStatus = "جاري فك الضغط...";
          } else {
            _downloadStatus =
                "تحميل: ${(progress * 100).toStringAsFixed(0)}%";
          }
        });
      },
      onDone: () async {
        setState(() {
          _modelDownloading = false;
          _downloadStatus = "اكتمل! جاري التهيئة...";
        });
        await _initRecognizer();
      },
      onError: (e) {
        setState(() {
          _modelDownloading = false;
          _downloadStatus = "فشل التجهيز: $e";
        });
      },
    );
  }

  // ── تحميل الكلمات المفتاحية المحفوظة ──────────────────────
  Future<void> _loadVoiceprints() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var widget in _widgets) {
        widget["keyword"] = prefs.getString("voiceprint_${widget["id"]}") ?? "";
      }
    });
  }

  Future<void> _saveVoiceprint(String id, String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("voiceprint_$id", keyword);
    await _loadVoiceprints();
  }

  // ── تسجيل بصمة صوتية جديدة ────────────────────────────────
  void _calibrateVoiceprint(Map<String, dynamic> widget) async {
    if (!_modelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يرجى الانتظار حتى يكتمل تحميل النموذج الصوتي"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await VoiceService.stop();

    // مسح buffer المعرِّف السابق تمامًا قبل جلسة تسجيل جديدة
    await _offlineSpeech.resetRecognizer();

    await VoiceService.speak(
      text:
          "تَسْجِيلُ بَصْمَةِ الصَّوْتِ لِخِدْمَةِ ${widget["speech_title"] ?? widget["title"]}. قُلِ الْكَلِمَةَ الْمِفْتَاحِيَّةَ بَعْدَ التَّنْبِيهِ.",
      isGuidance: true,
      awaitCompletion: true,
    );
    await VoiceService.playBeep();
    final canVibrate = await Vibration.hasVibrator();
    if (canVibrate == true) {
      Vibration.vibrate(duration: 100);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext sheetContext) {
        return _OfflineVoiceprintSheet(
          widgetData: widget,
          offlineSpeech: _offlineSpeech,
          onSave: _saveVoiceprint,
        );
      },
    );
  }

  // ── بدء الاستماع للأمر الصوتي ─────────────────────────────
  void _startListening() async {
    if (_isListening || !_modelReady) return;

    await VoiceService.stop();

    // reset الـ recognizer قبل كل ضغطة على المايك لضمان نتائج نظيفة
    await _offlineSpeech.resetRecognizer();

    final canVibrate = await Vibration.hasVibrator();
    if (canVibrate == true) {
      Vibration.vibrate(duration: 100);
    }

    setState(() {
      _isListening = true;
      _statusText = "تحدث الآن...";
      _lastSpokenText = "";
    });

    await _offlineSpeech.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _statusText = "جاري تسجيل: $text";
          _lastSpokenText = text;
        });
        if (isFinal && text.isNotEmpty) {
          _processCommand(text);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _statusText = "خطأ: $error";
        });
      },
    );
  }

  // ── إيقاف الاستماع ومعالجة الأمر ──────────────────────────
  void _stopListeningAndProcess() async {
    if (!_isListening) return;

    setState(() {
      _isListening = false;
      _statusText = "جاري تحليل الأمر الصوتي...";
    });

    await _offlineSpeech.stopListening();
    await Future.delayed(const Duration(milliseconds: 400));

    if (_lastSpokenText.isNotEmpty) {
      _processCommand(_lastSpokenText);
    } else {
      setState(() {
        _statusText = "اضغط على زر التحدث بالأسفل ونادِ باسم الخدمة";
      });
      await VoiceService.speak(
        text: "عُذْرًا، لَمْ أَسْمَعْ أَيَّ أَمْرٍ صَوْتِيٍّ. يُرْجَى الْمُحَاوَلَةُ مُجَدَّدًا.",
        isError: true,
      );
    }
  }

  void _processCommand(String spoken) async {
    final lower = spoken.toLowerCase();
    bool matched = false;
    for (var widget in _widgets) {
      final String keyword = widget["keyword"].toString().toLowerCase().trim();
      if (keyword.isNotEmpty && lower.contains(keyword)) {
        matched = true;
        setState(() {
          _statusText = "جاري فتح خدمة ${widget["title"]}...";
        });
        await VoiceService.speak(
          text: "جَارِي فَتْحُ خِدْمَةِ ${widget["speech_title"] ?? widget["title"]}.",
          isGuidance: true,
        );
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => widget["screen"]),
        ).then((_) {
          VoiceService.stop();
          _offlineSpeech.stopListening();
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusText = "اضغط على زر التحدث بالأسفل ونادِ باسم الخدمة";
            });
          }
        });
        break;
      }
    }

    if (!matched) {
      setState(() {
        _statusText = "لم يتم التعرف على: $spoken";
      });
      await VoiceService.speak(
        text: "عُذْرًا، لَمْ أَتَعَرَّفْ عَلَى الْأَمْرِ. لَقَدْ سَمِعْتُ: $spoken.",
        isError: true,
      );
    }
  }

  void _onWidgetTap(Map<String, dynamic> widget) {
    final String keyword = widget["keyword"].toString();
    if (keyword.isEmpty) {
      _calibrateVoiceprint(widget);
    } else {
      // عند الرجوع من الخدمة: نوقف الصوت ونعيد تعيين حالة الزر
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => widget["screen"]),
      ).then((_) {
        VoiceService.stop();
        _offlineSpeech.stopListening();
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusText = "اضغط على زر التحدث بالأسفل ونادِ باسم الخدمة";
          });
        }
      });
    }
  }

  // ── بطاقة الخدمة ──────────────────────────────────────────
  Widget _serviceCard(BuildContext context, Map<String, dynamic> widget) {
    final bool isCalibrated = widget["keyword"].toString().isNotEmpty;
    return Semantics(
      button: true,
      label:
          "خدمة ${widget["title"]}. ${isCalibrated ? 'بصمة مسجلة: ${widget["keyword"]}' : 'بصمة غير مسجلة'}.",
      child: Card(
        color: widget["color"],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onWidgetTap(widget),
          onLongPress: () => _calibrateVoiceprint(widget),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget["icon"], size: 40, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      widget["title"],
                      style: const TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    if (isCalibrated) ...[
                      const SizedBox(height: 4),
                      Text(
                        "\"${widget["keyword"]}\"",
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCalibrated)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.mic, color: Colors.yellowAccent, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── واجهة تحميل النموذج ───────────────────────────────────
  Widget _buildModelDownloadWidget() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.settings_applications,
              size: 56, color: Colors.purpleAccent),
          const SizedBox(height: 16),
          const Text(
            "تجهيز النموذج الصوتي العربي",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "النموذج مُضمَّن داخل التطبيق تمامًا\nيحتاج استخراجًا لمرة واحدة فقط للبدء",
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_modelDownloading) ...[
            if (_downloadProgress >= 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _downloadProgress,
                  minHeight: 14,
                  backgroundColor: Colors.white10,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                ),
              )
            else
              const LinearProgressIndicator(
                minHeight: 14,
                backgroundColor: Colors.white10,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              ),
            const SizedBox(height: 10),
            Text(
              _downloadStatus,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            if (_downloadStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _downloadStatus,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                icon: const Icon(Icons.download),
                label: const Text(
                  "تجهيز النموذج",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _startModelDownload,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("الوضع المستقل"),
            if (!_modelReady) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "تحتاج إعداد",
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          // شبكة الخدمات
          Expanded(
            child: _modelChecking
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.purpleAccent),
                        SizedBox(height: 16),
                        Text("جاري تحضير النموذج الصوتي...",
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                : !_modelReady
                    ? SingleChildScrollView(child: _buildModelDownloadWidget())
                    : GridView.count(
                        padding: const EdgeInsets.all(16),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: _widgets
                            .map((widget) => _serviceCard(context, widget))
                            .toList(),
                      ),
          ),

          // زر التحدث – يظهر فقط بعد جهوز النموذج
          if (_modelReady)
            Semantics(
              button: true,
              label:
                  "زر التحدث بالأوامر الصوتية. اضغط واستمر للتحدث.",
              child: Listener(
                onPointerDown: (_) => _startListening(),
                onPointerUp: (_) => _stopListeningAndProcess(),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: double.infinity,
                      height: 160,
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [Colors.redAccent, Colors.red]
                              : [Colors.purple, const Color(0xFF6C63FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isListening ? Colors.red : Colors.purple)
                                    .withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius:
                                _isListening ? (_pulseAnimation.value * 4) : 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isListening ? Icons.hearing : Icons.mic,
                            size: 55,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom Sheet تسجيل البصمة الصوتية باستخدام Vosk (بدون إنترنت)
// ──────────────────────────────────────────────────────────────
class _OfflineVoiceprintSheet extends StatefulWidget {
  final Map<String, dynamic> widgetData;
  final OfflineSpeechService offlineSpeech;
  final Function(String id, String keyword) onSave;

  const _OfflineVoiceprintSheet({
    required this.widgetData,
    required this.offlineSpeech,
    required this.onSave,
  });

  @override
  State<_OfflineVoiceprintSheet> createState() =>
      _OfflineVoiceprintSheetState();
}

class _OfflineVoiceprintSheetState extends State<_OfflineVoiceprintSheet>
    with SingleTickerProviderStateMixin {
  String _recordingStatus = "جاري الاستماع... تحدث الآن";
  String _recognizedWord = "";
  bool _recordingDone = false;
  bool _isCapturing = false;
  Timer? _captureTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // تأخير 600ms لضمان أن الـ buffer السابق انتهى تمامًا قبل بدء التسجيل
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _startCapture();
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _pulseController.dispose();
    widget.offlineSpeech.stopListening();
    super.dispose();
  }

  void _startCapture() {
    setState(() {
      _isCapturing = true;
      _recordingStatus = "جاري الاستماع... تحدث الآن";
      _recognizedWord = "";
      _recordingDone = false;
    });

    widget.offlineSpeech.startListening(
      onResult: (text, isFinal) async {
        if (!mounted || _recordingDone) return;
        // نقبل فقط النتائج النهائية – النتائج الجزئية قد تكون بصمة ويدج سابقة
        if (!isFinal) return;
        final word = text.trim();
        if (word.isEmpty) return;

        setState(() {
          _recognizedWord = word;
          _recordingStatus = "تم التعرف على الكلمة!";
          _recordingDone = true;
          _isCapturing = false;
        });

        await widget.offlineSpeech.stopListening();
        await widget.onSave(widget.widgetData["id"], _recognizedWord);
        await VoiceService.speak(
          text:
              "تَمَّ تَسْجِيلُ بَصْمَةِ خِدْمَةِ ${widget.widgetData["speech_title"] ?? widget.widgetData["title"]} بِكَلِمَةِ: $_recognizedWord.",
          isGuidance: true,
        );
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) Navigator.pop(context);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _recordingStatus = "خطأ: $error";
        });
      },
    );

    // إيقاف تلقائي بعد 8 ثوانٍ
    _captureTimer = Timer(const Duration(seconds: 8), () {
      if (!_recordingDone && mounted) {
        widget.offlineSpeech.stopListening();
        setState(() {
          _isCapturing = false;
          _recordingStatus = "لم يتم الكشف عن كلمة. حاول مرة أخرى.";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              widget.widgetData["icon"],
              size: 55,
              color: widget.widgetData["color"],
            ),
            const SizedBox(height: 12),
            Text(
              "تسجيل بصمة لخدمة ${widget.widgetData["title"]}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _recordingDone ? 1.0 : _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _recordingDone
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _recordingDone ? Icons.check : Icons.mic,
                      size: 45,
                      color: _recordingDone ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              _recordingStatus,
              style: TextStyle(
                color: _recordingDone ? Colors.greenAccent : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_recognizedWord.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _recognizedWord,
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!_recordingDone && !_isCapturing)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text("أعد المحاولة"),
                onPressed: _startCapture,
              ),
            TextButton(
              onPressed: () {
                widget.offlineSpeech.stopListening();
                Navigator.pop(context);
              },
              child: const Text(
                "إلغاء",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
