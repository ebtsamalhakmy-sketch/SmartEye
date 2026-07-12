import 'package:flutter/material.dart';
import 'currency_detection_screen.dart';
import 'face_detection_screen.dart';

import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("قائمة الخدمات")),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2, // شبكة من عمودين لسهولة الحفظ
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _serviceCard(context, "العملات", Icons.money, const Color.fromARGB(255, 145, 154, 145), const CurrencyDetectionScreen()),

          _serviceCard(context, "الأشخاص", Icons.person, Colors.blue, const FaceDetectionScreen()),
          _serviceCard(context, "الإعدادات", Icons.settings, Colors.blueGrey, const SettingsScreen()),
        ],
      ),
    );
  }

  Widget _serviceCard(BuildContext context, String title, IconData icon, Color color, Widget? nextScreen) {
    return Semantics(
      button: true,
      label: "خدمة $title",
      child: Card(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: () {
            if (nextScreen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => nextScreen),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("خدمة $title غير متوفرة بعد")),
              );
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}