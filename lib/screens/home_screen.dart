import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unsupported format for viewing.")),
        );
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => destination)).then((_) {
      _loadData();
    });
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
      appBar: BrandBanner(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
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
              leading: const Icon(Icons.info_outline, color: SGTheme.textSecondary),
              title: const Text("About Social Googol", style: TextStyle(color: SGTheme.text)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
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
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Support: +91 81262 10003\nWebsite: www.socialgoogol.com\nSecure Offline Architecture",
                style: TextStyle(color: SGTheme.textMuted, fontSize: 11, height: 1.6),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  Text(
                    "${filtered.length} files",
                    style: const TextStyle(color: SGTheme.textMuted, fontSize: 12),
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
                                "Tap 'Open Document' to browse PDF, Excel, Word or PPT files",
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
                            return ListTile(
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
                              trailing: const Icon(Icons.arrow_forward_ios, color: SGTheme.borderStrong, size: 13),
                              onTap: () => _openDocument(doc),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SGTheme.accentDeep,
        icon: const Icon(Icons.file_open_outlined, color: Colors.white),
        label: const Text(
          "Open Document",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _pickAndOpenFile,
      ),
    );
  }
}
