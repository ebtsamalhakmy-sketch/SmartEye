import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:io';

class FaceDetectorService {
  late FaceDetector _faceDetector;

  FaceDetectorService() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast, // سريع ومناسب للبث المباشر للكاميرا
      enableLandmarks: false,                 // لا نحتاج لمعالم الوجه لتسريع العملية
      enableClassification: false,            // لا نحتاج لتصنيف الابتسامة أو فتح العين
      enableTracking: false,
    );
    _faceDetector = FaceDetector(options: options);
  }

  /// الكشف عن الوجوه من إطار كاميرا حي
  Future<List<Face>> detectFromCameraImage(CameraImage image, CameraDescription cameraDescription) async {
    final inputImage = _convertCameraImageToInputImage(image, cameraDescription);
    if (inputImage == null) return [];
    return await _faceDetector.processImage(inputImage);
  }

  /// تحويل إطار الكاميرا (CameraImage) إلى صيغة مدعومة من ML Kit (InputImage)
  InputImage? _convertCameraImageToInputImage(CameraImage image, CameraDescription cameraDescription) {
    try {
      Uint8List bytes;
      InputImageFormat format;
      int bytesPerRow;

      if (Platform.isIOS) {
        // iOS: تجميع طبقات الكاميرا مباشرة بصيغة bgra8888
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
        format = InputImageFormat.bgra8888;
        bytesPerRow = image.planes[0].bytesPerRow;
      } else {
        // Android: تحويل YUV420 المتعدد الطبقات إلى مصفوفة NV21 أحادية ومقيسة
        bytes = _convertYUV420ToNV21(image);
        format = InputImageFormat.nv21;
        bytesPerRow = image.width; // الصورة المحولة خالية من الحشو (padding)
      }

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _getRotation(cameraDescription.sensorOrientation);

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      print("❌ [FaceDetectorService] خطأ في تحويل الصورة: $e");
      return null;
    }
  }

  /// تحويل YUV420 إلى NV21 مع تصفية الحشو (padding) ودمج قنوات الألوان بالتبادل
  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = (width / 2).floor() * (height / 2).floor() * 2;
    final nv21 = Uint8List(ySize + uvSize);

    // 1. نسخ قناة السطوع Y بدقة صفاً بصف لإزالة حشو البكسلات (row padding)
    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    int yOffset = 0;
    for (int y = 0; y < height; y++) {
      nv21.setRange(yOffset, yOffset + width, yBytes.sublist(y * yRowStride, y * yRowStride + width));
      yOffset += width;
    }

    // 2. دمج قنوات الألوان U و V بالتداخل (V ثم U) مع حساب قفزات البكسلات
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    int uvOffset = ySize;
    for (int y = 0; y < (height / 2).floor(); y++) {
      for (int x = 0; x < (width / 2).floor(); x++) {
        final int uIndex = (y * uvRowStride + x * uvPixelStride).toInt();
        final int vIndex = (y * uvRowStride + x * uvPixelStride).toInt();

        if (uIndex < uBytes.length && vIndex < vBytes.length && uvOffset < nv21.length - 1) {
          nv21[uvOffset++] = vBytes[vIndex];
          nv21[uvOffset++] = uBytes[uIndex];
        }
      }
    }

    return nv21;
  }

  /// تحويل زوايا الحساس الرقمية لزوايا ML Kit
  InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// إغلاق المعالج عند الإلغاء لتحرير موارد النظام
  void close() {
    _faceDetector.close();
  }
}
