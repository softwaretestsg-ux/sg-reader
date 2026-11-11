import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

enum ScanFilterType {
  autoRefine,    // Shadow-free illumination normalization + crisp text
  crispBw,       // Adaptive local binarization (pure white paper, dark ink)
  grayscale,     // Smooth grayscale without lighting gradients
  colorEnhanced, // Vibrant stamp & signature preservation
  original,      // Raw camera capture
}

class QuadCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const QuadCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  static const QuadCorners defaultNormalized = QuadCorners(
    topLeft: Offset(0.04, 0.04),
    topRight: Offset(0.96, 0.04),
    bottomRight: Offset(0.96, 0.96),
    bottomLeft: Offset(0.04, 0.96),
  );
}

class ScannedPage {
  final String id;
  final Uint8List originalBytes;
  Uint8List processedBytes;
  ScanFilterType currentFilter;
  int rotationAngle; // 0, 90, 180, 270
  QuadCorners corners;

  ScannedPage({
    required this.id,
    required this.originalBytes,
    required this.processedBytes,
    this.currentFilter = ScanFilterType.autoRefine,
    this.rotationAngle = 0,
    this.corners = QuadCorners.defaultNormalized,
  });
}

class ScannerService {
  final ImagePicker _picker = ImagePicker();

  /// Capture a document page using the device camera
  Future<ScannedPage?> capturePageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        maxWidth: 2400,
        maxHeight: 3200,
      );
      if (photo == null) return null;

      final bytes = await File(photo.path).readAsBytes();
      return _createProcessedPage(bytes);
    } catch (e) {
      debugPrint("Camera capture error: $e");
      return null;
    }
  }

  /// Pick a document photo from device gallery
  Future<ScannedPage?> pickPageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 2400,
        maxHeight: 3200,
      );
      if (image == null) return null;

      final bytes = await File(image.path).readAsBytes();
      return _createProcessedPage(bytes);
    } catch (e) {
      debugPrint("Gallery pick error: $e");
      return null;
    }
  }

  Future<ScannedPage> _createProcessedPage(Uint8List rawBytes) async {
    final pageId = DateTime.now().millisecondsSinceEpoch.toString();
    final processed = await compute(_applyFilterIsolate, {
      'bytes': rawBytes,
      'filter': ScanFilterType.autoRefine.index,
      'rotation': 0,
    });

    return ScannedPage(
      id: pageId,
      originalBytes: rawBytes,
      processedBytes: processed,
      currentFilter: ScanFilterType.autoRefine,
      rotationAngle: 0,
      corners: QuadCorners.defaultNormalized,
    );
  }

  /// Re-apply filter and rotation on a scanned page
  Future<Uint8List> processPage(
    Uint8List originalBytes,
    ScanFilterType filter,
    int rotationAngle,
  ) async {
    return await compute(_applyFilterIsolate, {
      'bytes': originalBytes,
      'filter': filter.index,
      'rotation': rotationAngle,
    });
  }

  /// Perspective Rectification (Crop 4 corners and flatten quadrilateral)
  Future<Uint8List> cropPerspective(
    Uint8List originalBytes,
    QuadCorners corners,
  ) async {
    return await compute(_cropPerspectiveIsolate, {
      'bytes': originalBytes,
      'tl_x': corners.topLeft.dx,
      'tl_y': corners.topLeft.dy,
      'tr_x': corners.topRight.dx,
      'tr_y': corners.topRight.dy,
      'br_x': corners.bottomRight.dx,
      'br_y': corners.bottomRight.dy,
      'bl_x': corners.bottomLeft.dx,
      'bl_y': corners.bottomLeft.dy,
    });
  }

  // --- Background Processing Isolates ---

  static Uint8List _cropPerspectiveIsolate(Map<String, dynamic> params) {
    final Uint8List inputBytes = params['bytes'];
    img.Image? src = img.decodeImage(inputBytes);
    if (src == null) return inputBytes;

    final num w = src.width;
    final num h = src.height;

    final tlX = params['tl_x'] * w;
    final tlY = params['tl_y'] * h;
    final trX = params['tr_x'] * w;
    final trY = params['tr_y'] * h;
    final brX = params['br_x'] * w;
    final brY = params['br_y'] * h;
    final blX = params['bl_x'] * w;
    final blY = params['bl_y'] * h;

    // Output target dimensions based on maximum edge lengths
    final topW = math.sqrt(math.pow(trX - tlX, 2) + math.pow(trY - tlY, 2));
    final botW = math.sqrt(math.pow(brX - blX, 2) + math.pow(brY - blY, 2));
    final targetW = math.max(topW, botW).clamp(400, 2400).round();

    final leftH = math.sqrt(math.pow(blX - tlX, 2) + math.pow(blY - tlY, 2));
    final rightH = math.sqrt(math.pow(brX - trX, 2) + math.pow(brY - trY, 2));
    final targetH = math.max(leftH, rightH).clamp(400, 3200).round();

    final dst = img.Image(width: targetW, height: targetH);

    // Bilinear Quadrilateral Dewarping
    for (int y = 0; y < targetH; y++) {
      final double v = y / (targetH - 1.0);
      for (int x = 0; x < targetW; x++) {
        final double u = x / (targetW - 1.0);

        // Interpolate source coordinates
        final double srcX = (1 - u) * (1 - v) * tlX +
            u * (1 - v) * trX +
            u * v * brX +
            (1 - u) * v * blX;

        final double srcY = (1 - u) * (1 - v) * tlY +
            u * (1 - v) * trY +
            u * v * brY +
            (1 - u) * v * blY;

        // Bilinear Pixel Sampling from source
        final int x0 = srcX.floor().clamp(0, src.width - 1);
        final int y0 = srcY.floor().clamp(0, src.height - 1);
        final int x1 = (x0 + 1).clamp(0, src.width - 1);
        final int y1 = (y0 + 1).clamp(0, src.height - 1);

        final double fx = srcX - x0;
        final double fy = srcY - y0;

        final p00 = src.getPixel(x0, y0);
        final p10 = src.getPixel(x1, y0);
        final p01 = src.getPixel(x0, y1);
        final p11 = src.getPixel(x1, y1);

        final r = (1 - fx) * (1 - fy) * p00.r +
            fx * (1 - fy) * p10.r +
            (1 - fx) * fy * p01.r +
            fx * fy * p11.r;

        final g = (1 - fx) * (1 - fy) * p00.g +
            fx * (1 - fy) * p10.g +
            (1 - fx) * fy * p01.g +
            fx * fy * p11.g;

        final b = (1 - fx) * (1 - fy) * p00.b +
            fx * (1 - fy) * p10.b +
            (1 - fx) * fy * p01.b +
            fx * fy * p11.b;

        dst.setPixelRgb(x, y, r.round(), g.round(), b.round());
      }
    }

    return Uint8List.fromList(img.encodeJpg(dst, quality: 92));
  }

  static Uint8List _applyFilterIsolate(Map<String, dynamic> params) {
    final Uint8List inputBytes = params['bytes'];
    final int filterIdx = params['filter'];
    final int rotation = params['rotation'];
    final filter = ScanFilterType.values[filterIdx];

    img.Image? decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    // 1. Rotation
    if (rotation != 0) {
      decoded = img.copyRotate(decoded, angle: rotation);
    }

    // 2. Filters
    switch (filter) {
      case ScanFilterType.autoRefine:
        // Background Division + Contrast Boost:
        // Downsample to compute background illumination map
        final bgSmall = img.copyResize(decoded, width: decoded.width ~/ 8, height: decoded.height ~/ 8);
        final bgBlurred = img.gaussianBlur(bgSmall, radius: 10);
        final bgFull = img.copyResize(bgBlurred, width: decoded.width, height: decoded.height);

        // Normalize: Divide original by background illumination
        for (int y = 0; y < decoded.height; y++) {
          for (int x = 0; x < decoded.width; x++) {
            final p = decoded.getPixel(x, y);
            final bgP = bgFull.getPixel(x, y);

            final newR = ((p.r * 248) / (bgP.r + 1)).clamp(0, 255).toInt();
            final newG = ((p.g * 248) / (bgP.g + 1)).clamp(0, 255).toInt();
            final newB = ((p.b * 248) / (bgP.b + 1)).clamp(0, 255).toInt();

            p.r = newR;
            p.g = newG;
            p.b = newB;
          }
        }
        decoded = img.adjustColor(decoded, contrast: 1.15);
        break;

      case ScanFilterType.crispBw:
        // Adaptive Binarization:
        // Grayscale conversion followed by shadow-immune thresholding
        decoded = img.grayscale(decoded);
        final bgSmall = img.copyResize(decoded, width: decoded.width ~/ 8, height: decoded.height ~/ 8);
        final bgBlurred = img.gaussianBlur(bgSmall, radius: 12);
        final bgFull = img.copyResize(bgBlurred, width: decoded.width, height: decoded.height);

        for (int y = 0; y < decoded.height; y++) {
          for (int x = 0; x < decoded.width; x++) {
            final p = decoded.getPixel(x, y);
            final bgP = bgFull.getPixel(x, y);
            // Local threshold ratio
            final ratio = (p.r / (bgP.r + 1));
            final val = ratio < 0.82 ? 0 : 255;
            p.r = val;
            p.g = val;
            p.b = val;
          }
        }
        break;

      case ScanFilterType.grayscale:
        decoded = img.grayscale(decoded);
        decoded = img.adjustColor(decoded, contrast: 1.20, brightness: 1.08);
        break;

      case ScanFilterType.colorEnhanced:
        // Preserve vivid colors for rubber stamps, seals, colored headings
        decoded = img.adjustColor(
          decoded,
          contrast: 1.25,
          brightness: 1.06,
          saturation: 1.35,
        );
        break;

      case ScanFilterType.original:
        break;
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }
}
