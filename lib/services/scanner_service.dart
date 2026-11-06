import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

enum ScanFilterType {
  autoRefine,
  crispBw,
  grayscale,
  colorEnhanced,
  original,
}

class ScannedPage {
  final String id;
  final Uint8List originalBytes;
  Uint8List processedBytes;
  ScanFilterType currentFilter;
  int rotationAngle; // 0, 90, 180, 270

  ScannedPage({
    required this.id,
    required this.originalBytes,
    required this.processedBytes,
    this.currentFilter = ScanFilterType.autoRefine,
    this.rotationAngle = 0,
  });
}

class ScannerService {
  final ImagePicker _picker = ImagePicker();

  /// Capture a document page using the device camera
  Future<ScannedPage?> capturePageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
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
        imageQuality: 92,
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
    // Default filter is autoRefine for clean document appearance
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

  /// Background isolate processor for instant non-blocking image enhancement
  static Uint8List _applyFilterIsolate(Map<String, dynamic> params) {
    final Uint8List inputBytes = params['bytes'];
    final int filterIdx = params['filter'];
    final int rotation = params['rotation'];
    final filter = ScanFilterType.values[filterIdx];

    img.Image? decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    // 1. Handle Rotation
    if (rotation != 0) {
      decoded = img.copyRotate(decoded, angle: rotation);
    }

    // 2. Handle Refinement Filters
    switch (filter) {
      case ScanFilterType.autoRefine:
        // Magic Document: Contrast boost + Brightness normalization + Light unsharp mask
        decoded = img.adjustColor(
          decoded,
          contrast: 1.25,
          brightness: 1.10,
          saturation: 1.05,
        );
        // Sharpen text outlines
        decoded = img.convolution(decoded, filter: [
          0, -1, 0,
          -1, 5, -1,
          0, -1, 0
        ]);
        break;

      case ScanFilterType.crispBw:
        // High-contrast Document B&W: Grayscale + high contrast thresholding
        decoded = img.grayscale(decoded);
        decoded = img.adjustColor(
          decoded,
          contrast: 1.70,
          brightness: 1.15,
        );
        break;

      case ScanFilterType.grayscale:
        decoded = img.grayscale(decoded);
        decoded = img.adjustColor(
          decoded,
          contrast: 1.15,
          brightness: 1.05,
        );
        break;

      case ScanFilterType.colorEnhanced:
        // Vibrant color enhancement for stamps, colored text, certificates
        decoded = img.adjustColor(
          decoded,
          contrast: 1.20,
          brightness: 1.05,
          saturation: 1.35,
        );
        break;

      case ScanFilterType.original:
        // Raw bytes with rotation only
        break;
    }

    // Encode as high-quality JPEG
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
  }
}
