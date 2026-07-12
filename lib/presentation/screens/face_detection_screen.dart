import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/camera_provider.dart';
import '../../logic/providers/face_provider.dart';
import '../widgets/shared_camera_preview.dart';

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  CameraProvider? _cameraProvider;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // الانتظار حتى الانتهاء من بناء الواجهة لضمان سلامة التهيئة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraProvider = Provider.of<CameraProvider>(context, listen: false);
      final faceProvider = Provider.of<FaceProvider>(context, listen: false);

      // تحميل النموذج محلياً
      faceProvider.loadModel();

      // تغيير سرعة معالجة الفريمات لتناسب التعرف على الوجوه (إطار كل 1.2 ثانية)
      _cameraProvider!.setTaskSpeed(1200);

      // مراقبة وتشغيل بث الكاميرا
      if (_cameraProvider!.isInitialized) {
        _cameraProvider!.startDetection((image) {
          faceProvider.onFrameAvailable(image, _cameraProvider!.controller!.description);
        });
        print("📸 [FaceDetectionScreen] الكاميرا جاهزة، تم فتح بث التعرف على الوجوه!");
      } else {
        void Function()? cameraListener;
        cameraListener = () {
          if (_cameraProvider!.isInitialized) {
            _cameraProvider!.startDetection((image) {
              faceProvider.onFrameAvailable(image, _cameraProvider!.controller!.description);
            });
            _cameraProvider!.removeListener(cameraListener!);
          }
        };
        _cameraProvider!.addListener(cameraListener);
      }
    });
  }

  @override
  void dispose() {
    _cameraProvider?.stopDetection();
    _nameController.dispose();
    super.dispose();
  }

  /// إظهار نافذة تسجيل اسم الوجه المكتشف حالياً
  void _showRegisterDialog(BuildContext context, FaceProvider provider) {
    if (provider.lastDetectedFace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء توجيه الكاميرا لوجه شخص بوضوح أولاً")),
      );
      return;
    }

    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تسجيل شخص جديد", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("سيتم أخذ البصمة الحالية للوجه المكتشف، الرجاء كتابة اسم الشخص:"),
            const SizedBox(height: 15),
            TextField(
              controller: _nameController,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "مثال: الوالد، أحمد، سارة",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.red, fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                final success = await provider.registerNewFace(name);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("تم تسجيل $name بنجاح")),
                  );
                }
              }
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  /// عرض قائمة الأشخاص المسجلين لحذفهم أو إدارتهم
  void _showDirectoryBottomSheet(BuildContext context, FaceProvider provider) {
    final names = provider.getRegisteredNames();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "دليل الأشخاص المسجلين",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 25),
                  if (names.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        "لا يوجد أي أشخاص مسجلين بعد.",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: names.length,
                        itemBuilder: (context, index) {
                          final name = names[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              title: Text(name, style: const TextStyle(fontSize: 18)),
                              trailing: Semantics(
                                label: "حذف $name",
                                button: true,
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    await provider.deletePerson(name);
                                    setModalState(() {
                                      names.remove(name);
                                    });
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إغلاق", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final faceProvider = Provider.of<FaceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("التعرف على الأشخاص"),
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
          // 1. عرض بث الكاميرا المشترك في الخلفية
          const SharedCameraPreview(),

          // 2. واجهة تفاعلية علوية وسفلية للمستخدم الكفيف
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // مستطيل الحالة في الأعلى
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  faceProvider.result,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

              // أزرار التحكم السفلية المخصصة للمكفوفين
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // زر دليل الأشخاص
                    Semantics(
                      button: true,
                      label: "دليل الأشخاص المسجلين، اضغط مرتين للفتح",
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () => _showDirectoryBottomSheet(context, faceProvider),
                        icon: const Icon(Icons.people, color: Colors.white),
                        label: const Text("الدليل", style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),

                    // زر تسجيل شخص جديد
                    Semantics(
                      button: true,
                      label: "تسجيل شخص جديد، اضغط مرتين لالتقاط بصمة الوجه وإدخال الاسم",
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () => _showRegisterDialog(context, faceProvider),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text("تسجيل وجه", style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
