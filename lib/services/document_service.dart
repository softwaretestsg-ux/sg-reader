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

  /// Picks a document reliably across all Android versions (Android 9 to 15)
  /// Copies the file to the app's safe internal documents directory to bypass Scoped Storage file locks.
  Future<DocumentFile?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true, // Guarantees in-memory byte access from Android ContentProviders
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.single;
      final fileName = pickedFile.name;
      final docType = DocumentFile.detectType(fileName);

      // Persist the file into the app's private application documents directory
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

      // Check if file is on disk and has readable length
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

  /// Saves a document to local recent history
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

  /// Retrieves list of recently opened files
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

  /// Robust DOCX Parser: Extracts paragraphs, headings, and table cells (100% offline)
  Future<List<String>> parseDocxParagraphs(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentXmlFile = archive.findFile('word/document.xml');
      if (documentXmlFile == null) return ["Unable to locate document content."];

      final xmlContent = utf8.decode(documentXmlFile.content as List<int>);
      final document = XmlDocument.parse(xmlContent);

      List<String> textBlocks = [];

      // Extract all paragraphs
      final paragraphs = document.findAllElements('w:p');
      for (var p in paragraphs) {
        final textNodes = p.findAllElements('w:t');
        final text = textNodes.map((n) => n.text).join('').trim();
        if (text.isNotEmpty) {
          textBlocks.add(text);
        }
      }

      // Also extract any table content
      final tables = document.findAllElements('w:tbl');
      for (var tbl in tables) {
        final rows = tbl.findAllElements('w:tr');
        for (var r in rows) {
          final cells = r.findAllElements('w:tc');
          final rowTexts = cells
              .map((c) => c.findAllElements('w:t').map((n) => n.text).join(' ').trim())
              .where((t) => t.isNotEmpty)
              .join('  |  ');
          if (rowTexts.isNotEmpty) {
            textBlocks.add("[Table Row] $rowTexts");
          }
        }
      }

      return textBlocks.isEmpty ? ["Document has no readable text content."] : textBlocks;
    } catch (e) {
      return ["Error reading DOCX file: $e"];
    }
  }

  /// Robust PPTX Slide Text Extractor (100% offline)
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

  /// Reads Excel spreadsheet data (100% offline)
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

  /// Saves updated Excel cell to disk
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
}
