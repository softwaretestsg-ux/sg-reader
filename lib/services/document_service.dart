import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel/excel.dart' as xls;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/document_file.dart';

class DocumentService {
  static const String _recentDocsKey = 'recent_documents_v1';

  /// Picks a document reliably across all Android versions
  Future<DocumentFile?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.single;
      final fileName = pickedFile.name;
      final docType = DocumentFile.detectType(fileName);

      String? originalPath = pickedFile.path;
      String activePath = pickedFile.path ?? '';

      final appDir = await getApplicationDocumentsDirectory();
      final localSafePath = '${appDir.path}/$fileName';
      final safeFile = File(localSafePath);

      if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
        await safeFile.writeAsBytes(pickedFile.bytes!, flush: true);
        activePath = safeFile.path;
      } else if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        final original = File(pickedFile.path!);
        if (await original.exists()) {
          try {
            await original.copy(localSafePath);
          } catch (_) {}
        }
      }

      if (activePath.isEmpty || !await File(activePath).exists()) {
        activePath = safeFile.path;
      }

      int length = 0;
      if (await File(activePath).exists()) {
        length = await File(activePath).length();
      } else {
        length = pickedFile.size;
      }

      final doc = DocumentFile(
        path: activePath,
        originalPath: originalPath,
        name: fileName,
        sizeInBytes: length,
        type: docType,
        lastOpened: DateTime.now(),
      );

      await saveRecentDocument(doc);
      return doc;
    } catch (e) {
      debugPrint("Error in pickDocument: $e");
      rethrow;
    }
  }

  /// Saves recent document entry
  Future<void> saveRecentDocument(DocumentFile doc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<DocumentFile> recents = await getRecentDocuments();

      recents.removeWhere((item) => item.path == doc.path || item.name == doc.name);
      recents.insert(0, doc);

      if (recents.length > 25) {
        recents = recents.sublist(0, 25);
      }

      final rawJsonList = recents.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_recentDocsKey, rawJsonList);
    } catch (e) {
      debugPrint("Error saving recent document: $e");
    }
  }

  /// Retrieves list of recent documents
  Future<List<DocumentFile>> getRecentDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_recentDocsKey) ?? [];

      List<DocumentFile> list = [];
      for (var raw in rawList) {
        try {
          final map = jsonDecode(raw);
          final file = File(map['path']);
          if (await file.exists()) {
            list.add(DocumentFile.fromJson(map));
          }
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Clears all recent documents history
  Future<void> clearRecentDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentDocsKey);
    } catch (e) {
      debugPrint("Error clearing recent documents: $e");
    }
  }

  /// Removes a single recent document entry from history by path
  Future<void> removeRecentDocument(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<DocumentFile> recents = await getRecentDocuments();
      recents.removeWhere((item) => item.path == filePath);

      final rawJsonList = recents.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_recentDocsKey, rawJsonList);
    } catch (e) {
      debugPrint("Error removing recent document: $e");
    }
  }

  /// Permanently deletes document from device storage.
  /// Deletes the primary file, original source path, internal cached copies,
  /// and invokes native Android ContentResolver/SAF deletion when URI is available.
  Future<bool> deleteDocumentPermanently(DocumentFile doc) async {
    bool deleted = false;

    // 1. Delete primary file path
    try {
      final f = File(doc.path);
      if (await f.exists()) {
        await f.delete();
        deleted = true;
      }
    } catch (e) {
      debugPrint("Could not delete primary file ${doc.path}: $e");
    }

    // 2. Delete original source path if different
    if (doc.originalPath != null && doc.originalPath != doc.path) {
      try {
        final orig = File(doc.originalPath!);
        if (await orig.exists()) {
          await orig.delete();
          deleted = true;
        }
      } catch (e) {
        debugPrint("Could not delete original file ${doc.originalPath}: $e");
      }
    }

    // 3. Delete any internal app document copy
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final internalCopy = File('${appDir.path}/${doc.name}');
      if (await internalCopy.exists() &&
          internalCopy.path != doc.path &&
          internalCopy.path != doc.originalPath) {
        await internalCopy.delete();
        deleted = true;
      }
    } catch (_) {}

    // 4. Request native Android ContentResolver / DocumentsContract deletion
    try {
      const channel = MethodChannel('com.socialgoogol.sgreader/open_file');
      final nativeResult = await channel.invokeMethod<bool>('deleteFilePermanently', {
        'path': doc.originalPath ?? doc.path,
        'uri': doc.uri,
      });
      if (nativeResult == true) {
        deleted = true;
      }
    } catch (e) {
      debugPrint("Native platform deletion channel: $e");
    }

    // 5. Remove from Recent Documents
    await removeRecentDocument(doc.path);
    if (doc.originalPath != null) {
      await removeRecentDocument(doc.originalPath!);
    }

    return deleted;
  }

  /// Permanently deletes a list of documents from device storage (Batch Deletion)
  Future<int> deleteMultipleDocumentsPermanently(List<DocumentFile> docs) async {
    int count = 0;
    for (final doc in docs) {
      final success = await deleteDocumentPermanently(doc);
      if (success) count++;
    }
    return count;
  }

  // ==========================================
  // 1. PDF OPERATIONS (READ / SAVE / EDIT / ANNOTATE)
  // ==========================================

  Future<void> savePdfBytes(String filePath, List<int> bytes) async {
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
  }

  /// Adds an annotation, note, or endorsement stamp to a PDF document and saves it
  Future<void> addPdfAnnotation(
    String filePath, {
    required int pageIndex,
    required String text,
    String position = 'top',
    String author = 'Social Googol Verified',
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    if (pageIndex >= 0 && pageIndex < document.pages.count) {
      final page = document.pages[pageIndex];
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
      final subFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
      final accentColor = PdfColor(176, 74, 36); // #B04A24 Terracotta
      final textColor = PdfColor(31, 25, 19);

      final double pageWidth = page.size.width;
      final double pageHeight = page.size.height;
      final double bannerWidth = (pageWidth - 60).clamp(100.0, 800.0);
      final double bannerHeight = 38;
      final double x = 30;
      final double y = position == 'top' ? 24 : (pageHeight - bannerHeight - 24);

      // Draw background container
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(254, 248, 243)),
        pen: PdfPen(accentColor, width: 1.5),
        bounds: Rect.fromLTWH(x, y, bannerWidth, bannerHeight),
      );

      // Draw note text
      page.graphics.drawString(
        text,
        font,
        brush: PdfSolidBrush(accentColor),
        bounds: Rect.fromLTWH(x + 10, y + 4, bannerWidth - 20, 16),
      );

      // Draw timestamp / endorsement subtitle
      final dateStr = DateTime.now().toLocal().toString().split('.')[0];
      page.graphics.drawString(
        "$author • $dateStr",
        subFont,
        brush: PdfSolidBrush(textColor),
        bounds: Rect.fromLTWH(x + 10, y + 20, bannerWidth - 20, 14),
      );
    }

    final updatedBytes = document.saveSync();
    document.dispose();
    await file.writeAsBytes(updatedBytes, flush: true);
  }

  /// Covers an unwanted watermark, footer stamp, or header on a PDF page with clean white paper
  Future<void> redactPdfWatermarkArea(
    String filePath, {
    required int pageIndex,
    required Rect bounds,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    if (pageIndex >= 0 && pageIndex < document.pages.count) {
      final page = document.pages[pageIndex];
      // Draw clean paper whiteout rectangle to cover watermark
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        bounds: bounds,
      );
    }

    final updatedBytes = document.saveSync();
    document.dispose();
    await file.writeAsBytes(updatedBytes, flush: true);
  }

  // ==========================================
  // 2. EXCEL OPERATIONS (READ / EDIT / SAVE)
  // ==========================================

  Future<Map<String, List<List<dynamic>>>> readExcel(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = xls.Excel.decodeBytes(bytes);

      Map<String, List<List<dynamic>>> sheetsData = {};

      for (var table in excel.tables.keys) {
        List<List<dynamic>> rows = [];
        for (var row in excel.tables[table]!.rows) {
          rows.add(row.map((cell) => cell?.value?.toString() ?? "").toList());
        }
        sheetsData[table] = rows;
      }

      return sheetsData;
    } catch (e) {
      debugPrint("Error reading Excel: $e");
      return {};
    }
  }

  Future<void> saveExcelCell(
    String filePath,
    String sheetName,
    int rowIndex,
    int colIndex,
    String newValue,
  ) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = xls.Excel.decodeBytes(bytes);

    final sheet = excel[sheetName];
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex)).value =
        xls.TextCellValue(newValue);

    final encoded = excel.encode();
    if (encoded != null) {
      await File(filePath).writeAsBytes(encoded, flush: true);
    }
  }

  Future<void> addExcelRow(String filePath, String sheetName, List<String> rowValues) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = xls.Excel.decodeBytes(bytes);

    final sheet = excel[sheetName];
    final currentRowsCount = sheet.maxRows;

    for (int col = 0; col < rowValues.length; col++) {
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRowsCount)).value =
          xls.TextCellValue(rowValues[col]);
    }

    final encoded = excel.encode();
    if (encoded != null) {
      await File(filePath).writeAsBytes(encoded, flush: true);
    }
  }

  // ==========================================
  // 3. WORD (DOCX) OPERATIONS (READ / EDIT / SAVE)
  // ==========================================

  Future<List<String>> parseDocxParagraphs(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentXmlFile = archive.findFile('word/document.xml');
      if (documentXmlFile == null) return ["Unable to locate document content."];

      final xmlContent = utf8.decode(documentXmlFile.content as List<int>);
      final document = XmlDocument.parse(xmlContent);

      List<String> textBlocks = [];
      final paragraphs = document.findAllElements('w:p');
      for (var p in paragraphs) {
        final textNodes = p.findAllElements('w:t');
        final text = textNodes.map((n) => n.text).join('').trim();
        if (text.isNotEmpty) {
          textBlocks.add(text);
        }
      }

      return textBlocks.isEmpty ? ["Document has no readable text content."] : textBlocks;
    } catch (e) {
      return ["Error reading DOCX file: $e"];
    }
  }

  /// Edits and saves DOCX paragraphs back to the ZIP archive
  Future<void> saveDocxParagraphs(String filePath, List<String> updatedParagraphs) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Build fresh word/document.xml with updated paragraphs
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.write('<w:body>');
    for (var para in updatedParagraphs) {
      buffer.write('<w:p><w:r><w:t>${_escapeXml(para)}</w:t></w:r></w:p>');
    }
    buffer.write('</w:body></w:document>');

    final newXmlBytes = utf8.encode(buffer.toString());

    // Create updated archive
    final updatedArchive = Archive();
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        updatedArchive.addFile(ArchiveFile('word/document.xml', newXmlBytes.length, newXmlBytes));
      } else {
        updatedArchive.addFile(file);
      }
    }

    final encodedZip = ZipEncoder().encode(updatedArchive);
    if (encodedZip != null) {
      await File(filePath).writeAsBytes(encodedZip, flush: true);
    }
  }

  // ==========================================
  // 4. POWERPOINT (PPTX) OPERATIONS (READ / EDIT / SAVE)
  // ==========================================

  Future<List<List<String>>> parsePptxSlides(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      List<List<String>> slides = [];

      int index = 1;
      while (true) {
        final slideFile = archive.findFile('ppt/slides/slide$index.xml');
        if (slideFile == null) break;

        final xmlContent = utf8.decode(slideFile.content as List<int>);
        final document = XmlDocument.parse(xmlContent);

        List<String> slideTexts = [];
        final textNodes = document.findAllElements('a:t');
        for (var t in textNodes) {
          final text = t.text.trim();
          if (text.isNotEmpty) {
            slideTexts.add(text);
          }
        }
        if (slideTexts.isNotEmpty) {
          slides.add(slideTexts);
        }
        index++;
      }

      return slides;
    } catch (e) {
      debugPrint("Error parsing PPTX: $e");
      return [];
    }
  }

  /// Updates and saves a PPTX slide back to the ZIP archive
  Future<void> savePptxSlide(String filePath, int slideIndex, List<String> updatedLines) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final slideName = 'ppt/slides/slide${slideIndex + 1}.xml';

    // Simple valid PPTX slide XML layout
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.write('<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
    buffer.write('<p:cSld><p:spTree>');
    buffer.write('<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>');
    for (int i = 0; i < updatedLines.length; i++) {
      buffer.write('<p:sp>');
      buffer.write('<p:nvSpPr><p:cNvPr id="${i + 2}" name="Text ${i + 1}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>');
      buffer.write('<p:spPr/>');
      buffer.write('<p:txBody><a:bodyPr/><a:p><a:r><a:t>${_escapeXml(updatedLines[i])}</a:t></a:r></a:p></p:txBody>');
      buffer.write('</p:sp>');
    }
    buffer.write('</p:spTree></p:cSld></p:sld>');

    final newXmlBytes = utf8.encode(buffer.toString());

    final updatedArchive = Archive();
    for (final file in archive) {
      if (file.name == slideName) {
        updatedArchive.addFile(ArchiveFile(slideName, newXmlBytes.length, newXmlBytes));
      } else {
        updatedArchive.addFile(file);
      }
    }

    final encodedZip = ZipEncoder().encode(updatedArchive);
    if (encodedZip != null) {
      await File(filePath).writeAsBytes(encodedZip, flush: true);
    }
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
