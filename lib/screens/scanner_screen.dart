import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/branding.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';
import '../services/scanner_export_service.dart';
import '../services/scanner_service.dart';
import '../widgets/perspective_cropper.dart';
import '../widgets/watermark_eraser_dialog.dart';
import 'docx_viewer_screen.dart';
import 'pdf_viewer_screen.dart';

class ScannerScreen extends StatefulWidget {
  final ScannedPage initialPage;

  const ScannerScreen({Key? key, required this.initialPage}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ScannerService _scannerService = ScannerService();
  final DocumentService _docService = DocumentService();
  late final List<ScannedPage> _pages;
  int _currentPageIndex = 0;
  bool _isProcessingFilter = false;

  @override
  void initState() {
    super.initState();
    _pages = [widget.initialPage];
  }

  ScannedPage get _currentPage => _pages[_currentPageIndex];

  Future<void> _applyFilter(ScanFilterType filter) async {
    if (_currentPage.currentFilter == filter) return;
    setState(() => _isProcessingFilter = true);

    try {
      final processed = await _scannerService.processPage(
        _currentPage.originalBytes,
        filter,
        _currentPage.rotationAngle,
      );
      if (!mounted) return;
      setState(() {
        _currentPage.currentFilter = filter;
        _currentPage.processedBytes = processed;
        _isProcessingFilter = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingFilter = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error applying filter: $e")),
      );
    }
  }

  Future<void> _rotatePage() async {
    setState(() => _isProcessingFilter = true);
    final newAngle = (_currentPage.rotationAngle + 90) % 360;

    try {
      final processed = await _scannerService.processPage(
        _currentPage.originalBytes,
        _currentPage.currentFilter,
        newAngle,
      );
      if (!mounted) return;
      setState(() {
        _currentPage.rotationAngle = newAngle;
        _currentPage.processedBytes = processed;
        _isProcessingFilter = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingFilter = false);
    }
  }

  Future<void> _openCropper() async {
    final result = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => PerspectiveCropperScreen(
          imageBytes: _currentPage.originalBytes,
          initialCorners: _currentPage.corners,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _isProcessingFilter = true);
      final processed = await _scannerService.processPage(
        result,
        _currentPage.currentFilter,
        _currentPage.rotationAngle,
      );
      if (!mounted) return;
      setState(() {
        _pages[_currentPageIndex] = ScannedPage(
          id: _currentPage.id,
          originalBytes: result,
          processedBytes: processed,
          currentFilter: _currentPage.currentFilter,
          rotationAngle: _currentPage.rotationAngle,
        );
        _isProcessingFilter = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✨ Document dewarped and straightened successfully!")),
      );
    }
  }

  Future<void> _openWatermarkCleaner() async {
    final cleaned = await showDialog<Uint8List>(
      context: context,
      builder: (_) => WatermarkEraserDialog(imageBytes: _currentPage.processedBytes),
    );

    if (cleaned != null && mounted) {
      setState(() {
        _currentPage.processedBytes = cleaned;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✨ Watermark removed from current page!")),
      );
    }
  }

  Future<void> _addPageFromCamera() async {
    final newPage = await _scannerService.capturePageFromCamera();
    if (newPage != null && mounted) {
      setState(() {
        _pages.add(newPage);
        _currentPageIndex = _pages.length - 1;
      });
    }
  }

  Future<void> _addPageFromGallery() async {
    final newPage = await _scannerService.pickPageFromGallery();
    if (newPage != null && mounted) {
      setState(() {
        _pages.add(newPage);
        _currentPageIndex = _pages.length - 1;
      });
    }
  }

  void _deleteCurrentPage() {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Document must have at least one page.")),
      );
      return;
    }

    setState(() {
      _pages.removeAt(_currentPageIndex);
      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
    });
  }

  void _showSaveFormatDialog() {
    final now = DateTime.now();
    final defaultName = "SG_Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
    final nameController = TextEditingController(text: defaultName);
    ExportFormat selectedFormat = ExportFormat.pdf;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SGTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SGTheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.save_as_outlined, color: SGTheme.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Save Scanned Document",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SGTheme.text),
                      ),
                      Text(
                        "${_pages.length} ${_pages.length == 1 ? 'Page' : 'Pages'} • 100% Offline Processing",
                        style: const TextStyle(fontSize: 12, color: SGTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // File Name Input
              const Text("Document Name", style: TextStyle(color: SGTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                style: const TextStyle(color: SGTheme.text),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: SGTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: SGTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SGTheme.accent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Format Selector
              const Text("Choose Output Format:", style: TextStyle(color: SGTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),

              _buildFormatOption(
                format: ExportFormat.pdf,
                current: selectedFormat,
                icon: Icons.picture_as_pdf_outlined,
                iconColor: const Color(0xFFE5534B),
                title: "PDF Document (.pdf)",
                subtitle: "Recommended • Multi-page document, printable & universal",
                onTap: () => setModalState(() => selectedFormat = ExportFormat.pdf),
              ),
              const SizedBox(height: 8),

              _buildFormatOption(
                format: ExportFormat.docx,
                current: selectedFormat,
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF4A7EBB),
                title: "Word Document (.docx)",
                subtitle: "Editable Word file with embedded scanned pages",
                onTap: () => setModalState(() => selectedFormat = ExportFormat.docx),
              ),
              const SizedBox(height: 8),

              _buildFormatOption(
                format: ExportFormat.jpg,
                current: selectedFormat,
                icon: Icons.image_outlined,
                iconColor: const Color(0xFF4CAF50),
                title: "Enhanced Images (.jpg)",
                subtitle: "High-resolution clean JPEG images",
                onTap: () => setModalState(() => selectedFormat = ExportFormat.jpg),
              ),
              const SizedBox(height: 8),

              _buildFormatOption(
                format: ExportFormat.zip,
                current: selectedFormat,
                icon: Icons.folder_zip_outlined,
                iconColor: const Color(0xFFFFA726),
                title: "Compressed ZIP (.zip)",
                subtitle: "Archive bundle containing all scanned pages",
                onTap: () => setModalState(() => selectedFormat = ExportFormat.zip),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SGTheme.textSecondary,
                        side: BorderSide(color: SGTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SGTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text("Save & Finish", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final chosenName = nameController.text.trim().isEmpty ? defaultName : nameController.text.trim();
                        Navigator.pop(ctx);
                        _executeExport(chosenName, selectedFormat);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatOption({
    required ExportFormat format,
    required ExportFormat current,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isSelected = format == current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? SGTheme.accent.withOpacity(0.12) : SGTheme.bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? SGTheme.accent : SGTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? SGTheme.accent : SGTheme.text)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: SGTheme.textSecondary)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.radio_button_checked, color: SGTheme.accent, size: 20)
            else
              const Icon(Icons.radio_button_off, color: SGTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _executeExport(String name, ExportFormat format) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: SGTheme.accent),
      ),
    );

    try {
      final result = await ScannerExportService.exportDocument(
        pages: _pages,
        baseFileName: name,
        format: format,
      );

      // Save to recent documents list in SG Reader
      final docFile = DocumentFile(
        path: result.filePath,
        name: result.fileName,
        sizeInBytes: result.fileSizeBytes,
        type: result.docType,
        lastOpened: DateTime.now(),
      );
      await _docService.saveRecentDocument(docFile);

      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator

      _showSuccessActionsSheet(docFile);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export document: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessActionsSheet(DocumentFile docFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SGTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 54),
            const SizedBox(height: 12),
            const Text(
              "Document Saved Successfully!",
              style: TextStyle(color: SGTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              docFile.name,
              style: const TextStyle(color: SGTheme.accent, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            // Open document inside SG Reader
            if (docFile.type == DocumentType.pdf || docFile.type == DocumentType.word)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SGTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Open in SG Reader", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx); // Close sheet
                    Navigator.pop(context); // Pop scanner
                    if (docFile.type == DocumentType.pdf) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(document: docFile)));
                    } else if (docFile.type == DocumentType.word) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DocxViewerScreen(document: docFile)));
                    }
                  },
                ),
              ),

            const SizedBox(height: 10),

            // Share Document
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SGTheme.text,
                  side: BorderSide(color: SGTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_outlined, color: SGTheme.accent),
                label: const Text("Share Document (WhatsApp / Email)"),
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(docFile.path)], text: "Sharing ${docFile.name} via Social Googol's SG Reader");
                  Navigator.pop(context);
                },
              ),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("Done & Back to Home", style: TextStyle(color: SGTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Document Scanner & Refiner",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SGTheme.text),
            ),
            Text(
              "Page ${_currentPageIndex + 1} of ${_pages.length} • 100% Offline AI Refine",
              style: const TextStyle(fontSize: 11, color: SGTheme.accent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_outlined, color: SGTheme.accent),
            tooltip: "Adjust 4 Corners & Dewarp",
            onPressed: _openCropper,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined, color: SGTheme.accent),
            tooltip: "Remove Watermarks & Stamps",
            onPressed: _openWatermarkCleaner,
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right_outlined, color: SGTheme.accent),
            tooltip: "Rotate 90°",
            onPressed: _rotatePage,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE5534B)),
            tooltip: "Delete Page",
            onPressed: _deleteCurrentPage,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Page Thumbnails Bar (If multi-page)
            if (_pages.length > 1)
              Container(
                height: 64,
                color: SGTheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final isCurrent = i == _currentPageIndex;
                    return InkWell(
                      onTap: () => setState(() => _currentPageIndex = i),
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isCurrent ? SGTheme.accent : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            _pages[i].processedBytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Live Document Preview
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.5,
                        child: Image.memory(
                          _currentPage.processedBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  if (_isProcessingFilter)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: SGTheme.accent),
                      ),
                    ),
                ],
              ),
            ),

            // Auto-Refine Filter Ribbon
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              color: SGTheme.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: "🪄 Auto Refine",
                      filter: ScanFilterType.autoRefine,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: "📄 Crisp B&W",
                      filter: ScanFilterType.crispBw,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: "🔘 Grayscale",
                      filter: ScanFilterType.grayscale,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: "🎨 Enhanced Color",
                      filter: ScanFilterType.colorEnhanced,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: "📷 Original",
                      filter: ScanFilterType.original,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1F1913),
                border: Border(top: BorderSide(color: Color(0xFF2E251E))),
              ),
              child: Row(
                children: [
                  // Add Page from Camera
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: SGTheme.surface,
                      foregroundColor: SGTheme.accent,
                    ),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    tooltip: "Scan Page from Camera",
                    onPressed: _addPageFromCamera,
                  ),
                  const SizedBox(width: 8),

                  // Add Page from Gallery
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: SGTheme.surface,
                      foregroundColor: SGTheme.textSecondary,
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: "Add Page from Gallery",
                    onPressed: _addPageFromGallery,
                  ),
                  const SizedBox(width: 12),

                  // Save & Export Primary CTA
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SGTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text(
                        "Save Document...",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: _showSaveFormatDialog,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required ScanFilterType filter,
  }) {
    final isSelected = _currentPage.currentFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : SGTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
      ),
      selected: isSelected,
      selectedColor: SGTheme.accent,
      backgroundColor: SGTheme.bgDark,
      side: BorderSide(color: isSelected ? SGTheme.accent : SGTheme.border),
      onSelected: (_) => _applyFilter(filter),
    );
  }
}
