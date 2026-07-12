import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/camera_provider.dart';
import '../../logic/providers/currency_provider.dart';
import '../widgets/shared_camera_preview.dart'; // استدعاء الكاميرا الموحدة

class CurrencyDetectionScreen extends StatefulWidget {
  const CurrencyDetectionScreen({super.key});

  @override
  State<CurrencyDetectionScreen> createState() => _CurrencyDetectionScreenState();
}

class _CurrencyDetectionScreenState extends State<CurrencyDetectionScreen> {
  CameraProvider? _cameraProvider;
  
  @override
  void initState() {
    super.initState();
    
    // 1. ننتظر بناء واجهة المستخدم أولاً لضمان عدم حدوث تصادم أثناء التنقل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraProvider = Provider.of<CameraProvider>(context, listen: false);
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

      // تحميل موديل الذكاء الاصطناعي أوفلاين
      currencyProvider.loadModel();

      // 2. خطة الأمان والمراقبة التلقائية للكاميرا
      if (_cameraProvider!.isInitialized) {
        // إذا كانت الكاميرا جاهزة مسبقاً بفعل الـ SharedCameraPreview، نفتح صنبور الفريمات فوراً
        _cameraProvider!.startDetection((image) {
          currencyProvider.onFrameAvailable(image, _cameraProvider!);
        });
        print("📸📸📸 [SUCCESS] الكاميرا جاهزة مسبقاً، تم فتح بث الفريمات!");
      } else {
        // إذا لم تجهز بعد (وهذا ما يحدث في السامسونج)، نضع مستمعاً ذكياً يراقبها
        print("⏳ الكاميرا قيد التجهيز... نراقبها الآن تلقائياً...");
        
        // تعديل أمان القيم الفارغة (Null Safety): تعريف المتغير أولاً كقيمة قابلة للاستدعاء الفارغ
        void Function()? cameraListener;
        
        // تعيين الدالة الفعلية للمتغير في سطر مستقل لتهدئة المترجم
        cameraListener = () {
          if (_cameraProvider!.isInitialized) {
            // انطلق صنبور الفريمات فوراً في اللحظة التي تحولت فيها الحالة إلى جاهز!
            _cameraProvider!.startDetection((image) {
              currencyProvider.onFrameAvailable(image, _cameraProvider!);
            });
            print("🚀🚀🚀 [SUCCESS] الكاميرا جهزت الآن تلقائياً وتم فتح صنبور الفريمات!");
            
            // نفك المستمع فوراً باستخدام علامة التعجب لإنهاء المراقبة بعد النجاح
            _cameraProvider!.removeListener(cameraListener!);
          }
        };
        
        // تسجيل المستمع في الـ Provider لبدء المراقبة
        _cameraProvider!.addListener(cameraListener);
      }
    });
  }

  @override
  void dispose() {
    // مهم جداً: إيقاف بث الكاميرا عند الخروج من الشاشة لحفظ موارد الجهاز والبطارية
    _cameraProvider?.stopDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("النسخة المحدثة - الكشف التلقائي"),
        actions: [
          Semantics(
            button: true,
            label: "تبديل الكاميرا، اضغط مرتين للتبديل بين الكاميرا الأمامية والخلفية",
            child: IconButton(
              icon: const Icon(Icons.flip_camera_ios, size: 28),
              onPressed: () async {
                final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
                await cameraProvider.toggleCamera();
              },
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          // 1. عرض بث الكاميرا الموحد في الخلفية
          const SharedCameraPreview(),

          // 2. واجهة المستخدم لعرض نتيجة التعرف على العملة للكفيف
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.black54,
              child: Text(
                currencyProvider.result, // عرض نتيجة تصنيف YOLOv11 الحالية
                style: const TextStyle(color: Colors.white, fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}