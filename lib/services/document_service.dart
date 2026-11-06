import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel/excel.dart' as xls;
import '../models/document_file.dart';

class DocumentService {
  static const String _recentDocsKey = 'recent_documents_v1';

  /// Picks a document using Android's native Scoped Storage picker (no invasive permissions needed)
  Future<DocumentFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'docx', 'doc', 'pptx', 'ppt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final doc = DocumentFile(
        path: file.path,
        name: result.files.single.name,
        sizeInBytes: await file.length(),
        type: DocumentFile.detectType(file.path),
        lastOpened: DateTime.now(),
      );

      await saveRecentDocument(doc);
      return doc;
    }
    return null;
  }

  /// Saves a document to local recent history
  Future<void> saveRecentDocument(DocumentFile doc) async {
    final prefs = await SharedPreferences.getInstance();
    List<DocumentFile> recents = await getRecentDocuments();

    // Remove duplicates if already exists
    recents.removeWhere((item) => item.path == doc.path);
    recents.insert(0, doc);

    // Keep top 20
    if (recents.length > 20) {
      recents = recents.sublist(0, 20);
    }

    final rawJsonList = recents.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_recentDocsKey, rawJsonList);
  }

  /// Retrieves list of recently opened files
  Future<List<DocumentFile>> getRecentDocuments() async {
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
  }

  /// Lightweight DOCX Text & Paragraph Extractor (zero cloud, offline)
  Future<List<String>> parseDocxParagraphs(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final documentXmlFile = archive.findFile('word/document.xml');
    if (documentXmlFile == null) return ["Unable to parse document format."];

    final xmlContent = utf8.decode(documentXmlFile.content as List<int>);
    final document = XmlDocument.parse(xmlContent);

    List<String> paragraphs = [];
    final pElements = document.findAllElements('w:p');

    for (var p in pElements) {
      final textNodes = p.findAllElements('w:t');
      final text = textNodes.map((n) => n.text).join('').trim();
      if (text.isNotEmpty) {
        paragraphs.add(text);
      }
    }

    return paragraphs.isEmpty ? ["Document has no readable text paragraphs."] : paragraphs;
  }

  /// Lightweight PPTX Slide Text Extractor (zero cloud, offline)
  Future<List<List<String>>> parsePptxSlides(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    List<List<String>> slides = [];

    // Slides are stored as ppt/slides/slide1.xml, slide2.xml...
    int index = 1;
    while (true) {
      final slideFile = archive.findFile('ppt/slides/slide$index.xml');
      if (slideFile == null) break;

      final xmlContent = utf8.decode(slideFile.content as List<int>);
      final document = XmlDocument.parse(xmlContent);

      List<String> slideTexts = [];
      final textNodes = document.findAllElements('a:t');
      for (var t in textNodes) {
        if (t.text.trim().isNotEmpty) {
          slideTexts.add(t.text.trim());
        }
      }
      slides.add(slideTexts);
      index++;
    }

    return slides;
  }

  /// Reads Excel spreadsheet data
  Future<Map<String, List<List<dynamic>>>> readExcel(String filePath) async {
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
  }

  /// Saves updated Excel sheet back to local file
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
      await File(filePath).writeAsBytes(encoded);
    }
  }
}
