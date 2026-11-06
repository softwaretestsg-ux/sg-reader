import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/document_file.dart';
import 'scanner_service.dart';

enum ExportFormat {
  pdf,
  docx,
  jpg,
  zip,
  txt,
}

class ExportResult {
  final String filePath;
  final String fileName;
  final DocumentType docType;
  final int fileSizeBytes;

  ExportResult({
    required this.filePath,
    required this.fileName,
    required this.docType,
    required this.fileSizeBytes,
  });
}

class ScannerExportService {
  /// Export multiple scanned pages into the requested format
  static Future<ExportResult> exportDocument({
    required List<ScannedPage> pages,
    required String baseFileName,
    required ExportFormat format,
  }) async {
    final sanitizedName = baseFileName.trim().replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory('${appDir.path}/scanned_documents');
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }

    switch (format) {
      case ExportFormat.pdf:
        return _exportAsPdf(pages, sanitizedName, docsDir);
      case ExportFormat.docx:
        return _exportAsDocx(pages, sanitizedName, docsDir);
      case ExportFormat.jpg:
        return _exportAsImages(pages, sanitizedName, docsDir);
      case ExportFormat.zip:
        return _exportAsZip(pages, sanitizedName, docsDir);
      case ExportFormat.txt:
        return _exportAsTxt(pages, sanitizedName, docsDir);
    }
  }

  /// 1. Export as Standard Multi-Page PDF Document
  static Future<ExportResult> _exportAsPdf(
    List<ScannedPage> pages,
    String name,
    Directory dir,
  ) async {
    final pdfDocument = PdfDocument();
    pdfDocument.pageSettings.margins.all = 0; // Edge to edge document scan

    for (final page in pages) {
      final pdfPage = pdfDocument.pages.add();
      final PdfBitmap bitmap = PdfBitmap(page.processedBytes);
      final double pageWidth = pdfPage.getClientSize().width;
      final double pageHeight = pdfPage.getClientSize().height;

      // Draw image fitted to page
      pdfPage.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, pageWidth, pageHeight),
      );
    }

    final List<int> bytes = pdfDocument.saveSync();
    pdfDocument.dispose();

    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(
      filePath: file.path,
      fileName: '$name.pdf',
      docType: DocumentType.pdf,
      fileSizeBytes: bytes.length,
    );
  }

  /// 2. Export as OpenXML Word Document (.docx) with embedded scanned pages
  static Future<ExportResult> _exportAsDocx(
    List<ScannedPage> pages,
    String name,
    Directory dir,
  ) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, contentTypesXml.codeUnits));

    // 2. _rels/.rels
    final rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, rootRelsXml.codeUnits));

    // 3. word/_rels/document.xml.rels
    final relsBuffer = StringBuffer();
    relsBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    relsBuffer.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

    for (int i = 0; i < pages.length; i++) {
      final rId = 'rId${i + 1}';
      final target = 'media/image${i + 1}.jpg';
      relsBuffer.writeln('  <Relationship Id="$rId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="$target"/>');
    }
    relsBuffer.writeln('</Relationships>');
    final docRelsStr = relsBuffer.toString();
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsStr.length, docRelsStr.codeUnits));

    // 4. word/document.xml
    final docBuffer = StringBuffer();
    docBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">');
    docBuffer.writeln('  <w:body>');

    // Title paragraph
    docBuffer.writeln('    <w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="32"/><w:color w:val="B04A24"/></w:rPr><w:t>Social Googol Scanned Document</w:t></w:r></w:p>');
    docBuffer.writeln('    <w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="777777"/></w:rPr><w:t>Total Pages: ${pages.length} • 100% On-Device Processed</w:t></w:r></w:p>');

    for (int i = 0; i < pages.length; i++) {
      final rId = 'rId${i + 1}';
      docBuffer.writeln('    <w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t>Page ${i + 1}</w:t></w:r></w:p>');
      // Drawing element containing the image (width: 5.8in, height: 7.7in in EMUs: 1in = 914400 EMUs)
      docBuffer.writeln('''    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:drawing>
          <wp:inline distT="0" distB="0" distL="0" distR="0">
            <wp:extent cx="5303520" cy="7040880"/>
            <wp:docPr id="${i + 1}" name="Page ${i + 1}"/>
            <a:graphic>
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic>
                  <pic:nvPicPr>
                    <pic:cNvPr id="${i + 1}" name="image${i + 1}.jpg"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="$rId"/>
                    <a:stretch><a:fillRect/></a:stretch>
                  </pic:blipFill>
                  <pic:spPr>
                    <a:xfrm><a:off x="0" y="0"/><a:ext cx="5303520" cy="7040880"/></a:xfrm>
                    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                  </pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>''');
      // Page break between pages
      if (i < pages.length - 1) {
        docBuffer.writeln('    <w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    docBuffer.writeln('  </w:body>');
    docBuffer.writeln('</w:document>');
    final docStr = docBuffer.toString();
    archive.addFile(ArchiveFile('word/document.xml', docStr.length, docStr.codeUnits));

    // 5. Add media files
    for (int i = 0; i < pages.length; i++) {
      final imgBytes = pages[i].processedBytes;
      archive.addFile(ArchiveFile('word/media/image${i + 1}.jpg', imgBytes.length, imgBytes));
    }

    final zipEncoder = ZipEncoder();
    final List<int>? encodedZip = zipEncoder.encode(archive);
    final file = File('${dir.path}/$name.docx');
    await file.writeAsBytes(encodedZip ?? [], flush: true);

    return ExportResult(
      filePath: file.path,
      fileName: '$name.docx',
      docType: DocumentType.word,
      fileSizeBytes: file.lengthSync(),
    );
  }

  /// 3. Export as Image (Primary first page as JPG or all pages)
  static Future<ExportResult> _exportAsImages(
    List<ScannedPage> pages,
    String name,
    Directory dir,
  ) async {
    final mainFile = File('${dir.path}/$name.jpg');
    await mainFile.writeAsBytes(pages.first.processedBytes, flush: true);

    // If multiple pages, save secondary pages with suffix
    if (pages.length > 1) {
      for (int i = 1; i < pages.length; i++) {
        final subFile = File('${dir.path}/${name}_page_${i + 1}.jpg');
        await subFile.writeAsBytes(pages[i].processedBytes, flush: true);
      }
    }

    return ExportResult(
      filePath: mainFile.path,
      fileName: '$name.jpg',
      docType: DocumentType.unknown, // Image format
      fileSizeBytes: mainFile.lengthSync(),
    );
  }

  /// 4. Export as ZIP bundle containing all pages
  static Future<ExportResult> _exportAsZip(
    List<ScannedPage> pages,
    String name,
    Directory dir,
  ) async {
    final archive = Archive();
    for (int i = 0; i < pages.length; i++) {
      final pBytes = pages[i].processedBytes;
      archive.addFile(ArchiveFile('page_${i + 1}.jpg', pBytes.length, pBytes));
    }

    // Add manifest
    final manifest = 'Social Googol SG Reader Document Scan\nDocument: $name\nPages: ${pages.length}\nDate: ${DateTime.now().toIso8601String()}\n100% On-Device Air-Gapped Processing';
    archive.addFile(ArchiveFile('manifest.txt', manifest.length, manifest.codeUnits));

    final zipEncoder = ZipEncoder();
    final List<int>? encoded = zipEncoder.encode(archive);
    final file = File('${dir.path}/$name.zip');
    await file.writeAsBytes(encoded ?? [], flush: true);

    return ExportResult(
      filePath: file.path,
      fileName: '$name.zip',
      docType: DocumentType.unknown,
      fileSizeBytes: file.lengthSync(),
    );
  }

  /// 5. Export as TXT Record
  static Future<ExportResult> _exportAsTxt(
    List<ScannedPage> pages,
    String name,
    Directory dir,
  ) async {
    final file = File('${dir.path}/$name.txt');
    final content = '''========================================
SOCIAL GOOGOL - SG READER DOCUMENT SCAN
Secure to Grow - सुरक्षा से ग्रोथ तक
========================================
Document Name : $name
Total Pages   : ${pages.length}
Scan Date     : ${DateTime.now().toLocal()}
Security Mode : 100% Offline Sandbox • Zero Cloud Storage
========================================
''';
    await file.writeAsString(content, flush: true);

    return ExportResult(
      filePath: file.path,
      fileName: '$name.txt',
      docType: DocumentType.unknown,
      fileSizeBytes: file.lengthSync(),
    );
  }
}
