enum DocumentType {
  pdf,
  excel,
  word,
  powerpoint,
  unknown,
}

class DocumentFile {
  final String path;
  final String name;
  final int sizeInBytes;
  final DocumentType type;
  final DateTime lastOpened;

  DocumentFile({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.type,
    required this.lastOpened,
  });

  static DocumentType detectType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.pdf')) return DocumentType.pdf;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv')) {
      return DocumentType.excel;
    }
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return DocumentType.word;
    if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) return DocumentType.powerpoint;
    return DocumentType.unknown;
  }

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'sizeInBytes': sizeInBytes,
        'type': type.index,
        'lastOpened': lastOpened.toIso8601String(),
      };

  factory DocumentFile.fromJson(Map<String, dynamic> json) => DocumentFile(
        path: json['path'],
        name: json['name'],
        sizeInBytes: json['sizeInBytes'],
        type: DocumentType.values[json['type'] ?? 0],
        lastOpened: DateTime.parse(json['lastOpened']),
      );
}
