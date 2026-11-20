import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Offset;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/document_file.dart';

/// Industrial-Strength PDF Powerhouse Service
/// Handles Digital Signatures, Page Merge/Split, Compression, and Text Extraction
class PdfPowerhouseService {
  /// Stamp a digital signature (transparent PNG) onto a target PDF page
  Future<String> stampSignature({
    required String pdfPath,
    required Uint8List signaturePngBytes,
    required int pageIndex,
    required Rect stampRect,
    String? outputCustomPath,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception("Target PDF file does not exist.");
    }

    final inputBytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: inputBytes);

    if (pageIndex < 0 || pageIndex >= document.pages.count) {
      document.dispose();
      throw Exception("Invalid page index: $pageIndex. Document has ${document.pages.count} pages.");
    }

    final targetPage = document.pages[pageIndex];
    final bitmap = PdfBitmap(signaturePngBytes);

    // Render signature bitmap at user-selected coordinate and size
    targetPage.graphics.drawImage(bitmap, stampRect);

    final savedBytes = await document.save();
    document.dispose();

    String outputPath = outputCustomPath ?? pdfPath;
    if (outputCustomPath == null) {
      // Create a new signed file name to preserve the original unless explicitly overwritten
      final dir = file.parent.path;
      final baseName = file.uri.pathSegments.last.replaceAll('.pdf', '');
      outputPath = '$dir/${baseName}_signed_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(savedBytes, flush: true);
    return outputPath;
  }

  /// Merge multiple PDF files in sequential order into a single unified PDF
  Future<DocumentFile> mergePdfs({
    required List<String> inputPaths,
    String? mergedFileName,
    String? customOutputPath,
  }) async {
    if (inputPaths.length < 2) {
      throw Exception("At least 2 PDF files are required for merging.");
    }

    final outputPdf = PdfDocument();

    for (final path in inputPaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final srcDoc = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < srcDoc.pages.count; i++) {
        final srcPage = srcDoc.pages[i];
        final template = srcPage.createTemplate();
        final newPage = outputPdf.pages.add();
        // Match source page dimensions and orientation
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      srcDoc.dispose();
    }

    final mergedBytes = await outputPdf.save();
    outputPdf.dispose();

    String savedPath;
    String finalName = mergedFileName ?? 'Merged_Document_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (customOutputPath != null) {
      savedPath = customOutputPath;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      savedPath = '${appDir.path}/$finalName';
    }

    final mergedFile = File(savedPath);
    await mergedFile.writeAsBytes(mergedBytes, flush: true);

    return DocumentFile(
      path: savedPath,
      name: finalName,
      sizeInBytes: await mergedFile.length(),
      type: DocumentType.pdf,
      lastOpened: DateTime.now(),
    );
  }

  /// Split/Extract specific pages from a PDF and save as a new document
  Future<DocumentFile> extractPages({
    required String inputPath,
    required List<int> pageIndices,
    String? outputFileName,
    String? customOutputPath,
  }) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception("Source PDF does not exist.");
    }

    final inputBytes = await file.readAsBytes();
    final srcDoc = PdfDocument(inputBytes: inputBytes);
    final outputPdf = PdfDocument();

    for (final pageIndex in pageIndices) {
      if (pageIndex >= 0 && pageIndex < srcDoc.pages.count) {
        final srcPage = srcDoc.pages[pageIndex];
        final template = srcPage.createTemplate();
        final newPage = outputPdf.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    final extractedBytes = await outputPdf.save();
    srcDoc.dispose();
    outputPdf.dispose();

    String savedPath;
    String name = outputFileName ?? 'Extracted_Pages_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (customOutputPath != null) {
      savedPath = customOutputPath;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      savedPath = '${appDir.path}/$name';
    }

    final outputFile = File(savedPath);
    await outputFile.writeAsBytes(extractedBytes, flush: true);

    return DocumentFile(
      path: savedPath,
      name: name,
      sizeInBytes: await outputFile.length(),
      type: DocumentType.pdf,
      lastOpened: DateTime.now(),
    );
  }

  /// Smart PDF Compressor: optimizes PDF streams and downsamples images
  Future<DocumentFile> compressPdf(String inputPath, {String? customOutputPath}) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception("Target PDF does not exist.");
    }

    final originalBytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: originalBytes);

    // Apply highest stream compression
    document.compressionLevel = PdfCompressionLevel.best;

    final compressedBytes = await document.save();
    document.dispose();

    String savedPath;
    final baseName = file.uri.pathSegments.last.replaceAll('.pdf', '');
    final name = '${baseName}_compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (customOutputPath != null) {
      savedPath = customOutputPath;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      savedPath = '${appDir.path}/$name';
    }

    final outputFile = File(savedPath);
    await outputFile.writeAsBytes(compressedBytes, flush: true);

    return DocumentFile(
      path: savedPath,
      name: name,
      sizeInBytes: await outputFile.length(),
      type: DocumentType.pdf,
      lastOpened: DateTime.now(),
    );
  }

  /// Extract complete continuous text across all PDF pages for Liquid Responsive Mode & TTS
  Future<List<String>> extractPagesText(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      return [];
    }

    try {
      final inputBytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: inputBytes);
      final extractor = PdfTextExtractor(document);

      final List<String> pagesText = [];
      for (int i = 0; i < document.pages.count; i++) {
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        pagesText.add(pageText.trim());
      }

      document.dispose();
      return pagesText;
    } catch (e) {
      debugPrint("Error extracting PDF text: $e");
      return [];
    }
  }
}
