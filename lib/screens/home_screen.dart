import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/branding.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';
import '../services/security_service.dart';
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
  final SecurityService _securityService = SecurityService();
  List<DocumentFile> _recentDocs = [];
  bool _isLoading = true;
  DocumentType? _selectedFilter;
  bool _appLockEnabled = false;

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
      name: fileName,
      sizeInBytes: size,
      type: type,
      lastOpened: DateTime.now(),
    );

    await _docService.saveRecentDocument(doc);
    _openDocument(doc);
  }

  Future<void> _loadData() async {
    final docs = await _docService.getRecentDocuments();
    final lock = await _securityService.isAppLockEnabled();
    setState(() {
      _recentDocs = docs;
      _appLockEnabled = lock;
      _isLoading = false;
    });
  }

  Future<void> _checkAppUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      UpdateService.showUpdateDialog(context, update);
    }
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

  void _showClearAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: const Text("Clear Recent Documents?", style: TextStyle(color: SGTheme.text, fontWeight: FontWeight.bold)),
        content: const Text(
          "This will clear your recent document history in SG Reader. Your original files will remain safely stored on your device.",
          style: TextStyle(color: SGTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: SGTheme.textMuted)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5534B),
              foregroundColor: Colors.white,
            ),
            child: const Text("Clear History"),
            onPressed: () async {
              Navigator.pop(ctx);
              await _docService.clearRecentDocuments();
              setState(() {
                _recentDocs.clear();
              });
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Recent document history cleared."),
                  backgroundColor: SGTheme.surface,
                  duration: Duration(seconds: 2),
                ),
              );
            },
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Removed '${doc.name}' from recents."),
        backgroundColor: SGTheme.surface,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: "Undo",
          textColor: SGTheme.accent,
          onPressed: () async {
            await _docService.saveRecentDocument(doc);
            _loadData();
          },
        ),
      ),
    );
  }

  void _confirmDeleteFilePermanently(DocumentFile doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGTheme.surface,
        title: const Text("Delete File Permanently?", style: TextStyle(color: Color(0xFFE5534B), fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to permanently delete '${doc.name}' from your device storage? This cannot be undone.",
          style: const TextStyle(color: SGTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: SGTheme.textMuted)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5534B),
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete Permanently"),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final file = File(doc.path);
                if (await file.exists()) {
                  await file.delete();
                }
                await _docService.removeRecentDocument(doc.path);
                setState(() {
                  _recentDocs.removeWhere((d) => d.path == doc.path);
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Permanently deleted '${doc.name}'."),
                    backgroundColor: const Color(0xFFE5534B),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error deleting file: $e")),
                );
              }
            },
          ),
        ],
      ),
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
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: SGTheme.accent),
              title: const Text("App Lock (Biometrics/PIN)", style: TextStyle(color: SGTheme.text)),
              subtitle: const Text(
                "Require biometric verification to open documents",
                style: TextStyle(color: SGTheme.textMuted, fontSize: 11),
              ),
              value: _appLockEnabled,
              activeColor: SGTheme.accent,
              onChanged: (val) async {
                await _securityService.setAppLockEnabled(val);
                setState(() {
                  _appLockEnabled = val;
                });
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
              child: Row(
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
                          onTap: _showClearAllConfirmDialog,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: const [
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
                              child: ListTile(
                                tileColor: SGTheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: SGTheme.border),
                                ),
                                leading: Container(
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
                                trailing: PopupMenuButton<String>(
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
                                onTap: () => _openDocument(doc),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
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
