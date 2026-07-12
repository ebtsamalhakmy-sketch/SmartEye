import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ModeSelectionScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // سكن الأبليكيشن الفاتح
      body: Center(
        child: Image.asset(
          "assets/images/logo.png",
          width: 135,
          height: 135,
          errorBuilder: (context, error, stackTrace) {
            // أيقونة احتياطية في حال حدوث مشكلة في مسار الصورة
            return const Icon(Icons.remove_red_eye, color: Colors.blue, size: 120);
          },
        ),
      ),
    );
  }
}