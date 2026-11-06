import 'package:flutter/material.dart';
import '../constants/branding.dart';
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
    final doc = await _docService.pickDocument();
    if (doc != null) {
      _openDocument(doc);
    }
  }

  IconData _iconForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.excel:
        return Icons.table_chart;
      case DocumentType.word:
        return Icons.article;
      case DocumentType.powerpoint:
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return const Color(0xFFEF4444); // Red
      case DocumentType.excel:
        return const Color(0xFF10B981); // Emerald
      case DocumentType.word:
        return const Color(0xFF3B82F6); // Blue
      case DocumentType.powerpoint:
        return const Color(0xFFF97316); // Orange
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedFilter == null
        ? _recentDocs
        : _recentDocs.where((d) => d.type == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: const BrandBanner(),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    BrandConstants.appName,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    BrandConstants.fullTagline,
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white70),
              title: const Text("About Social Googol", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: Color(0xFF10B981)),
              title: const Text("App Lock (Biometrics/PIN)", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Require security authentication on launch", style: TextStyle(color: Colors.white54, fontSize: 11)),
              value: _appLockEnabled,
              onChanged: (val) async {
                await _securityService.setAppLockEnabled(val);
                setState(() {
                  _appLockEnabled = val;
                });
              },
            ),
            const Divider(color: Colors.white12),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Helpline: 8126210003\nWebsite: www.socialgoogol.com\n100% Free & Sideloaded Edition",
                style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Status Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.lock_outline, color: Color(0xFF34D399), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "100% Offline Sandbox • Zero Cloud Uploads • Complete Privacy",
                        style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Format Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text("All"),
                    selected: _selectedFilter == null,
                    onSelected: (_) => setState(() => _selectedFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
                    label: const Text("PDF"),
                    selected: _selectedFilter == DocumentType.pdf,
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.pdf),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.table_chart, size: 16, color: Colors.white),
                    label: const Text("Excel (XLSX)"),
                    selected: _selectedFilter == DocumentType.excel,
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.excel),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.article, size: 16, color: Colors.white),
                    label: const Text("Word (DOCX)"),
                    selected: _selectedFilter == DocumentType.word,
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.word),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.slideshow, size: 16, color: Colors.white),
                    label: const Text("PPT (PPTX)"),
                    selected: _selectedFilter == DocumentType.powerpoint,
                    onSelected: (_) => setState(() => _selectedFilter = DocumentType.powerpoint),
                  ),
                ],
              ),
            ),

            // Recent Documents Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Documents",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${filtered.length} files",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Recent List or Empty State
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 12),
                              const Text(
                                "No recent documents",
                                style: TextStyle(color: Colors.white60, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Tap 'Open File' below to browse PDF, Excel, Word or PPT",
                                style: TextStyle(color: Colors.white38, fontSize: 12),
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
                              tileColor: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.white10),
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _colorForType(doc.type).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _iconForType(doc.type),
                                  color: _colorForType(doc.type),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                doc.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                "${doc.formattedSize} • ${doc.type.name.toUpperCase()}",
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                              onTap: () => _openDocument(doc),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.file_open, color: Colors.white),
        label: const Text("Open File", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _pickAndOpenFile,
      ),
    );
  }
}
