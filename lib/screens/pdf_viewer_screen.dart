import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../models/document_file.dart';

class PdfViewerScreen extends StatefulWidget {
  final DocumentFile document;

  const PdfViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Completer<PDFViewController> _controller = Completer<PDFViewController>();
  int _totalPages = 0;
  int _currentPage = 1;
  bool _isReady = false;

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
      body: Stack(
        children: [
          PDFView(
            filePath: widget.document.path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: 0,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onRender: (pages) {
              setState(() {
                _totalPages = pages ?? 0;
                _isReady = true;
              });
            },
            onError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error loading PDF: $error")),
              );
            },
            onPageError: (page, error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error on page $page: $error")),
              );
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _controller.complete(pdfViewController);
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                _currentPage = (page ?? 0) + 1;
                _totalPages = total ?? _totalPages;
              });
            },
          ),
          if (!_isReady)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF0F172A),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
              onPressed: () async {
                final c = await _controller.future;
                if (_currentPage > 1) {
                  await c.setPage(_currentPage - 2);
                }
              },
            ),
            const Text(
              "Social Googol's SG Reader (100% Offline)",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
              onPressed: () async {
                final c = await _controller.future;
                if (_currentPage < _totalPages) {
                  await c.setPage(_currentPage);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
