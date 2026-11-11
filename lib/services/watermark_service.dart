import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

enum WatermarkColorType {
  lightGray,    // Faint diagonal text ("DRAFT", "CONFIDENTIAL", "SAMPLE")
  redStamp,     // Red review/evaluation stamps
  blueStamp,    // Blue stamps or evaluation banners
  yellowMarker, // Yellow highlighter/watermark tint
}

class WatermarkService {
  /// 1. IMAGE: Remove color-keyed watermarks (e.g. faint diagonal text or colored stamps)
  Future<Uint8List> removeColorWatermark(
    Uint8List inputBytes, {
    WatermarkColorType type = WatermarkColorType.lightGray,
    double sensitivity = 1.0,
  }) async {
    return await compute(_removeColorWatermarkIsolate, {
      'bytes': inputBytes,
      'type': type.index,
      'sensitivity': sensitivity,
    });
  }

  /// 2. IMAGE: Seamlessly erase a targeted rectangular region (e.g. corner logo, footer stamp)
  Future<Uint8List> eraseRegion(
    Uint8List inputBytes, {
    required double normLeft,
    required double normTop,
    required double normWidth,
    required double normHeight,
  }) async {
    return await compute(_eraseRegionIsolate, {
      'bytes': inputBytes,
      'left': normLeft,
      'top': normTop,
      'width': normWidth,
      'height': normHeight,
    });
  }

