import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/document_file.dart';

class PdfViewerScreen extends StatefulWidget {
  final DocumentFile document;

  const PdfViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  int _totalPages = 0;
  int _currentPage = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.document.path),
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                "Page $_currentPage of $_totalPages",
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : PdfViewPinch(
              controller: _pdfController,
              onDocumentLoaded: (document) {
                setState(() {
                  _totalPages = document.pagesCount;
                });
              },
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF0F172A),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
              onPressed: () {
                _pdfController.previousPage(
                  curve: Curves.ease,
                  duration: const Duration(milliseconds: 200),
                );
              },
            ),
            const Text(
              "Social Googol's SG Reader (100% Offline)",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
              onPressed: () {
                _pdfController.nextPage(
                  curve: Curves.ease,
                  duration: const Duration(milliseconds: 200),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
