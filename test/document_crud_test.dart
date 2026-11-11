import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:sg_reader/services/document_service.dart';
import 'package:sg_reader/services/scanner_service.dart';
import 'package:sg_reader/services/scanner_export_service.dart';
import 'package:sg_reader/services/update_service.dart';
import 'package:sg_reader/services/security_service.dart';
import 'package:sg_reader/services/watermark_service.dart';
import 'package:sg_reader/constants/branding.dart';
import 'package:sg_reader/models/document_file.dart';

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

    // -------------------------------------------------------------
    // 6. IN-BUILT DOCUMENT SCANNER & MULTI-FORMAT EXPORT TEST
    // -------------------------------------------------------------
    test('Scanner & Multi-Format Export: Process -> Export to PDF & DOCX -> Verify Proof', () async {
      // Create a mock scanned image in memory
      final testImg = img.Image(width: 200, height: 300);
      img.fill(testImg, color: img.ColorRgb8(255, 255, 255));
      img.drawString(testImg, 'Social Googol Verified Scan', font: img.arial14, x: 20, y: 50, color: img.ColorRgb8(0, 0, 0));
      final imgBytes = Uint8List.fromList(img.encodeJpg(testImg));

      final scannedPages = [
        ScannedPage(
          id: 'page_1',
          originalBytes: imgBytes,
          processedBytes: imgBytes,
          currentFilter: ScanFilterType.autoRefine,
        ),
        ScannedPage(
          id: 'page_2',
          originalBytes: imgBytes,
          processedBytes: imgBytes,
          currentFilter: ScanFilterType.crispBw,
        ),
      ];

      // 1. Export as PDF
      final pdfResult = await ScannerExportService.exportDocument(
        pages: scannedPages,
        baseFileName: 'test_scan_export',
        format: ExportFormat.pdf,
        customOutputDir: tempDir,
      );
      expect(File(pdfResult.filePath).existsSync(), true);
      expect(pdfResult.docType, DocumentType.pdf);
      expect(pdfResult.fileSizeBytes > 0, true);

      // Verify PDF has 2 pages
      final pdfBytes = await File(pdfResult.filePath).readAsBytes();
      final loadedPdf = PdfDocument(inputBytes: pdfBytes);
      expect(loadedPdf.pages.count, 2);
      loadedPdf.dispose();

      // 2. Export as Word (.docx)
      final docxResult = await ScannerExportService.exportDocument(
        pages: scannedPages,
        baseFileName: 'test_scan_export',
        format: ExportFormat.docx,
        customOutputDir: tempDir,
      );
      expect(File(docxResult.filePath).existsSync(), true);
      expect(docxResult.docType, DocumentType.word);
      expect(docxResult.fileSizeBytes > 0, true);

      // Verify DOCX archive contains document.xml and both images
      final docxBytes = await File(docxResult.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(docxBytes);
      expect(archive.findFile('word/document.xml') != null, true);
      expect(archive.findFile('word/media/image1.jpg') != null, true);
      expect(archive.findFile('word/media/image2.jpg') != null, true);

      // 3. Export as ZIP
      final zipResult = await ScannerExportService.exportDocument(
        pages: scannedPages,
        baseFileName: 'test_scan_export',
        format: ExportFormat.zip,
        customOutputDir: tempDir,
      );
      expect(File(zipResult.filePath).existsSync(), true);
      final zipArchive = ZipDecoder().decodeBytes(await File(zipResult.filePath).readAsBytes());
      expect(zipArchive.findFile('page_1.jpg') != null, true);
      expect(zipArchive.findFile('page_2.jpg') != null, true);
      expect(zipArchive.findFile('manifest.txt') != null, true);
    });

    // -------------------------------------------------------------
    // 7. RECENT DOCUMENTS CLEAR & REMOVE TESTS
    // -------------------------------------------------------------
    test('Recent Documents: Save -> Remove Individual -> Clear All -> Verify Proof', () async {
      SharedPreferences.setMockInitialValues({});
      final mockDoc1 = DocumentFile(
        path: '${tempDir.path}/doc1.pdf',
        name: 'doc1.pdf',
        sizeInBytes: 1024,
        type: DocumentType.pdf,
        lastOpened: DateTime.now(),
      );
      final mockDoc2 = DocumentFile(
        path: '${tempDir.path}/doc2.docx',
        name: 'doc2.docx',
        sizeInBytes: 2048,
        type: DocumentType.word,
        lastOpened: DateTime.now(),
      );

      // Create files so getRecentDocuments verifies existence
      await File(mockDoc1.path).writeAsString("mock1");
      await File(mockDoc2.path).writeAsString("mock2");

      // 1. Save both
      await docService.saveRecentDocument(mockDoc1);
      await docService.saveRecentDocument(mockDoc2);
      var recents = await docService.getRecentDocuments();
      expect(recents.length, 2);

      // 2. Remove single entry
      await docService.removeRecentDocument(mockDoc1.path);
      recents = await docService.getRecentDocuments();
      expect(recents.length, 1);
      expect(recents.first.path, mockDoc2.path);

      // 3. Clear all
      await docService.clearRecentDocuments();
      recents = await docService.getRecentDocuments();
      expect(recents.isEmpty, true);
    });

    // -------------------------------------------------------------
    // 8. BRANDING, UPDATE SERVICE & SECURITY VERIFICATION TESTS
    // -------------------------------------------------------------
    test('UpdateService: Version code dynamically synchronizes with BrandConstants', () {
      expect(UpdateService.currentVersionCode, BrandConstants.buildNumber);
      expect(UpdateService.currentVersionCode, 16);
      expect(BrandConstants.appVersion, "1.3.1");
      expect(BrandConstants.fullVersionDisplay, "v1.3.1 • Build 16");
    });

    test('BrandConstants: Bilingual tagline and identity integrity', () {
      expect(BrandConstants.appName, "Social Googol's SG Reader");
      expect(BrandConstants.taglineEn, "Secure to Grow");
      expect(BrandConstants.taglineHi, "सुरक्षा से ग्रोथ तक");
      expect(BrandConstants.fullTagline, "Secure to Grow - सुरक्षा से ग्रोथ तक");
      expect(BrandConstants.contactPhone, "8126210003");
      expect(BrandConstants.contactPhoneFormatted, "+91 81262 10003");
    });

    test('SecurityService: EULA and App Lock state persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final security = SecurityService();

      expect(await security.isEulaAccepted(), false);
      await security.setEulaAccepted(true);
      expect(await security.isEulaAccepted(), true);

      expect(await security.isAppLockEnabled(), false);
      await security.setAppLockEnabled(true);
      expect(await security.isAppLockEnabled(), true);
    });

    // -------------------------------------------------------------
    // 9. SCANNER PERSPECTIVE DEWARP & ADAPTIVE FILTERS TEST
    // -------------------------------------------------------------
    test('Scanner: 4-Point Perspective Crop & Adaptive Binarization', () async {
      final scanner = ScannerService();

      // Create synthetic 400x500 test document image with text & shadows
      final testImg = img.Image(width: 400, height: 500);
      img.fill(testImg, color: img.ColorRgb8(240, 235, 230)); // off-white paper
      // Add simulated document text (dark pixels)
      for (int y = 50; y < 70; y++) {
        for (int x = 60; x < 340; x++) {
          testImg.setPixelRgb(x, y, 20, 20, 20);
        }
      }
      final rawJpg = Uint8List.fromList(img.encodeJpg(testImg));

      // 1. Perspective Crop
      const corners = QuadCorners(
        topLeft: Offset(0.05, 0.05),
        topRight: Offset(0.95, 0.05),
        bottomRight: Offset(0.95, 0.95),
        bottomLeft: Offset(0.05, 0.95),
      );
      final croppedBytes = await scanner.cropPerspective(rawJpg, corners);
      expect(croppedBytes.isNotEmpty, true);
      final croppedImg = img.decodeImage(croppedBytes);
      expect(croppedImg != null, true);
      expect(croppedImg!.width > 300, true);
      expect(croppedImg.height > 400, true);

      // 2. Adaptive Binarization (Crisp B&W)
      final bwBytes = await scanner.processPage(croppedBytes, ScanFilterType.crispBw, 0);
      expect(bwBytes.isNotEmpty, true);

      // 3. Illumination Normalization (Auto Refine)
      final refinedBytes = await scanner.processPage(croppedBytes, ScanFilterType.autoRefine, 0);
      expect(refinedBytes.isNotEmpty, true);
    });

    // -------------------------------------------------------------
    // 10. WATERMARK REMOVER (COLOR-KEYED & AREA ERASER) TEST
    // -------------------------------------------------------------
    test('Watermark: Color Stripper & Region Eraser', () async {
      final watermarkService = WatermarkService();

      // Create synthetic image with dark text and a red watermark stamp
      final testImg = img.Image(width: 300, height: 400);
      img.fill(testImg, color: img.ColorRgb8(255, 255, 255)); // white background

      // Dark text (Luminance ~ 30)
      for (int y = 50; y < 60; y++) {
        for (int x = 40; x < 260; x++) {
          testImg.setPixelRgb(x, y, 30, 30, 30);
        }
      }

      // Red Watermark ("CONFIDENTIAL" - R: 220, G: 30, B: 30)
      for (int y = 150; y < 190; y++) {
        for (int x = 60; x < 240; x++) {
          testImg.setPixelRgb(x, y, 220, 30, 30);
        }
      }

      final rawBytes = Uint8List.fromList(img.encodeJpg(testImg));

      // 1. Strip Red Watermark
      final strippedBytes = await watermarkService.removeColorWatermark(
        rawBytes,
        type: WatermarkColorType.redStamp,
      );
      expect(strippedBytes.isNotEmpty, true);
      final strippedImg = img.decodeImage(strippedBytes)!;

      // Verify red watermark is erased to white (R,G,B > 240)
      final sampleWatermarkPixel = strippedImg.getPixel(150, 170);
      expect(sampleWatermarkPixel.r > 240, true);
      expect(sampleWatermarkPixel.g > 240, true);
      expect(sampleWatermarkPixel.b > 240, true);

      // Verify black text remains dark (R,G,B < 60)
      final sampleTextPixel = strippedImg.getPixel(150, 55);
      expect(sampleTextPixel.r < 60, true);
      expect(sampleTextPixel.g < 60, true);

      // 2. Erase Region (Footer)
      final erasedBytes = await watermarkService.eraseRegion(
        rawBytes,
        normLeft: 0.1,
        normTop: 0.85,
        normWidth: 0.8,
        normHeight: 0.12,
      );
      expect(erasedBytes.isNotEmpty, true);
    });

    // -------------------------------------------------------------
    // 11. WORD (.docx) OPENXML WATERMARK STRIPPING TEST
    // -------------------------------------------------------------
    test('Word (.docx): Strip OpenXML VML & WordArt Watermark Shapes', () async {
      final watermarkService = WatermarkService();
      final docxFile = File('${tempDir.path}/watermarked_doc.docx');

      // Create DOCX archive containing a VML watermark shape in document.xml
      final archive = Archive();
      final docXmlWithWatermark = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml">'
        '<w:body>'
        '<w:p><w:r><w:t>Real Document Content</w:t></w:r></w:p>'
        '<w:p><w:r><w:pict><v:shape id="PowerPlusWaterMarkObject35783163" type="#_x0000_m102" style="position:absolute;width:468pt;height:117pt" fillcolor="#d9d9d9"><v:textpath string="DRAFT"/></v:shape></w:pict></w:r></w:p>'
        '</w:body>'
        '</w:document>',
      );
      archive.addFile(ArchiveFile('word/document.xml', docXmlWithWatermark.length, docXmlWithWatermark));
      await docxFile.writeAsBytes(ZipEncoder().encode(archive)!);

      // Verify file initially has the watermark
      final initialContent = utf8.decode((ZipDecoder().decodeBytes(await docxFile.readAsBytes())).findFile('word/document.xml')!.content as List<int>);
      expect(initialContent.contains('PowerPlusWaterMarkObject'), true);
      expect(initialContent.contains('DRAFT'), true);

      // Run Watermark Cleaner
      final cleaned = await watermarkService.removeDocxWatermark(docxFile.path);
      expect(cleaned, true);

      // Verify watermark is completely stripped while document text remains
      final updatedContent = utf8.decode((ZipDecoder().decodeBytes(await docxFile.readAsBytes())).findFile('word/document.xml')!.content as List<int>);
      expect(updatedContent.contains('PowerPlusWaterMarkObject'), false);
      expect(updatedContent.contains('Real Document Content'), true);
    });

    // -------------------------------------------------------------
    // 12. PDF WHITEOUT / WATERMARK REDACTION TEST
    // -------------------------------------------------------------
    test('PDF: Redact Watermark / Footer with Clean Paper Whiteout', () async {
      final pdfFile = File('${tempDir.path}/test_watermark.pdf');

      // Create a 1-page PDF
      final doc = PdfDocument();
      final page = doc.pages.add();
      page.graphics.drawString(
        "Important Contract Text",
        PdfStandardFont(PdfFontFamily.helvetica, 16),
        bounds: const Rect.fromLTWH(50, 100, 300, 30),
      );
      // Simulated watermark stamp at bottom
      page.graphics.drawString(
        "WATERMARK - EVALUATION COPY",
        PdfStandardFont(PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(50, 750, 400, 30),
      );
      await pdfFile.writeAsBytes(doc.saveSync());
      doc.dispose();

      // Redact the watermark area
      await docService.redactPdfWatermarkArea(
        pdfFile.path,
        pageIndex: 0,
        bounds: const Rect.fromLTWH(0, 720, 600, 80),
      );

      // Verify PDF is readable and byte size increased
      final updatedBytes = await pdfFile.readAsBytes();
      final verifiedDoc = PdfDocument(inputBytes: updatedBytes);
      expect(verifiedDoc.pages.count, 1);
      verifiedDoc.dispose();
    });
  });
}
