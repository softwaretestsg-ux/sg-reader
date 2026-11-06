import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/theme.dart';
import '../models/document_file.dart';

class PdfViewerScreen extends StatefulWidget {
  final DocumentFile document;

  const PdfViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Search feature
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;

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
            onPressed: () {
              _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0);
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: SGTheme.text),
            tooltip: "Zoom Out",
            onPressed: () {
              _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SGTheme.accent),
            tooltip: "Share PDF",
            onPressed: _shareDocument,
          ),
        ],
      ),
      body: _errorMessage != null
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
          : SfPdfViewer.file(
              File(widget.document.path),
              key: _pdfViewerKey,
              controller: _pdfViewerController,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                setState(() {
                  _totalPages = details.document.pages.count;
                  _isLoading = false;
                });
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: SGTheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: SGTheme.textSecondary, size: 18),
              onPressed: () {
                _pdfViewerController.previousPage();
              },
            ),
            const Text(
              "Social Googol's SG Reader (100% Offline)",
              style: TextStyle(color: SGTheme.textMuted, fontSize: 11),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: SGTheme.textSecondary, size: 18),
              onPressed: () {
                _pdfViewerController.nextPage();
              },
            ),
          ],
        ),
      ),
    );
  }
}
