import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../logic/services/voice_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _speechRate = VoiceService.defaultRate;
  bool _isTtsEnabled = VoiceService.isTtsEnabled;
  bool _isVibrationEnabled = VoiceService.isVibrationEnabled;
  String _voiceGender = VoiceService.defaultGender;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VoiceService.speak(
        text: "شَاشَةُ الْإِعْدَادَاتِ. هُنَا يُمْكِنُكَ تَعْدِيلُ سُرْعَةِ نُطْقِ الصَّوْتِ، وَنَوْعِ الصَّوْتِ ذَكَرٌ أَمْ أُنْثَى، وَالتَّحُكُّمِ بِالِاهْتِزَازِ.",
        isGuidance: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الإعدادات"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. التحكم بنطق الصوت (TTS)
          Semantics(
            label: "تفعيل النطق الصوتي",
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: SwitchListTile(
                title: const Text(
                  "النطق الصوتي",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("تمكين أو تعطيل التوجيه الصوتي التلقائي"),
                secondary: const Icon(Icons.volume_up, color: Colors.blue),
                value: _isTtsEnabled,
                onChanged: (val) {
                  setState(() {
                    _isTtsEnabled = val;
                    VoiceService.isTtsEnabled = val;
                  });
                  // إذا تم تعطيله فلن ينطق، وإذا تم تشغيله سينطق
                  if (val) {
                    VoiceService.speak(
                      text: "تَمَّ تَشْغِيلُ النُّطْقِ الصَّوْتِيِّ",
                      isGuidance: true,
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. اختيار جنس الصوت (رجل أم امرأة)
          if (_isTtsEnabled) ...[
            Semantics(
              label: "نوع الصوت. القيمة الحالية صوت ${_voiceGender == 'female' ? 'امرأة' : 'رجل'}",
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.record_voice_over, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            "نوع الصوت (Voice Gender)",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "اختر جنس الصوت المفضل للخدمات",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  "صوت امرأة",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: _voiceGender == "female",
                              selectedColor: Colors.green.withOpacity(0.2),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _voiceGender = "female";
                                    VoiceService.defaultGender = "female";
                                  });
                                  VoiceService.speak(
                                    text: "تَمَّ تَغْيِيرُ الصَّوْتِ إِلَى صَوْتِ اِمْرَأَةٍ",
                                    voiceGender: "female",
                                    isGuidance: true,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  "صوت رجل",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: _voiceGender == "male",
                              selectedColor: Colors.green.withOpacity(0.2),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _voiceGender = "male";
                                    VoiceService.defaultGender = "male";
                                  });
                                  VoiceService.speak(
                                    text: "تَمَّ تَغْيِيرُ الصَّوْتِ إِلَى صَوْتِ رَجُلٍ",
                                    voiceGender: "male",
                                    isGuidance: true,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. سرعة الكلام (Speech Rate)
            Semantics(
              label: "سرعة نطق الصوت. القيمة الحالية ${( _speechRate * 100).toInt()}%",
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.speed, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            "سرعة الكلام (Speech Rate)",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "اسحب لتسريع أو إبطاء نطق الصوت التلقائي",
                        style: TextStyle(color: Colors.grey),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.directions_walk, size: 20, color: Colors.grey),
                          Expanded(
                            child: Slider(
                              value: _speechRate,
                              min: 0.2,
                              max: 1.0,
                              divisions: 8,
                              label: "${(_speechRate * 100).toInt()}%",
                              onChanged: (val) {
                                setState(() {
                                  _speechRate = val;
                                  VoiceService.defaultRate = val;
                                });
                              },
                              onChangeEnd: (val) {
                                VoiceService.speak(
                                  text: "تَمَّ ضَبْطُ سُرْعَةِ الْكَلَامِ",
                                  rate: val,
                                  isGuidance: true,
                                );
                              },
                            ),
                          ),
                          const Icon(Icons.directions_run, size: 20, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4. الاهتزاز (Vibration)
          Semantics(
            label: "تفعيل ميزة الاهتزاز التفاعلي",
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: SwitchListTile(
                title: const Text(
                  "الاهتزاز التفاعلي",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("اهتزاز الهاتف عند التعرف على الأشياء أو حدوث أخطاء"),
                secondary: const Icon(Icons.vibration, color: Colors.purple),
                value: _isVibrationEnabled,
                onChanged: (val) async {
                  setState(() {
                    _isVibrationEnabled = val;
                    VoiceService.isVibrationEnabled = val;
                  });
                  if (val && await Vibration.hasVibrator() == true) {
                    Vibration.vibrate(duration: 200);
                  }
                  VoiceService.speak(
                    text: val ? "تَمَّ تَفْعِيلُ الِاهْتِزَازِ" : "تَمَّ إِلْغَاءُ تَفْعِيلِ الِاهْتِزَازِ",
                    isGuidance: true,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. سماع شرح التطبيق مجدداً
          Semantics(
            label: "سَمَاعُ شَرْحِ مُمَيِّزَاتِ التَّطْبِيقِ، اِضْغَطْ مَرَّتَيْنِ لِلتَّشْغِيلِ",
            button: true,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.teal, size: 28),
                title: const Text(
                  "سماع شرح التطبيق",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("إعادة الاستماع إلى دليل استخدام التطبيق الصوتي"),
                onTap: () {
                  VoiceService.speak(
                    text: "مَرْحَبًا بِكَ فِي تَطْبِيقِ الْعَيْنِ الذَّكِيَّةِ الْمُسَاعِدِ الْبَصَرِيِّ. "
                          "سَأَقُومُ بِشَرْحِ مُمَيِّزَاتِ التَّطْبِيقِ لِمُسَاعَدَتِكَ. "
                          "أَوَّلًا: وَضْعُ النِّظَامِ، وَهُوَ مُتَوَافِقٌ تَمَامًا مَعَ قَارِئِ الشَّاشَةِ (TalkBack) لِقِرَاءَةِ الشَّاشَةِ بِشَكْلٍ تَقْلِيدِيٍّ. "
                          "ثَانِيًا: الْوَضْعُ الْمُسْتَقِلُّ، وَهُوَ وَضْعٌ مُخَصَّصٌ بِالْكَامِلِ لِلتَّحُكُّمِ بِالصَّوْتِ. يُمْكِنُكَ تَسْجِيلُ كَلِمَةٍ مِفْتَاحِيَّةٍ لِكُلِّ خِدْمَةٍ، وَفَتْحُهَا بِنُطْقِ الْكَلَمَةِ عِنْدَ الضَّغْطِ الْمُسْتَمِرِّ عَلَى زِرِّ الْمَايِكِ فِي أَسْفَلِ الشَّاشَةِ. "
                          "ثَالِثًا: الْخِدْمَاتُ الْمُتَاحَةُ بِالتَّطْبِيقِ: "

                          "خِدْمَةُ الْعُمُلَاتِ، لِلتَّعَرُّفِ عَلَى فِئَاتِ الْعُمُلَاتِ النَّقْدِيَّةِ. "
                          "خِدْمَةُ الْأَشْخَاصِ، لِلتَّعَرُّفِ عَلَى الْوُجُوهِ. "
                          "وَشَاشَةُ الْإِعْدَادَاتِ، لِضَبْطِ سُرْعَةِ النُّطْقِ وَاخْتِيَارِ صَوْتِ رَجُلٍ أَوْ اِمْرَأَةٍ.",
                    isGuidance: true,
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
