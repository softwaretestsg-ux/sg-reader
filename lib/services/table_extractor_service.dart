import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/document_file.dart';

class _TableElement {
  final String text;
  final Rect rect;

  _TableElement({required this.text, required this.rect});
}

/// 100% On-Device Photo-to-Spreadsheet Table Extractor
/// Converts paper tables, invoices, price lists, and schedules into editable Microsoft Excel (.xlsx) files.
class TableExtractorService {
  /// Extract a structured table from an image file and save as an Excel (.xlsx) document
  Future<DocumentFile> extractTableToExcel(String imagePath, {String? customSheetName}) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception("Target image does not exist.");
    }

    // 1. Run ML Kit Text Recognition with error shielding
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    RecognizedText recognizedText;
    try {
      recognizedText = await recognizer.processImage(inputImage);
    } finally {
      await recognizer.close();
    }

    if (recognizedText.blocks.isEmpty) {
      throw Exception("No text or table cells detected in the captured image.");
    }

    // 2. Collect all recognized text elements with bounding boxes
    final List<_TableElement> elements = [];
    double totalHeight = 0;
    int elementCount = 0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        if (line.text.trim().isEmpty) continue;
        elements.add(_TableElement(text: line.text.trim(), rect: line.boundingBox));
        totalHeight += line.boundingBox.height;
        elementCount++;
      }
    }

    if (elements.isEmpty) {
      throw Exception("No readable text lines found in document.");
    }

    final double avgLineHeight = elementCount > 0 ? (totalHeight / elementCount) : 24.0;
    final double rowThreshold = avgLineHeight * 0.7;

    // 3. Cluster into rows based on vertical (Y) coordinates
    elements.sort((a, b) => a.rect.top.compareTo(b.rect.top));

    final List<List<_TableElement>> rows = [];
    List<_TableElement> currentRow = [];
    double currentRowY = -1;

    for (final el in elements) {
      if (currentRow.isEmpty) {
        currentRow.add(el);
        currentRowY = el.rect.top;
      } else {
        if ((el.rect.top - currentRowY).abs() <= rowThreshold) {
          currentRow.add(el);
        } else {
          // Sort previous row horizontally from left to right
          currentRow.sort((a, b) => a.rect.left.compareTo(b.rect.left));
          rows.add(List.from(currentRow));
          currentRow = [el];
          currentRowY = el.rect.top;
        }
      }
    }
    if (currentRow.isNotEmpty) {
      currentRow.sort((a, b) => a.rect.left.compareTo(b.rect.left));
      rows.add(currentRow);
    }

    // 4. Determine column grid alignments across rows
    // Find all distinct column X anchors
    final List<double> columnAnchors = [];
    final double colThreshold = avgLineHeight * 1.5;

    for (final row in rows) {
      for (final cell in row) {
        final cellLeft = cell.rect.left;
        bool matched = false;
        for (int i = 0; i < columnAnchors.length; i++) {
          if ((columnAnchors[i] - cellLeft).abs() <= colThreshold) {
            columnAnchors[i] = (columnAnchors[i] + cellLeft) / 2; // update average
            matched = true;
            break;
          }
        }
        if (!matched) {
          columnAnchors.add(cellLeft);
        }
      }
    }
    columnAnchors.sort();

    // 5. Build 2D matrix
    final List<List<String>> tableMatrix = [];
    for (final row in rows) {
      final List<String> rowCells = List.filled(columnAnchors.length, "");
      for (final cell in row) {
        // Find best matching column index
        int bestCol = 0;
        double minDiff = double.infinity;
        for (int i = 0; i < columnAnchors.length; i++) {
          final diff = (columnAnchors[i] - cell.rect.left).abs();
          if (diff < minDiff) {
            minDiff = diff;
            bestCol = i;
          }
        }
        if (rowCells[bestCol].isNotEmpty) {
          rowCells[bestCol] += " ${cell.text}";
        } else {
          rowCells[bestCol] = cell.text;
        }
      }
      tableMatrix.add(rowCells);
    }

    // 6. Generate Microsoft Excel (.xlsx) file
    final excel = xls.Excel.createExcel();
    final sheetName = customSheetName ?? "Extracted_Table";
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];

    for (int r = 0; r < tableMatrix.length; r++) {
      final rowData = tableMatrix[r];
      for (int c = 0; c < rowData.length; c++) {
        final cellValue = rowData[c].trim();
        if (cellValue.isEmpty) continue;

        final cellIndex = xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r);
        // Try parsing number
        final numVal = num.tryParse(cellValue.replaceAll(',', ''));
        if (numVal != null && !cellValue.startsWith('0')) {
          sheet.cell(cellIndex).value = xls.DoubleCellValue(numVal.toDouble());
        } else {
          sheet.cell(cellIndex).value = xls.TextCellValue(cellValue);
        }
      }
    }

    final excelBytes = excel.encode();
    if (excelBytes == null) {
      throw Exception("Failed to encode spreadsheet workbook.");
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'Table_Extracted_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final savedPath = '${appDir.path}/$fileName';

    final outputFile = File(savedPath);
    await outputFile.writeAsBytes(excelBytes, flush: true);

    return DocumentFile(
      path: savedPath,
      name: fileName,
      sizeInBytes: await outputFile.length(),
      type: DocumentType.excel,
      lastOpened: DateTime.now(),
    );
  }
}
