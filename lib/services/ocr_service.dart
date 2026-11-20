import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Result of an Offline OCR text recognition run
class OcrResult {
  final String fullText;
  final List<String> lines;
  final int wordCount;
  final int charCount;
  final bool isDevanagari;
  final String? imagePath;

  OcrResult({
    required this.fullText,
    required this.lines,
    required this.wordCount,
    required this.charCount,
    required this.isDevanagari,
    this.imagePath,
  });

  bool get isEmpty => fullText.trim().isEmpty;
}

/// 100% Offline & Private On-Device Text Recognition Engine
class OcrService {
  Future<Directory> _getStorageDir() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    } catch (_) {}
    return await getApplicationDocumentsDirectory();
  }

  /// Recognize text from a local image file (Camera photo, scanned document, receipt)
  Future<OcrResult> recognizeTextFromFile(String filePath, {bool devanagariSupport = true}) async {
    final inputImage = InputImage.fromFilePath(filePath);
    return _processInputImage(inputImage, filePath: filePath, devanagariSupport: devanagariSupport);
  }

  /// Recognize text from in-memory image bytes
  Future<OcrResult> recognizeTextFromBytes(Uint8List bytes, {bool devanagariSupport = true}) async {
    // Write to a temporary file so Google ML Kit's native engine can process efficiently
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytes);

    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final result = await _processInputImage(inputImage, filePath: tempFile.path, devanagariSupport: devanagariSupport);
      return result;
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Internal processor running Latin and optionally Devanagari recognition
  Future<OcrResult> _processInputImage(InputImage inputImage, {String? filePath, bool devanagariSupport = true}) async {
    // 1. Primary Latin Recognizer
    final latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    RecognizedText latinText;
    try {
      latinText = await latinRecognizer.processImage(inputImage);
    } finally {
      await latinRecognizer.close();
    }

    String extractedText = latinText.text;
    bool hasDevanagari = false;

    // 2. If Devanagari (Hindi) is enabled, check with Devanagari recognizer if Latin yielded sparse text
    if (devanagariSupport) {
      final devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
      try {
        final devaText = await devanagariRecognizer.processImage(inputImage);
        // If Devanagari captured more text or contains Hindi characters
        if (devaText.text.trim().isNotEmpty && _containsDevanagari(devaText.text)) {
          extractedText = devaText.text;
          hasDevanagari = true;
        }
      } catch (e) {
        debugPrint("Devanagari OCR pass error (non-fatal): $e");
      } finally {
        await devanagariRecognizer.close();
      }
    }

    final cleanedText = extractedText.trim();
    final lines = cleanedText.isEmpty ? <String>[] : cleanedText.split('\n');
    final words = cleanedText.isEmpty ? <String>[] : cleanedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    return OcrResult(
      fullText: cleanedText,
      lines: lines,
      wordCount: words.length,
      charCount: cleanedText.length,
      isDevanagari: hasDevanagari || _containsDevanagari(cleanedText),
      imagePath: filePath,
    );
  }

  /// Helper to test for Devanagari unicode range (0x0900 - 0x097F)
  bool _containsDevanagari(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0900 && code <= 0x097F) {
        return true;
      }
    }
    return false;
  }

  /// Export recognized OCR text into a new Word (.docx) document
  Future<String> exportToDocx(String text, String baseName) async {
    final docsDir = await _getStorageDir();
    final sanitizedName = baseName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
    final filePath = "${docsDir.path}/$sanitizedName.docx";
    final file = File(filePath);

    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, contentTypesXml.codeUnits));

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, rootRelsXml.codeUnits));

    // 3. word/document.xml
    final docBuffer = StringBuffer();
    docBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    docBuffer.writeln('  <w:body>');

    final paragraphs = text.split('\n');
    for (final p in paragraphs) {
      final safeText = p
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      docBuffer.writeln('    <w:p><w:r><w:t>$safeText</w:t></w:r></w:p>');
    }

    docBuffer.writeln('  </w:body>');
    docBuffer.writeln('</w:document>');

    final docXmlStr = docBuffer.toString();
    archive.addFile(ArchiveFile('word/document.xml', docXmlStr.length, docXmlStr.codeUnits));

    // Encode zip
    final encoded = ZipEncoder().encode(archive);
    if (encoded != null) {
      await file.writeAsBytes(encoded);
    }
    return filePath;
  }

  /// Save recognized OCR text into a plain text (.txt) file
  Future<String> exportToTxt(String text, String baseName) async {
    final docsDir = await _getStorageDir();
    final sanitizedName = baseName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
    final filePath = "${docsDir.path}/$sanitizedName.txt";
    final file = File(filePath);
    await file.writeAsString(text);
    return filePath;
  }
}
