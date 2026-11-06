import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel/excel.dart' as xls;
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

      final appDir = await getApplicationDocumentsDirectory();
      final localSafePath = '${appDir.path}/$fileName';
      final safeFile = File(localSafePath);

      if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
        await safeFile.writeAsBytes(pickedFile.bytes!, flush: true);
      } else if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        final original = File(pickedFile.path!);
        if (await original.exists()) {
          await original.copy(localSafePath);
        }
      }

      int length = 0;
      if (await safeFile.exists()) {
        length = await safeFile.length();
      } else {
        length = pickedFile.size;
      }

      final doc = DocumentFile(
        path: safeFile.path,
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

  // ==========================================
  // 1. PDF OPERATIONS (READ / SAVE)
  // ==========================================

  Future<void> savePdfBytes(String filePath, List<int> bytes) async {
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
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