  /// 3. WORD (.docx): Strip OpenXML watermark shapes from headers and body
  Future<bool> removeDocxWatermark(String docxPath, {String? outputPath}) async {
    try {
      final file = File(docxPath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      bool modified = false;

      for (final archFile in archive) {
        if (archFile.isFile) {
          final name = archFile.name.toLowerCase();
          // Target document.xml and any header XML files where watermarks live
          if (name == 'word/document.xml' || name.startsWith('word/header')) {
            String xmlContent = utf8.decode(archFile.content as List<int>);

            // 1. Remove VML Watermark Shapes (PowerPlusWaterMarkObject or _x0000_m102)
            final vmlWatermarkRegex = RegExp(
              r'<w:r\b[^>]*>[\s\S]*?<v:shape\b[^>]*?(?:WaterMark|PowerPlus|type="#_x0000_m102")[^>]*>[\s\S]*?</v:shape>[\s\S]*?</w:r>',
              caseSensitive: false,
            );
            if (vmlWatermarkRegex.hasMatch(xmlContent)) {
              xmlContent = xmlContent.replaceAll(vmlWatermarkRegex, '');
              modified = true;
            }

            // 2. Remove standard WordArt watermarks
            final wordArtRegex = RegExp(
              r'<v:shape\b[^>]*?id="[^"]*?(?:WaterMark|PowerPlus)[^"]*"[^>]*>[\s\S]*?</v:shape>',
              caseSensitive: false,
            );
            if (wordArtRegex.hasMatch(xmlContent)) {
              xmlContent = xmlContent.replaceAll(wordArtRegex, '');
              modified = true;
            }

            // 3. Remove modern DrawingML watermark shapes
            final drawingWatermarkRegex = RegExp(
              r'<w:drawing\b[^>]*>[\s\S]*?(?:Watermark|CONFIDENTIAL|DRAFT|SAMPLE)[\s\S]*?</w:drawing>',
              caseSensitive: false,
            );
            if (drawingWatermarkRegex.hasMatch(xmlContent)) {
              xmlContent = xmlContent.replaceAll(drawingWatermarkRegex, '');
              modified = true;
            }

            final newBytes = utf8.encode(xmlContent);
            newArchive.addFile(ArchiveFile(archFile.name, newBytes.length, newBytes));
          } else {
            newArchive.addFile(ArchiveFile(archFile.name, (archFile.content as List<int>).length, archFile.content));
          }
        }
      }

      final outPath = outputPath ?? docxPath;
      final encoded = ZipEncoder().encode(newArchive);
      if (encoded != null) {
        await File(outPath).writeAsBytes(encoded);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error removing DOCX watermark: $e");
      return false;
    }
  }

  // --- Background Isolates ---

  static Uint8List _removeColorWatermarkIsolate(Map<String, dynamic> params) {
    final Uint8List inputBytes = params['bytes'];
    final int typeIdx = params['type'];
    final double sensitivity = params['sensitivity'];
    final type = WatermarkColorType.values[typeIdx];

    img.Image? decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    for (int y = 0; y < decoded.height; y++) {
      for (int x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        final num r = pixel.r;
        final num g = pixel.g;
        final num b = pixel.b;

        // Convert to Luminance & Saturation
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final delta = maxC - minC;
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        final saturation = maxC == 0 ? 0 : delta / maxC;

        bool shouldErase = false;

        switch (type) {
          case WatermarkColorType.lightGray:
            // Faint diagonal text: High luminance (175 - 245), low saturation (< 0.18)
            // But NOT dark text (which has luminance < 140)
            if (luminance >= (170 - (20 * sensitivity)) && luminance <= 248 && saturation < 0.20) {
              shouldErase = true;
            }
            break;

          case WatermarkColorType.redStamp:
            // Red stamps/watermarks: Red channel significantly higher than green & blue
            if (r > 130 && r > (g * 1.35) && r > (b * 1.35)) {
              shouldErase = true;
            }
            break;

          case WatermarkColorType.blueStamp:
            // Blue stamps/watermarks: Blue channel significantly higher than red
            if (b > 120 && b > (r * 1.25) && b > (g * 1.10)) {
              shouldErase = true;
            }
            break;

          case WatermarkColorType.yellowMarker:
            // Yellow tint: High R & G, low B
            if (r > 160 && g > 160 && b < 120) {
              shouldErase = true;
            }
            break;
        }

        if (shouldErase) {
          // Replace with clean white paper pixel
          pixel.r = 255;
          pixel.g = 255;
          pixel.b = 255;
        }
      }
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }

  static Uint8List _eraseRegionIsolate(Map<String, dynamic> params) {
    final Uint8List inputBytes = params['bytes'];
    final double normL = params['left'];
    final double normT = params['top'];
    final double normW = params['width'];
    final double normH = params['height'];

    img.Image? decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    final int pxL = (normL * decoded.width).clamp(0, decoded.width - 1).toInt();
    final int pxT = (normT * decoded.height).clamp(0, decoded.height - 1).toInt();
    final int pxW = (normW * decoded.width).clamp(1, decoded.width - pxL).toInt();
    final int pxH = (normH * decoded.height).clamp(1, decoded.height - pxT).toInt();

    // Sample background paper color from the perimeter of the selection
    int bgR = 0, bgG = 0, bgB = 0, sampleCount = 0;
    void sample(int x, int y) {
      if (x >= 0 && x < decoded!.width && y >= 0 && y < decoded.height) {
        final p = decoded.getPixel(x, y);
        bgR += p.r.toInt();
        bgG += p.g.toInt();
        bgB += p.b.toInt();
        sampleCount++;
      }
    }

    for (int x = pxL; x < pxL + pxW; x += 4) {
      sample(x, pxT - 2);
      sample(x, pxT + pxH + 2);
    }
    for (int y = pxT; y < pxT + pxH; y += 4) {
      sample(pxL - 2, y);
      sample(pxL + pxW + 2, y);
    }

    final fillR = sampleCount > 0 ? (bgR / sampleCount).round() : 255;
    final fillG = sampleCount > 0 ? (bgG / sampleCount).round() : 255;
    final fillB = sampleCount > 0 ? (bgB / sampleCount).round() : 255;

    // Fill region with sampled paper tone
    for (int y = pxT; y < pxT + pxH; y++) {
      for (int x = pxL; x < pxL + pxW; x++) {
        final p = decoded.getPixel(x, y);
        p.r = fillR;
        p.g = fillG;
        p.b = fillB;
      }
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }
}
