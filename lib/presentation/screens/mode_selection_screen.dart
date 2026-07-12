import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_menu_screen.dart';
import 'independent_mode_screen.dart';
import '../../logic/services/voice_service.dart';
import '../../logic/services/offline_speech_service.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
      _prepareOfflineModelInBackground();
    });
  }

  void _prepareOfflineModelInBackground() async {
    try {
      final offlineSpeech = OfflineSpeechService();
      bool isExtracted = await offlineSpeech.isModelExtracted();
      if (!isExtracted) {
        offlineSpeech.extractModelFromAssets().listen(
          (_) {},
          onDone: () => print("✅ [Background] Offline model extracted successfully."),
          onError: (e) => print("❌ [Background] Error extracting model: $e"),
        );
      }
    } catch (e) {
      print("❌ [Background] Exception checking/extracting model: $e");
    }
  }

  Future<void> _checkFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isFirst = prefs.getBool("is_first_launch") ?? true;
      if (isFirst) {
        await VoiceService.speak(
          text: "مَرْحَبًا بِكَ فِي تَطْبِيقِ الْعَيْنِ الذَّكِيَّةِ الْمُسَاعِدِ الْبَصَرِيِّ. هَذَا هُوَ تَشْغِيلُكَ الْأَوَّلُ لِلتَّطْبِيقِ، سَأَقُومُ بِشَرْحِ مُمَيِّزَاتِ التَّطْبِيقِ لِمُسَاعَدَتِكَ. "
                "أَوَّلًا: وَضْعُ النِّظَامِ، وَهُوَ مُتَوَافِقٌ تَمَامًا مَعَ قَارِئِ الشَّاشَةِ (TalkBack) لِقِرَاءَةِ الشَّاشَةِ بِشَكْلٍ تَقْلِيدِيٍّ. "
                "ثَانِيًا: الْوَضْعُ الْمُسْتَقِلُّ، وَهُوَ وَضْعٌ مُخَصَّصٌ بِالْكَامِلِ لِلتَّحُكُّمِ بِالصَّوْتِ. يُمْكِنُكَ تَسْجِيلُ كَلِمَةٍ مِفْتَاحِيَّةٍ لِكُلِّ خِدْمَةٍ، وَفَتْحُهَا بِنُطْقِ الْكَلَمَةِ عِنْدَ الضَّغْطِ الْمُسْتَمِرِّ عَلَى زِرِّ الْمَايِكِ فِي أَسْفَلِ الشَّاشَةِ. "
                "ثَالِثًا: الْخِدْمَاتُ الْمُتَاحَةُ بِالتَّطْبِيقِ: "

                "خِدْمَةُ الْعُمُلَاتِ، لِلتَّعَرُّفِ عَلَى فِئَاتِ الْعُمُلَاتِ النَّقْدِيَّةِ. "
                "خِدْمَةُ الْأَشْخَاصِ، لِلتَّعَرُّفِ عَلَى الْوُجُوهِ. "
                "وَشَاشَةُ الْإِعْدَادَاتِ، لِضَبْطِ سُرْعَةِ النُّطْقِ وَاخْتِيَارِ صَوْتِ رَجُلٍ أَوْ اِمْرَأَةٍ. "
                "يُرْجَى تَحْدِيدُ وَضْعِ التَّشْغِيلِ الْمُنَاسِبِ لَكَ لِلْبَدْءِ.",
          isGuidance: true,
        );
        await prefs.setBool("is_first_launch", false);
      } else {
        // نطق ترحيب عادي للمستخدمين العائدين
        await VoiceService.speak(
          text: "مَرْحَبًا بِكَ مُجَدَّدًا فِي تَطْبِيقِ الْعَيْنِ الذَّكِيَّةِ. يُرْجَى اِخْتِيَارُ وَضْعِ التَّشْغِيلِ: وَضْعُ النِّظَامِ أَوِ الْوَضْعُ الْمُسْتَقِلُّ.",
          isGuidance: true,
        );
      }
    } catch (e) {
      print("⚠️ [FirstLaunchCheck Error] $e");
      // في حال حدوث خطأ، ننطق ترحيباً افتراضياً
      await VoiceService.speak(
        text: "مَرْحَبًا بِكَ فِي تَطْبِيقِ الْعَيْنِ الذَّكِيَّةِ. يُرْجَى اِخْتِيَارُ وَضْعِ التَّشْغِيلِ لِلْبَدْءِ.",
        isGuidance: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختيار وضع التشغيل")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildModeButton(
            context,
            "وضع النظام",
            "متوافق مع قارئات الشاشة (TalkBack)",
            Icons.accessibility_new,
            Colors.blueAccent,
            const MainMenuScreen(),
          ),
          const SizedBox(height: 20),
          _buildModeButton(
            context,
            "الوضع المستقل",
            "تحكم كامل بالأوامر الصوتية",
            Icons.mic,
            Colors.purple,
            const IndependentModeScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(BuildContext context, String title, String desc, IconData icon, Color color, Widget destinationScreen) {
    return Semantics(
      button: true,
      label: "$title, $desc. اضغط مرتين للبدء",
      child: GestureDetector(
        onTap: () {
          // إيقاف أي صوت إرشادي ترحيبي عند الدخول لوضع جديد
          VoiceService.stop();
          Navigator.push(context, MaterialPageRoute(builder: (_) => destinationScreen));
        },
        child: Container(
          height: 180,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.white),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(desc, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}