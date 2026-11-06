import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:sg_reader/services/document_service.dart';

void main() {
  late Directory tempDir;
  late DocumentService docService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sg_test_');
    docService = DocumentService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Document Read, Edit, Save & Share Tests (All Formats)', () {
    // -------------------------------------------------------------
    // 1. EXCEL TEST (READ, EDIT, SAVE, VERIFY)
    // -------------------------------------------------------------
    test('Excel (.xlsx): Read -> Edit Cell -> Save -> Verify Proof', () async {
      final excelFile = File('${tempDir.path}/test_sheet.xlsx');

      // Create initial excel
      final initialExcel = xls.Excel.createExcel();
      final sheet = initialExcel['Sheet1'];
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          xls.TextCellValue("Initial Value");
      await excelFile.writeAsBytes(initialExcel.encode()!);

      expect(excelFile.existsSync(), true);

      // 1. READ
      final readData = await docService.readExcel(excelFile.path);
      expect(readData.containsKey('Sheet1'), true);
      expect(readData['Sheet1']![0][0], "Initial Value");

      // 2. EDIT & 3. SAVE
      const updatedValue = "Social Googol Growth Verified";
      await docService.saveExcelCell(excelFile.path, 'Sheet1', 0, 0, updatedValue);

      // 4. VERIFY PROOF (Fresh read from disk)
      final reloadedData = await docService.readExcel(excelFile.path);
      expect(reloadedData['Sheet1']![0][0], updatedValue);
    });

    // -------------------------------------------------------------
    // 2. WORD DOCX TEST (READ, EDIT, SAVE, VERIFY)
    // -------------------------------------------------------------
    test('Word (.docx): Read -> Edit Paragraph -> Save -> Verify Proof', () async {
      final docxFile = File('${tempDir.path}/test_doc.docx');

      // Create initial DOCX zip archive with word/document.xml
      final initialArchive = Archive();
      final initialXml = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body><w:p><w:r><w:t>Original Paragraph 1</w:t></w:r></w:p></w:body>'
        '</w:document>',
      );
      initialArchive.addFile(ArchiveFile('word/document.xml', initialXml.length, initialXml));
      await docxFile.writeAsBytes(ZipEncoder().encode(initialArchive)!);

      // 1. READ
      final paragraphs = await docService.parseDocxParagraphs(docxFile.path);
      expect(paragraphs.length, 1);
      expect(paragraphs[0], "Original Paragraph 1");

      // 2. EDIT & 3. SAVE
      const updatedPara = "Social Googol SG Reader - Document Edited & Verified";
      await docService.saveDocxParagraphs(docxFile.path, [updatedPara, "Added Second Paragraph"]);

      // 4. VERIFY PROOF (Fresh read from disk)
      final reloadedParagraphs = await docService.parseDocxParagraphs(docxFile.path);
      expect(reloadedParagraphs.length, 2);
      expect(reloadedParagraphs[0], updatedPara);
      expect(reloadedParagraphs[1], "Added Second Paragraph");
    });

    // -------------------------------------------------------------
    // 3. POWERPOINT PPTX TEST (READ, EDIT, SAVE, VERIFY)
    // -------------------------------------------------------------
    test('PowerPoint (.pptx): Read -> Edit Slide -> Save -> Verify Proof', () async {
      final pptxFile = File('${tempDir.path}/test_pres.pptx');

      // Create initial PPTX zip archive with ppt/slides/slide1.xml
      final initialArchive = Archive();
      final initialXml = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>Original Slide Title</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld>'
        '</p:sld>',
      );
      initialArchive.addFile(ArchiveFile('ppt/slides/slide1.xml', initialXml.length, initialXml));
      await pptxFile.writeAsBytes(ZipEncoder().encode(initialArchive)!);

      // 1. READ
      final slides = await docService.parsePptxSlides(pptxFile.path);
      expect(slides.length, 1);
      expect(slides[0][0], "Original Slide Title");

      // 2. EDIT & 3. SAVE
      const updatedLine = "Secure to Grow - सुरक्षा से ग्रोथ तक Presentation";
      await docService.savePptxSlide(pptxFile.path, 0, [updatedLine, "Key Growth Metrics"]);

      // 4. VERIFY PROOF (Fresh read from disk)
      final reloadedSlides = await docService.parsePptxSlides(pptxFile.path);
      expect(reloadedSlides.length, 1);
      expect(reloadedSlides[0][0], updatedLine);
      expect(reloadedSlides[0][1], "Key Growth Metrics");
    });

    // -------------------------------------------------------------
    // 4. PDF EDIT & ANNOTATION TEST (READ, EDIT, SAVE, VERIFY)
    // -------------------------------------------------------------
    test('PDF: Create -> Add Annotation Note -> Save -> Verify Proof', () async {
      final pdfFile = File('${tempDir.path}/test_pdf_edit.pdf');
      final document = PdfDocument();
      document.pages.add().graphics.drawString(
        "Initial PDF Page",
        PdfStandardFont(PdfFontFamily.helvetica, 12),
      );
      final initialBytes = document.saveSync();
      document.dispose();
      await pdfFile.writeAsBytes(initialBytes);

      expect(pdfFile.existsSync(), true);

      // 1. ADD ANNOTATION & SAVE
      const noteText = "Social Googol Endorsement Verified";
      await docService.addPdfAnnotation(
        pdfFile.path,
        pageIndex: 0,
        text: noteText,
        position: 'top',
      );

      // 2. VERIFY PROOF (Fresh read from disk)
      final reloadedBytes = await pdfFile.readAsBytes();
      final reloadedDoc = PdfDocument(inputBytes: reloadedBytes);
      expect(reloadedDoc.pages.count, 1);
      reloadedDoc.dispose();
      expect(reloadedBytes.length > initialBytes.length, true);
    });

    // -------------------------------------------------------------
    // 5. PDF & SHARE INTEGRITY TEST
    // -------------------------------------------------------------
    test('PDF & Share: File creation, byte integrity, and share readiness', () async {
      final pdfFile = File('${tempDir.path}/test_doc.pdf');
      final pdfBytes = utf8.encode("%PDF-1.4 Mock PDF Document with Social Googol Verified Content");
      await docService.savePdfBytes(pdfFile.path, pdfBytes);

      // 1. Verify existence & byte integrity
      expect(pdfFile.existsSync(), true);
      final readBytes = await pdfFile.readAsBytes();
      expect(readBytes.length, pdfBytes.length);

      // 2. Verify file is ready for sharing
      expect(pdfFile.path.endsWith('.pdf'), true);
      expect(await pdfFile.length() > 0, true);
    });
  });
}
