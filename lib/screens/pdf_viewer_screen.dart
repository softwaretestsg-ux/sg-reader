import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';
import '../services/document_service.dart';
import '../services/pdf_powerhouse_service.dart';
import '../widgets/zoom_controls_dock.dart';
import '../widgets/signature_pad_dialog.dart';
import '../widgets/liquid_reader_view.dart';

class PdfViewerScreen extends StatefulWidget {
  final DocumentFile document;

  const PdfViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfPowerhouseService _powerhouseService = PdfPowerhouseService();
  Key _reloadKey = UniqueKey();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _errorMessage;
  double _currentZoom = 1.0;

  // Liquid Reflow & Accessibility TTS
  bool _isLiquidMode = false;
  List<String> _extractedPagesText = [];
  bool _isLoadingLiquid = false;

  // Search feature
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;

  // Multi-touch pinch tracking for sub-100% zoom
  final Map<int, Offset> _pointerPositions = {};
  double _initialPinchDistance = 0.0;
  double _pinchStartZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateZoom(double newZoom) {
    final clamped = newZoom.clamp(0.35, 5.0);
    if (clamped >= 1.0) {
      _pdfViewerController.zoomLevel = clamped;
    } else {
      _pdfViewerController.zoomLevel = 1.0;
    }
    setState(() {
      _currentZoom = clamped;
    });
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) {
      _searchResult?.clear();
      setState(() {
        _searchResult = null;
      });
      return;
    }
    _searchResult = _pdfViewerController.searchText(query);
    setState(() {});
  }

  Future<void> _shareDocument() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.document.path)],
        text: "Sharing ${widget.document.name} via Social Googol's SG Reader",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sharing file: $e")),
      );
    }
  }

  Future<void> _toggleLiquidMode() async {
    if (_isLiquidMode) {
      setState(() => _isLiquidMode = false);
      return;
    }

    if (_extractedPagesText.isNotEmpty) {
      setState(() => _isLiquidMode = true);
      return;
    }

    setState(() => _isLoadingLiquid = true);
    try {
      final pages = await _powerhouseService.extractPagesText(widget.document.path);
      setState(() {
        _extractedPagesText = pages;
        _isLiquidMode = true;
        _isLoadingLiquid = false;
      });
    } catch (e) {
      setState(() => _isLoadingLiquid = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not reflow document: $e")),
        );
      }
    }
  }

  Future<void> _showFillAndSignDialog() async {
    final signatureBytes = await SignaturePadDialog.show(context);
    if (signatureBytes == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: SGTheme.accent),
      ),
    );

    try {
      final targetPage = (_currentPage - 1).clamp(0, (_totalPages > 0 ? _totalPages - 1 : 0));
      // Standard signature stamp rect (bottom-right: x: 340, y: 680, w: 200, h: 90)
      const stampRect = Rect.fromLTWH(340, 680, 200, 90);

      final signedPath = await _powerhouseService.stampSignature(
        pdfPath: widget.document.path,
        signaturePngBytes: signatureBytes,
        pageIndex: targetPage,
        stampRect: stampRect,
      );

      if (mounted) {
        Navigator.pop(context); // close loader
        setState(() {
          _reloadKey = UniqueKey();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Signature stamped on Page $_currentPage & saved!"),
            backgroundColor: const Color(0xFF107C41),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to stamp signature: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _compressPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          color: SGTheme.surface,
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: SGTheme.accent),
                SizedBox(height: 16),
                Text("Optimizing & Compressing PDF...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final compressedDoc = await _powerhouseService.compressPdf(widget.document.path);
      if (mounted) {
        Navigator.pop(context); // close loader
        final originalKb = (widget.document.sizeInBytes / 1024).round();
        final compressedKb = (compressedDoc.sizeInBytes / 1024).round();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: SGTheme.surface,
            title: const Text("PDF Compressed Successfully", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Original Size: $originalKb KB", style: const TextStyle(color: SGTheme.textSecondary)),
                Text("Compressed Size: $compressedKb KB", style: const TextStyle(color: Color(0xFF107C41), fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Saved to: ${compressedDoc.name}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: SGTheme.accent)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Compression error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditPdfDialog() {
    final textController = TextEditingController();
    String selectedPosition = 'top';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SGTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Edit & Annotate PDF",
                    style: TextStyle(
                      color: SGTheme.text,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: SGTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Add an official revision note or stamp to Page $_currentPage and save directly to PDF.",
                style: const TextStyle(color: SGTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: SGTheme.text),
                decoration: InputDecoration(
                  labelText: "Note / Endorsement Text",
                  hintText: "e.g. Verified by Social Googol, Approved, Reviewed...",
                  labelStyle: const TextStyle(color: SGTheme.accent),
                  hintStyle: const TextStyle(color: SGTheme.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: SGTheme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text("Position: ", style: TextStyle(color: SGTheme.textSecondary, fontSize: 13)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Top Header"),
                    selected: selectedPosition == 'top',
                    selectedColor: SGTheme.accentDeep,
                    labelStyle: TextStyle(
                      color: selectedPosition == 'top' ? Colors.white : SGTheme.text,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedPosition = 'top');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Bottom Footer"),
                    selected: selectedPosition == 'bottom',
                    selectedColor: SGTheme.accentDeep,
                    labelStyle: TextStyle(
                      color: selectedPosition == 'bottom' ? Colors.white : SGTheme.text,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedPosition = 'bottom');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text(
                    "Save Changes to PDF",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SGTheme.accentDeep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final note = textController.text.trim();
                    if (note.isEmpty) return;
                    Navigator.pop(ctx);
                    await _savePdfNote(note, selectedPosition);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePdfNote(String note, String position) async {
    try {
      final docService = DocumentService();
      await docService.addPdfAnnotation(
        widget.document.path,
        pageIndex: _currentPage > 0 ? _currentPage - 1 : 0,
        text: note,
        position: position,
      );

      // Force PDF viewer to reload updated file from disk
      setState(() {
        _reloadKey = UniqueKey();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Note saved into PDF file on disk."),
          backgroundColor: Color(0xFF4F7A4A),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving PDF note: $e"),
          backgroundColor: const Color(0xFFE5534B),
        ),
      );
    }
  }

  void _showWatermarkRedactDialog() {
    String selectedArea = 'footer';

    showModalBottomSheet(
      context: context,
      backgroundColor: SGTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20.0),
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
                    child: const Icon(Icons.cleaning_services_outlined, color: SGTheme.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Remove Watermark from PDF",
                        style: TextStyle(color: SGTheme.text, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Clean unwanted stamps or footers on Page $_currentPage",
                        style: const TextStyle(color: SGTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Select Watermark Location on Page:", style: TextStyle(color: SGTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Bottom Footer (e.g. Scanned with...)"),
                    selected: selectedArea == 'footer',
                    selectedColor: SGTheme.accentDeep,
                    labelStyle: TextStyle(color: selectedArea == 'footer' ? Colors.white : SGTheme.text),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedArea = 'footer');
                    },
                  ),
                  ChoiceChip(
                    label: const Text("Top Header"),
                    selected: selectedArea == 'header',
                    selectedColor: SGTheme.accentDeep,
                    labelStyle: TextStyle(color: selectedArea == 'header' ? Colors.white : SGTheme.text),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedArea = 'header');
                    },
                  ),
                  ChoiceChip(
                    label: const Text("Bottom-Right Corner"),
                    selected: selectedArea == 'bottom_right',
                    selectedColor: SGTheme.accentDeep,
                    labelStyle: TextStyle(color: selectedArea == 'bottom_right' ? Colors.white : SGTheme.text),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedArea = 'bottom_right');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SGTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 20),
                  label: const Text("Clean Watermark on Current Page"),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _applyPdfWhiteout(selectedArea);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyPdfWhiteout(String area) async {
    try {
      final docService = DocumentService();
      // Calculate coordinates: A4 standard points (approx 595 x 842)
      Rect bounds = const Rect.fromLTWH(0, 780, 595, 62); // default footer
      if (area == 'header') {
        bounds = const Rect.fromLTWH(0, 0, 595, 55);
      } else if (area == 'bottom_right') {
        bounds = const Rect.fromLTWH(380, 750, 215, 92);
      }

      await docService.redactPdfWatermarkArea(
        widget.document.path,
        pageIndex: _currentPage > 0 ? _currentPage - 1 : 0,
        bounds: bounds,
      );

      setState(() {
        _reloadKey = UniqueKey();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Watermark cleared from PDF!"),
          backgroundColor: Color(0xFF4F7A4A),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error cleaning PDF watermark: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SGTheme.surface,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: SGTheme.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Search in PDF...",
                  hintStyle: const TextStyle(color: SGTheme.textMuted),
                  border: InputBorder.none,
                  suffixIcon: _searchResult != null && _searchResult!.totalInstanceCount > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${_searchResult!.currentInstanceIndex} of ${_searchResult!.totalInstanceCount}",
                              style: const TextStyle(color: SGTheme.accent, fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up, color: SGTheme.text, size: 20),
                              onPressed: () => _searchResult?.previousInstance(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down, color: SGTheme.text, size: 20),
                              onPressed: () => _searchResult?.nextInstance(),
                            ),
                          ],
                        )
                      : null,
                ),
                onChanged: _onSearch,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.document.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SGTheme.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_totalPages > 0)
                    Text(
                      "Page $_currentPage of $_totalPages",
                      style: const TextStyle(fontSize: 11, color: SGTheme.textSecondary),
                    ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isLiquidMode ? Icons.auto_stories : Icons.auto_stories_outlined,
              color: _isLiquidMode ? Colors.amber : SGTheme.accent,
            ),
            tooltip: _isLiquidMode ? "Exit Liquid Reflow" : "Liquid Mode (Mobile Reflow & TTS)",
            onPressed: _toggleLiquidMode,
          ),
          IconButton(
            icon: const Icon(Icons.draw, color: SGTheme.accent, size: 22),
            tooltip: "Digital Signature (Fill & Sign)",
            onPressed: _showFillAndSignDialog,
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: SGTheme.text),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchResult?.clear();
                  _searchResult = null;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: SGTheme.text),
            tooltip: "Zoom In",
            onPressed: () => _updateZoom(_currentZoom + 0.25),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: SGTheme.text),
            tooltip: "Zoom Out",
            onPressed: () => _updateZoom(_currentZoom - 0.25),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: SGTheme.text),
            tooltip: "PDF Powerhouse Tools",
            onSelected: (val) {
              if (val == 'compress') {
                _compressPdf();
              } else if (val == 'watermark') {
                _showWatermarkRedactDialog();
              } else if (val == 'note') {
                _showEditPdfDialog();
              } else if (val == 'share') {
                _shareDocument();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'compress',
                child: Row(
                  children: [
                    Icon(Icons.compress, size: 18, color: Color(0xFF107C41)),
                    SizedBox(width: 8),
                    Text("Compress PDF (<2MB)"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'watermark',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 18, color: SGTheme.accent),
                    SizedBox(width: 8),
                    Text("Remove Watermark"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'note',
                child: Row(
                  children: [
                    Icon(Icons.edit_note, size: 18, color: SGTheme.accent),
                    SizedBox(width: 8),
                    Text("Add Note & Annotate"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 18, color: SGTheme.accent),
                    SizedBox(width: 8),
                    Text("Share PDF"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoadingLiquid
          ? const Center(
              child: Card(
                color: SGTheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: SGTheme.accent),
                      SizedBox(height: 16),
                      Text("Reflowing Pages for Mobile & TTS...", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            )
          : _isLiquidMode
              ? LiquidReaderView(
                  pagesText: _extractedPagesText,
                  documentTitle: widget.document.name,
                  onExitLiquidMode: () => setState(() => _isLiquidMode = false),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: SGTheme.accent, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: SGTheme.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: SGTheme.accentDeep),
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Go Back", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
              children: [
                Listener(
                  onPointerDown: (event) {
                    _pointerPositions[event.pointer] = event.position;
                    if (_pointerPositions.length == 2) {
                      final keys = _pointerPositions.keys.toList();
                      _initialPinchDistance = (_pointerPositions[keys[0]]! - _pointerPositions[keys[1]]!).distance;
                      _pinchStartZoom = _currentZoom;
                    }
                  },
                  onPointerMove: (event) {
                    if (_pointerPositions.containsKey(event.pointer)) {
                      _pointerPositions[event.pointer] = event.position;
                    }
                    if (_pointerPositions.length == 2 && _initialPinchDistance > 10.0) {
                      final keys = _pointerPositions.keys.toList();
                      final currentDist = (_pointerPositions[keys[0]]! - _pointerPositions[keys[1]]!).distance;
                      final ratio = currentDist / _initialPinchDistance;
                      final targetZoom = (_pinchStartZoom * ratio).clamp(0.35, 5.0);
                      if (targetZoom < 1.0 || _currentZoom < 1.0) {
                        _updateZoom(targetZoom);
                      }
                    }
                  },
                  onPointerUp: (event) {
                    _pointerPositions.remove(event.pointer);
                    if (_pointerPositions.length < 2) {
                      _initialPinchDistance = 0.0;
                    }
                  },
                  onPointerCancel: (event) {
                    _pointerPositions.remove(event.pointer);
                    if (_pointerPositions.length < 2) {
                      _initialPinchDistance = 0.0;
                    }
                  },
                  child: Transform.scale(
                    scale: _currentZoom < 1.0 ? _currentZoom : 1.0,
                    alignment: Alignment.topCenter,
                    child: SfPdfViewer.file(
                      File(widget.document.path),
                      key: _reloadKey,
                      controller: _pdfViewerController,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      enableDoubleTapZooming: true,
                      enableTextSelection: true,
                      maxZoomLevel: 5.0,
                      pageLayoutMode: PdfPageLayoutMode.continuous,
                      scrollDirection: PdfScrollDirection.vertical,
                      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                        setState(() {
                          _totalPages = details.document.pages.count;
                          _isLoading = false;
                        });
                      },
                      onZoomLevelChanged: (PdfZoomDetails details) {
                        if (details.newZoomLevel >= 1.0) {
                          setState(() {
                            _currentZoom = details.newZoomLevel;
                          });
                        }
                      },
                      onPageChanged: (PdfPageChangedDetails details) {
                        setState(() {
                          _currentPage = details.newPageNumber;
                        });
                      },
                      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                        setState(() {
                          _errorMessage = "Unable to render PDF document: ${details.description}";
                          _isLoading = false;
                        });
                      },
                    ),
                  ),
                ),

                // Floating On-Screen Zoom Dock (+ / - / Reset %)
                Positioned(
                  bottom: 24,
                  right: 18,
                  child: ZoomControlsDock(
                    currentZoom: _currentZoom,
                    minZoom: 0.35,
                    maxZoom: 5.0,
                    onZoomIn: () => _updateZoom(_currentZoom + 0.25),
                    onZoomOut: () => _updateZoom(_currentZoom - 0.25),
                    onResetZoom: () => _updateZoom(1.0),
                  ),
                ),
              ],
            ),
    );
  }
}
