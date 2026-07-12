import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// مصفوفة بسيطة لنقل بيانات الكاميرا إلى الـ Isolate بدون مشاكل كائنات native
class ConversionInput {
  final List<Uint8List> planes;
  final int width;
  final int height;
  final List<int> rowStrides;
  final List<int> pixelStrides;

  ConversionInput(this.planes, this.width, this.height, this.rowStrides, this.pixelStrides);
}

class ImageConverter {
  static img.Image convertCameraImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      // إذا كانت الكاميرا بطبقة واحدة (مثل iOS بصيغة BGRA8888)
      if (image.planes.length == 1) {
        final plane = image.planes[0];
        final bytes = plane.bytes;
        final int bytesPerRow = plane.bytesPerRow;
        
        final imgImage = img.Image(width: width, height: height);
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final int index = y * bytesPerRow + x * 4;
            if (index + 3 >= bytes.length) continue;
            
            final int b = bytes[index];
            final int g = bytes[index + 1];
            final int r = bytes[index + 2];
            
            imgImage.setPixelRgb(x, y, r, g, b);
          }
        }
        return imgImage;
      }

      // إذا كانت الكاميرا بثلاث طبقات (YUV420 - أندرويد)
      var imgImage = img.Image(width: width, height: height);

      final planes = image.planes;
      final Uint8List yPlane = planes[0].bytes;
      final Uint8List uPlane = planes[1].bytes;
      final Uint8List vPlane = planes[2].bytes;

      final int yRowStride = planes[0].bytesPerRow;
      final int uvRowStride = planes[1].bytesPerRow;
      final int uvPixelStride = planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        final int uvY = y >> 1;
        for (int x = 0; x < width; x++) {
          final int uvX = x >> 1;

          final int yIndex = y * yRowStride + x;
          final int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

          if (yIndex >= yPlane.length || uvIndex >= uPlane.length || uvIndex >= vPlane.length) {
            continue;
          }

          final int yp = yPlane[yIndex];
          final int up = uPlane[uvIndex];
          final int vp = vPlane[uvIndex];

          int r = (yp + (1.370705 * (vp - 128))).toInt().clamp(0, 255);
          int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128))).toInt().clamp(0, 255);
          int b = (yp + (1.732446 * (up - 128))).toInt().clamp(0, 255);

          imgImage.setPixelRgb(x, y, r, g, b);
        }
      }
      return imgImage;
    } catch (e) {
      print("❌ [ImageConverter] خطأ في تحويل صورة الكاميرا: $e");
      return img.Image(width: 1, height: 1);
    }
  }

  /// تحويل وتصغير إطار الكاميرا مباشرة إلى مصفوفة رقمية أحادية من نوع Float32List بأبعاد 640x640 وبشكل فائق السرعة
  /// تستخدم الحسابات الصحيحة للـ strides والعمليات الرياضية الصحيحة للـ integer math لتفادي الـ block
  static Float32List convertYUV420ToFloat32List(ConversionInput input, int targetWidth, int targetHeight) {
    final int width = input.width;
    final int height = input.height;

    final Float32List buffer = Float32List(1 * targetWidth * targetHeight * 3);

    final double scaleX = width / targetWidth;
    final double scaleY = height / targetHeight;

    final Uint8List yPlane = input.planes[0];
    final Uint8List uPlane = input.planes[1];
    final Uint8List vPlane = input.planes[2];

    final int yRowStride = input.rowStrides[0];
    final int uvRowStride = input.rowStrides[1];
    final int uvPixelStride = input.pixelStrides[1];

    int bufferIndex = 0;

    for (int y = 0; y < targetHeight; y++) {
      final int sourceY = (y * scaleY).toInt().clamp(0, height - 1);
      final int uvY = sourceY >> 1;

      for (int x = 0; x < targetWidth; x++) {
        final int sourceX = (x * scaleX).toInt().clamp(0, width - 1);
        final int uvX = sourceX >> 1;

        final int yIndex = sourceY * yRowStride + sourceX;
        final int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

        if (yIndex >= yPlane.length || uvIndex >= uPlane.length || uvIndex >= vPlane.length) {
          buffer[bufferIndex++] = 0.0;
          buffer[bufferIndex++] = 0.0;
          buffer[bufferIndex++] = 0.0;
          continue;
        }

        final int yp = yPlane[yIndex];
        final int up = uPlane[uvIndex];
        final int vp = vPlane[uvIndex];

        // تحويل سريع باستخدام عمليات الـ bitwise والـ integer arithmetic لتفادي بطء الفلوت
        final int r = (yp + ((1404 * (vp - 128)) >> 10)).clamp(0, 255);
        final int g = (yp - ((346 * (up - 128) + 715 * (vp - 128)) >> 10)).clamp(0, 255);
        final int b = (yp + ((1774 * (up - 128)) >> 10)).clamp(0, 255);

        buffer[bufferIndex++] = r / 255.0;
        buffer[bufferIndex++] = g / 255.0;
        buffer[bufferIndex++] = b / 255.0;
      }
    }

    return buffer;
  }
}