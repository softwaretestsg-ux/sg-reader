import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/branding.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';
import '../services/update_service.dart';
import '../widgets/brand_banner.dart';
import 'pdf_viewer_screen.dart';
import 'excel_editor_screen.dart';
import 'docx_viewer_screen.dart';
import 'pptx_viewer_screen.dart';
import 'about_screen.dart';
import 'scanner_screen.dart';
import '../services/scanner_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _intentChannel = MethodChannel('com.socialgoogol.sgreader/open_file');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DocumentService _docService = DocumentService();
  List<DocumentFile> _recentDocs = [];
  bool _isLoading = true;
  DocumentType? _selectedFilter;
  bool _isSelectionMode = false;
  final Set<String> _selectedDocPaths = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkAppUpdate();
    _initIncomingIntentHandler();
  }

  void _initIncomingIntentHandler() {
    // 1. Check if opened via "Open With" intent on cold launch
    _intentChannel.invokeMethod<Map>('getInitialFile').then((fileMap) {
      if (fileMap != null && mounted) {
        _handleIncomingFileMap(Map<String, dynamic>.from(fileMap));
      }
    }).catchError((e) {
      debugPrint("Error fetching initial file intent: $e");
    });

    // 2. Listen for intent when app is already open in background
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFileOpened' && call.arguments != null) {
        if (mounted) {
          _handleIncomingFileMap(Map<String, dynamic>.from(call.arguments));
        }
      }
    });
  }

  Future<void> _handleIncomingFileMap(Map<String, dynamic> fileMap) async {
    final filePath = fileMap['path'] as String?;
    final originalPath = fileMap['originalPath'] as String?;
    final uriStr = fileMap['uri'] as String?;
    final fileName = fileMap['name'] as String? ?? 'Document';
    final mimeType = fileMap['mimeType'] as String?;

    if (filePath == null) return;
    final file = File(filePath);
    if (!await file.exists()) return;

    final type = DocumentFile.detectType(
      filePath,
      mimeType: mimeType,
    );
    final size = await file.length();

    final doc = DocumentFile(
      path: filePath,
      originalPath: (originalPath != null && originalPath.isNotEmpty) ? originalPath : null,
      uri: (uriStr != null && uriStr.isNotEmpty) ? uriStr : null,
      name: fileName,
      sizeInBytes: size,
      type: type,
      lastOpened: DateTime.now(),
    );

    await _docService.saveRecentDocument(doc);
    _openDocument(doc);
  }

  Future<void> _loadData() async {
    try {
      final docs = await _docService.getRecentDocuments().timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
      if (mounted) {
        setState(() {
          _recentDocs = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error in _loadData: $e");
      if (mounted) {
        setState(() {
          _recentDocs = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAppUpdate() async {
    try {
      final update = await UpdateService.checkForUpdate().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (update != null && mounted) {
        UpdateService.showUpdateDialog(context, update);
      }
    } catch (_) {}
  }

  void _openDocument(DocumentFile doc) {
    if (doc.type == DocumentType.unknown) {
      _showFormatSelectionDialog(doc);
      return;
    }

    Widget destination;
    switch (doc.type) {
      case DocumentType.pdf:
        destination = PdfViewerScreen(document: doc);
        break;
      case DocumentType.excel:
        destination = ExcelEditorScreen(document: doc);
        break;
      case DocumentType.word:
        destination = DocxViewerScreen(document: doc);
        break;
      case DocumentType.powerpoint:
        destination = PptxViewerScreen(document: doc);
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => destination)).then((_) {
      _loadData();
    });
  }

  void _showFormatSelectionDialog(DocumentFile doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: const Text("Open With SG Reader", style: TextStyle(color: SGTheme.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("File: ${doc.name}", style: const TextStyle(color: SGTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            const Text("Choose how to open this document:", style: TextStyle(color: SGTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFE5534B)),
              title: const Text("PDF Viewer", style: TextStyle(color: SGTheme.text)),
              onTap: () {
                Navigator.pop(ctx);
                _openDocument(DocumentFile(
                  path: doc.path,
                  name: doc.name,
                  sizeInBytes: doc.sizeInBytes,
                  type: DocumentType.pdf,
                  lastOpened: doc.lastOpened,
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Color(0xFF4A7EBB)),
              title: const Text("Word Processor (DOCX)", style: TextStyle(color: SGTheme.text)),
              onTap: () {
                Navigator.pop(ctx);
                _openDocument(DocumentFile(
                  path: doc.path,
                  name: doc.name,
                  sizeInBytes: doc.sizeInBytes,
                  type: DocumentType.word,
                  lastOpened: doc.lastOpened,
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Color(0xFF2E7D32)),
              title: const Text("Excel Spreadsheet (XLSX/CSV)", style: TextStyle(color: SGTheme.text)),
              onTap: () {
                Navigator.pop(ctx);
                _openDocument(DocumentFile(
                  path: doc.path,
                  name: doc.name,
                  sizeInBytes: doc.sizeInBytes,
                  type: DocumentType.excel,
                  lastOpened: doc.lastOpened,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _launchDocumentScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SGTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Document Scanner",
              style: TextStyle(color: SGTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Automatically enhance & save to PDF, Word (DOCX), or Images",
              style: TextStyle(color: SGTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: SGTheme.bgDark,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SGTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: SGTheme.accent),
              ),
              title: const Text("Scan with Camera", style: TextStyle(color: SGTheme.text, fontWeight: FontWeight.w600)),
              subtitle: const Text("Take a document photo with live framing", style: TextStyle(color: SGTheme.textSecondary, fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                final page = await ScannerService().capturePageFromCamera();
                if (page != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ScannerScreen(initialPage: page)),
                  ).then((_) => _loadData());
                }
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: SGTheme.bgDark,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A7EBB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFF4A7EBB)),
              ),
              title: const Text("Import from Gallery", style: TextStyle(color: SGTheme.text, fontWeight: FontWeight.w600)),
              subtitle: const Text("Select existing document photo to enhance", style: TextStyle(color: SGTheme.textSecondary, fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                final page = await ScannerService().pickPageFromGallery();
                if (page != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ScannerScreen(initialPage: page)),
                  ).then((_) => _loadData());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationFeedback({
    required String title,
    required String subtitle,
    bool isError = false,
    Widget? actionWidget,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        backgroundColor: SGTheme.surface,
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError ? const Color(0xFFE5534B).withOpacity(0.5) : SGTheme.accentBorder,
            width: 1.2,
          ),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFE5534B).withOpacity(0.15)
                    : const Color(0xFF4F7A4A).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: isError ? const Color(0xFFE5534B) : const Color(0xFF66BB6A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: SGTheme.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: SGTheme.textSecondary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (actionWidget != null) ...[
              const SizedBox(width: 8),
              actionWidget,
            ],
          ],
        ),
      ),
    );
  }

  void _showClearAllConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SGTheme.borderStrong, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SGTheme.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SGTheme.accentBorder),
                  ),
                  child: const Icon(
                    Icons.delete_sweep_outlined,
                    color: SGTheme.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Clear Recent History?",
                        style: TextStyle(
                          color: SGTheme.text,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "History Cleanup",
                        style: TextStyle(
                          color: SGTheme.accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SGTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SGTheme.border),
              ),
              child: const Text(
                "This will clear your recent document viewing history in SG Reader. Your original files will remain safely stored on your device.",
                style: TextStyle(
                  color: SGTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SGTheme.borderStrong),
                    foregroundColor: SGTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Cancel", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5534B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text("Clear All", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _docService.clearRecentDocuments();
                    setState(() {
                      _recentDocs.clear();
                    });
                    _showNotificationFeedback(
                      title: "History Cleared",
                      subtitle: "Recent documents history was emptied.",
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _removeSingleRecentDocument(DocumentFile doc) async {
    await _docService.removeRecentDocument(doc.path);
    setState(() {
      _recentDocs.removeWhere((d) => d.path == doc.path);
    });
    _showNotificationFeedback(
      title: "Removed from Recents",
      subtitle: "'${doc.name}' was removed from history.",
      actionWidget: InkWell(
        onTap: () async {
          await _docService.saveRecentDocument(doc);
          _loadData();
        },
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            "UNDO",
            style: TextStyle(
              color: SGTheme.accent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSelection(DocumentFile doc) {
    setState(() {
      if (_selectedDocPaths.contains(doc.path)) {
        _selectedDocPaths.remove(doc.path);
        if (_selectedDocPaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedDocPaths.add(doc.path);
      }
    });
  }

  void _selectAll(List<DocumentFile> docs) {
    setState(() {
      if (_selectedDocPaths.length == docs.length) {
        _selectedDocPaths.clear();
        _isSelectionMode = false;
      } else {
        _selectedDocPaths.clear();
        for (final d in docs) {
          _selectedDocPaths.add(d.path);
        }
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedDocPaths.clear();
    });
  }

  Future<bool> _ensureStoragePermission() async {
    final hasPerm = await _docService.hasStoragePermission();
    if (hasPerm) return true;

    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SGTheme.borderStrong, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SGTheme.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SGTheme.accentBorder),
                  ),
                  child: const Icon(
                    Icons.folder_special_outlined,
                    color: SGTheme.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Storage Permission Required",
                        style: TextStyle(
                          color: SGTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Android Device Security",
                        style: TextStyle(
                          color: SGTheme.accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SGTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SGTheme.border),
              ),
              child: const Text(
                "To erase physical files from Downloads or SD card storage, Android requires 'All files access'.\n\n1. Tap 'Continue' below.\n2. Enable 'Allow access to manage all files' for SG Reader.\n3. Return to SG Reader to complete file deletion.",
                style: TextStyle(
                  color: SGTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SGTheme.borderStrong),
                    foregroundColor: SGTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Not Now", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SGTheme.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text("Continue", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (proceed == true) {
      await _docService.requestStoragePermission();
    }
    return false;
  }

  void _confirmDeleteFilePermanently(DocumentFile doc) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SGTheme.borderStrong, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5534B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5534B).withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Color(0xFFE5534B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Delete Permanently?",
                        style: TextStyle(
                          color: SGTheme.text,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Physical Storage Removal",
                        style: TextStyle(
                          color: Color(0xFFE5534B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Document Details Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SGTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SGTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _colorForType(doc.type).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _iconForType(doc.type),
                      color: _colorForType(doc.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
                          style: const TextStyle(
                            color: SGTheme.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${doc.formattedSize} • ${doc.type.name.toUpperCase()} Document",
                          style: const TextStyle(
                            color: SGTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Warning Notice Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5534B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5534B).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE5534B)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This file will be completely erased from your phone's storage. This action is permanent and cannot be undone.",
                      style: TextStyle(
                        color: SGTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SGTheme.borderStrong),
                    foregroundColor: SGTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5534B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text(
                    "Delete File",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final hasPerm = await _ensureStoragePermission();
                    if (!hasPerm && mounted) {
                      final recheck = await _docService.hasStoragePermission();
                      if (!recheck) return;
                    }

                    try {
                      final success = await _docService.deleteDocumentPermanently(doc);
                      setState(() {
                        _recentDocs.removeWhere((d) => d.path == doc.path || (doc.originalPath != null && d.originalPath == doc.originalPath));
                        _selectedDocPaths.remove(doc.path);
                      });
                      _showNotificationFeedback(
                        title: success ? "Permanently Deleted" : "Removed from Recents",
                        subtitle: success
                            ? "'${doc.name}' was removed from device storage."
                            : "'${doc.name}' was removed from recent list.",
                      );
                    } catch (e) {
                      _showNotificationFeedback(
                        title: "Deletion Failed",
                        subtitle: "Error deleting file: $e",
                        isError: true,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelectedFilesPermanently() {
    final selectedDocs = _recentDocs.where((d) => _selectedDocPaths.contains(d.path)).toList();
    if (selectedDocs.isEmpty) return;

    final totalBytes = selectedDocs.fold<int>(0, (sum, d) => sum + d.sizeInBytes);
    final totalSizeStr = DocumentFile.formatBytes(totalBytes);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SGTheme.borderStrong, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5534B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5534B).withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Color(0xFFE5534B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Delete ${selectedDocs.length} ${selectedDocs.length == 1 ? 'File' : 'Files'}?",
                        style: const TextStyle(
                          color: SGTheme.text,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Batch Permanent Removal",
                        style: TextStyle(
                          color: Color(0xFFE5534B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SGTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SGTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${selectedDocs.length} Documents Selected",
                        style: const TextStyle(
                          color: SGTheme.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        totalSizeStr,
                        style: const TextStyle(
                          color: SGTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: SGTheme.border, height: 1),
                  const SizedBox(height: 8),
                  Text(
                    selectedDocs.take(3).map((d) => "• ${d.name}").join("\n") +
                        (selectedDocs.length > 3 ? "\n... and ${selectedDocs.length - 3} more" : ""),
                    style: const TextStyle(
                      color: SGTheme.textMuted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Warning Notice Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5534B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5534B).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE5534B)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "All selected files will be permanently erased from your phone's storage. They cannot be recovered.",
                      style: TextStyle(
                        color: SGTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SGTheme.borderStrong),
                    foregroundColor: SGTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5534B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: Text(
                    "Delete All (${selectedDocs.length})",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final hasPerm = await _ensureStoragePermission();
                    if (!hasPerm && mounted) {
                      final recheck = await _docService.hasStoragePermission();
                      if (!recheck) return;
                    }

                    try {
                      final count = await _docService.deleteMultipleDocumentsPermanently(selectedDocs);
                      final deletedPaths = selectedDocs.map((d) => d.path).toSet();
                      setState(() {
                        _recentDocs.removeWhere((d) => deletedPaths.contains(d.path));
                        _exitSelectionMode();
                      });
                      _showNotificationFeedback(
                        title: "Batch Deletion Complete",
                        subtitle: "$count ${count == 1 ? 'file' : 'files'} permanently removed from device storage.",
                      );
                    } catch (e) {
                      _showNotificationFeedback(
                        title: "Deletion Failed",
                        subtitle: "Error deleting files: $e",
                        isError: true,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _removeSelectedFromRecents() async {
    final selectedDocs = _recentDocs.where((d) => _selectedDocPaths.contains(d.path)).toList();
    if (selectedDocs.isEmpty) return;

    for (final doc in selectedDocs) {
      await _docService.removeRecentDocument(doc.path);
    }
    final removedPaths = selectedDocs.map((d) => d.path).toSet();
    setState(() {
      _recentDocs.removeWhere((d) => removedPaths.contains(d.path));
      _exitSelectionMode();
    });
    _showNotificationFeedback(
      title: "Removed from Recents",
      subtitle: "${selectedDocs.length} ${selectedDocs.length == 1 ? 'file' : 'files'} removed from history.",
    );
  }

  Future<void> _pickAndOpenFile() async {
    try {
      final doc = await _docService.pickDocument();
      if (doc != null) {
        if (doc.type == DocumentType.unknown) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: SGTheme.surface,
              content: Text(
                "Selected file '${doc.name}' is not a supported format. Please select a PDF, Excel (.xlsx, .csv), Word (.docx), or PowerPoint (.pptx) file.",
                style: const TextStyle(color: SGTheme.text),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
        _openDocument(doc);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE5534B),
          content: Text("Error accessing file: $e"),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  IconData _iconForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf_outlined;
      case DocumentType.excel:
        return Icons.table_chart_outlined;
      case DocumentType.word:
        return Icons.article_outlined;
      case DocumentType.powerpoint:
        return Icons.slideshow_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _colorForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return const Color(0xFFE5534B);
      case DocumentType.excel:
        return const Color(0xFF4F7A4A);
      case DocumentType.word:
        return const Color(0xFF4B8FE5);
      case DocumentType.powerpoint:
        return SGTheme.accent;
      default:
        return SGTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedFilter == null
        ? _recentDocs
        : _recentDocs.where((d) => d.type == _selectedFilter).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SGTheme.bgDark,
      drawer: Drawer(
        backgroundColor: SGTheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: SGTheme.logoTileDark,
                border: Border(bottom: BorderSide(color: SGTheme.borderStrong)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: SGTheme.bgDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SGTheme.accentBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo-sg.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          BrandConstants.appName,
                          style: TextStyle(
                            color: SGTheme.text,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          BrandConstants.fullTagline,
                          style: TextStyle(
                            color: SGTheme.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined, color: SGTheme.accent),
              title: const Text("Scan Document", style: TextStyle(color: SGTheme.text, fontWeight: FontWeight.bold)),
              subtitle: const Text("Camera scan with offline auto-refine", style: TextStyle(color: SGTheme.textSecondary, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _launchDocumentScanner();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: SGTheme.textSecondary),
              title: const Text("About Social Googol", style: TextStyle(color: SGTheme.text)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFE5534B)),
              title: const Text("Clear Recent Documents", style: TextStyle(color: SGTheme.text)),
              subtitle: const Text("Remove all files from recents history", style: TextStyle(color: SGTheme.textSecondary, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showClearAllConfirmDialog();
              },
            ),
            const Divider(color: SGTheme.border),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "App Version: ${BrandConstants.fullVersionDisplay}",
                    style: TextStyle(color: SGTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Support: +91 81262 10003\nWebsite: www.socialgoogol.com\n100% Offline Secure Architecture",
                    style: TextStyle(color: SGTheme.textMuted, fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Safe buffer ensuring branding is completely clear of system icons (wifi, battery, clock)
            const SizedBox(height: 10),

            // Official Social Googol Branding Card (Separated from status bar)
            BrandBanner(
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            const SizedBox(height: 6),

            // Executive Security Badge (Clean & Professional)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: SGTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SGTheme.accentBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: SGTheme.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_user_outlined, color: SGTheme.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Enterprise On-Device Privacy",
                            style: TextStyle(
                              color: SGTheme.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Air-Gapped Processing • Zero External Data Transmission",
                            style: TextStyle(
                              color: SGTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Format Quick-Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text("All"),
                    selected: _selectedFilter == null,
                    selectedColor: SGTheme.accentDeep,
                    backgroundColor: SGTheme.surface,
                    labelStyle: TextStyle(
                      color: _selectedFilter == null ? Colors.white : SGTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.white),
                    label: const Text("PDF"),
                    selected: _selectedFilter == DocumentType.pdf,
                    selectedColor: SGTheme.accentDeep,
                    backgroundColor: SGTheme.surface,
                    labelStyle: TextStyle(
                      color: _selectedFilter == DocumentType.pdf ? Colors.white : SGTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.pdf),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.table_chart_outlined, size: 16, color: Colors.white),
                    label: const Text("Excel (XLSX)"),
                    selected: _selectedFilter == DocumentType.excel,
                    selectedColor: SGTheme.accentDeep,
                    backgroundColor: SGTheme.surface,
                    labelStyle: TextStyle(
                      color: _selectedFilter == DocumentType.excel ? Colors.white : SGTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.excel),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.article_outlined, size: 16, color: Colors.white),
                    label: const Text("Word (DOCX)"),
                    selected: _selectedFilter == DocumentType.word,
                    selectedColor: SGTheme.accentDeep,
                    backgroundColor: SGTheme.surface,
                    labelStyle: TextStyle(
                      color: _selectedFilter == DocumentType.word ? Colors.white : SGTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.word),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.slideshow_outlined, size: 16, color: Colors.white),
                    label: const Text("PPT (PPTX)"),
                    selected: _selectedFilter == DocumentType.powerpoint,
                    selectedColor: SGTheme.accentDeep,
                    backgroundColor: SGTheme.surface,
                    labelStyle: TextStyle(
                      color: _selectedFilter == DocumentType.powerpoint ? Colors.white : SGTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.powerpoint),
                  ),
                ],
              ),
            ),

            // Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: _isSelectionMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: filtered.isNotEmpty && _selectedDocPaths.length == filtered.length,
                              tristate: _selectedDocPaths.isNotEmpty && _selectedDocPaths.length < filtered.length,
                              activeColor: SGTheme.accent,
                              checkColor: Colors.white,
                              onChanged: (_) => _selectAll(filtered),
                            ),
                            Text(
                              "${_selectedDocPaths.length} Selected",
                              style: const TextStyle(
                                color: SGTheme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _exitSelectionMode,
                          icon: const Icon(Icons.close, size: 16, color: SGTheme.textSecondary),
                          label: const Text("Done", style: TextStyle(color: SGTheme.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Documents",
                          style: TextStyle(
                            color: SGTheme.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (filtered.isNotEmpty)
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isSelectionMode = true;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.checklist, size: 16, color: SGTheme.accent),
                                      SizedBox(width: 4),
                                      Text(
                                        "Select",
                                        style: TextStyle(
                                          color: SGTheme.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: _showClearAllConfirmDialog,
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_sweep_outlined, size: 16, color: SGTheme.accent),
                                      SizedBox(width: 4),
                                      Text(
                                        "Clear All",
                                        style: TextStyle(
                                          color: SGTheme.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "(${filtered.length})",
                                style: const TextStyle(color: SGTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
            ),

            // Recent Documents List or Empty State
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: SGTheme.accent))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_outlined, size: 56, color: SGTheme.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 12),
                              const Text(
                                "No recent documents",
                                style: TextStyle(color: SGTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Tap 'Open Document' or 'Scan Doc' to get started",
                                style: TextStyle(color: SGTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final doc = filtered[index];
                            final isSelected = _selectedDocPaths.contains(doc.path);

                            final listTile = ListTile(
                              tileColor: isSelected ? SGTheme.accent.withOpacity(0.12) : SGTheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? SGTheme.accent : SGTheme.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      activeColor: SGTheme.accent,
                                      checkColor: Colors.white,
                                      onChanged: (_) => _toggleSelection(doc),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _colorForType(doc.type).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _iconForType(doc.type),
                                        color: _colorForType(doc.type),
                                        size: 22,
                                      ),
                                    ),
                              title: Text(
                                doc.name,
                                style: const TextStyle(
                                  color: SGTheme.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                "${doc.formattedSize} • ${doc.type.name.toUpperCase()}",
                                style: const TextStyle(color: SGTheme.textMuted, fontSize: 11),
                              ),
                              trailing: _isSelectionMode
                                  ? null
                                  : PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: SGTheme.textMuted, size: 20),
                                      color: SGTheme.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: const BorderSide(color: SGTheme.border),
                                      ),
                                      onSelected: (val) {
                                        if (val == 'open') {
                                          _openDocument(doc);
                                        } else if (val == 'share') {
                                          Share.shareXFiles([XFile(doc.path)], text: "Sharing ${doc.name} via Social Googol's SG Reader");
                                        } else if (val == 'remove') {
                                          _removeSingleRecentDocument(doc);
                                        } else if (val == 'delete') {
                                          _confirmDeleteFilePermanently(doc);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'open',
                                          child: Row(
                                            children: [
                                              Icon(Icons.open_in_new, color: SGTheme.accent, size: 18),
                                              SizedBox(width: 10),
                                              Text("Open Document", style: TextStyle(color: SGTheme.text, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            children: [
                                              Icon(Icons.share_outlined, color: Color(0xFF4B8FE5), size: 18),
                                              SizedBox(width: 10),
                                              Text("Share File", style: TextStyle(color: SGTheme.text, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(Icons.close, color: SGTheme.textSecondary, size: 18),
                                              SizedBox(width: 10),
                                              Text("Remove from Recents", style: TextStyle(color: SGTheme.text, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, color: Color(0xFFE5534B), size: 18),
                                              SizedBox(width: 10),
                                              Text("Delete Permanently", style: TextStyle(color: Color(0xFFE5534B), fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(doc);
                                } else {
                                  _openDocument(doc);
                                }
                              },
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedDocPaths.add(doc.path);
                                  });
                                }
                              },
                            );

                            if (_isSelectionMode) {
                              return listTile;
                            }

                            return Dismissible(
                              key: Key(doc.path),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5534B).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.white, size: 22),
                                    SizedBox(width: 6),
                                    Text("Remove", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                              onDismissed: (_) => _removeSingleRecentDocument(doc),
                              child: listTile,
                            );
                          },
                        ),
            ),

            // Multi-Selection Bottom Action Bar
            if (_isSelectionMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: SGTheme.surface,
                  border: Border(top: BorderSide(color: SGTheme.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SGTheme.borderStrong),
                            foregroundColor: SGTheme.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.playlist_remove_rounded, size: 17),
                          label: Text(
                            "Remove Recents (${_selectedDocPaths.length})",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _selectedDocPaths.isEmpty ? null : _removeSelectedFromRecents,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5534B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded, size: 17),
                          label: Text(
                            "Delete (${_selectedDocPaths.length})",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _selectedDocPaths.isEmpty ? null : _confirmDeleteSelectedFilesPermanently,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    heroTag: "scan_btn",
                    backgroundColor: SGTheme.accent,
                    icon: const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      "Scan Doc",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _launchDocumentScanner,
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.extended(
                    heroTag: "open_btn",
                    backgroundColor: SGTheme.surface,
                    icon: const Icon(Icons.file_open_outlined, color: SGTheme.accent, size: 20),
                    label: const Text(
                      "Open File",
                      style: TextStyle(color: SGTheme.text, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _pickAndOpenFile,
                  ),
                ],
              ),
            ),
    );
  }
}
