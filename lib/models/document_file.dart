import 'dart:io';
import 'dart:math';

enum DocumentType {
  pdf,
  excel,
  word,
  powerpoint,
  unknown,
}

class DocumentFile {
  final String path;
  final String? originalPath;
  final String? uri;
  final String name;
  final int sizeInBytes;
  final DocumentType type;
  final DateTime lastOpened;

  DocumentFile({
    required this.path,
    this.originalPath,
    this.uri,
    required this.name,
    required this.sizeInBytes,
    required this.type,
    required this.lastOpened,
  });

  /// Robust multi-layer document type detection (Extension -> MIME -> Magic Bytes)
  static DocumentType detectType(String filePath, {String? mimeType}) {
    final lower = filePath.toLowerCase();
    
    // 1. File Extension check
    if (lower.endsWith('.pdf')) return DocumentType.pdf;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv')) {
      return DocumentType.excel;
    }
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return DocumentType.word;
    if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) return DocumentType.powerpoint;

    // 2. MIME Type check
    if (mimeType != null && mimeType.isNotEmpty) {
      final mLower = mimeType.toLowerCase();
      if (mLower.contains('pdf')) return DocumentType.pdf;
      if (mLower.contains('sheet') || mLower.contains('excel') || mLower.contains('csv')) {
        return DocumentType.excel;
      }
      if (mLower.contains('word') || mLower.contains('msword') || mLower.contains('wordprocessingml')) {
        return DocumentType.word;
      }
      if (mLower.contains('presentation') || mLower.contains('powerpoint')) {
        return DocumentType.powerpoint;
      }
    }

    // 3. Inspect magic bytes from file header
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final length = file.lengthSync();
        if (length >= 4) {
          final raf = file.openSync(mode: FileMode.read);
          final bytes = raf.readSync(min(length, 4096));
          raf.closeSync();

          // Check PDF magic bytes: %PDF (0x25, 0x50, 0x44, 0x46)
          if (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
            return DocumentType.pdf;
          }

          // Check ZIP signature (PK\x03\x04 or PK\x05\x06) for modern Office formats (.docx, .xlsx, .pptx)
          if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
            final ascii = String.fromCharCodes(bytes);
            if (ascii.contains('word/')) return DocumentType.word;
            if (ascii.contains('xl/')) return DocumentType.excel;
            if (ascii.contains('ppt/')) return DocumentType.powerpoint;
            // Default ZIP package without clear entry: check docx first
            return DocumentType.word;
          }

          // Check OLE2 Compound File (0xD0 0xCF 0x11 0xE0) for legacy Office (.xls, .doc, .ppt)
          if (bytes.length >= 8 &&
              bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0) {
            final ascii = String.fromCharCodes(bytes);
            if (ascii.contains('Workbook') || ascii.contains('Book')) return DocumentType.excel;
            if (ascii.contains('WordDocument')) return DocumentType.word;
            if (ascii.contains('PowerPoint')) return DocumentType.powerpoint;
            return DocumentType.excel; // Most common legacy compound
          }
        }
      }
    } catch (_) {}

    return DocumentType.unknown;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedSize => formatBytes(sizeInBytes);

  Map<String, dynamic> toJson() => {
        'path': path,
        if (originalPath != null) 'originalPath': originalPath,
        if (uri != null) 'uri': uri,
        'name': name,
        'sizeInBytes': sizeInBytes,
        'type': type.index,
        'lastOpened': lastOpened.toIso8601String(),
      };

  factory DocumentFile.fromJson(Map<String, dynamic> json) => DocumentFile(
        path: json['path'],
        originalPath: json['originalPath'],
        uri: json['uri'],
        name: json['name'],
        sizeInBytes: json['sizeInBytes'],
        type: DocumentType.values[json['type'] ?? 0],
        lastOpened: DateTime.parse(json['lastOpened']),
      );
}
