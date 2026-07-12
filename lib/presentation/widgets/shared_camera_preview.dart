import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/camera_provider.dart';

class SharedCameraPreview extends StatefulWidget {
  const SharedCameraPreview({Key? key}) : super(key: key);

  @override
  State<SharedCameraPreview> createState() => _SharedCameraPreviewState();
}

class _SharedCameraPreviewState extends State<SharedCameraPreview> {
  @override
  void initState() {
    super.initState();
    // استدعاء التهيئة مرة واحدة فقط عند بدء ظهور الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CameraProvider>(context, listen: false).setupCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = Provider.of<CameraProvider>(context);

    if (!cameraProvider.isInitialized || cameraProvider.controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CameraPreview(cameraProvider.controller!);
  }
}